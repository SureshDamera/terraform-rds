resource "random_password" "onmoauth_master_password" {
  length  = 16
  special = false
}

data "aws_vpc" "vpc_name" {
  filter {
    name   = "tag:Name"
    values = ["${var.app_name}-vpc"]
  }
}

data "aws_subnets" "database_subnets" {
  filter {
    name   = "tag:Name"
    values = ["${var.app_name}-vpc-db-*"]
  }
}

resource "aws_iam_role" "rds-proxy-role" {
  name               = "rds-proxy-role"
  assume_role_policy = file("assumerolepolicy.json")
}

resource "aws_iam_policy" "rds-proxy-policy" {
  name        = "rds-proxy-policy"
  description = "A rds-proxy-policy"
  policy      = file("policyrdsproxy.json")
}

resource "aws_iam_policy_attachment" "rds-proxy-policy-attach" {
  name       = "rds-proxy-policy-attachment"
  roles      = ["${aws_iam_role.rds-proxy-role.name}"]
  policy_arn = aws_iam_policy.rds-proxy-policy.arn
}

resource "aws_security_group" "onmo-aurora" {
  name        = "aurora_db_sg"
  description = "Allow Aurora DB traffic"
  vpc_id      = data.aws_vpc.vpc_name.id

  ingress {
    description      = "Allow requests from only VPC"
    from_port        = var.onmostealth_port
    to_port          = var.onmostealth_port
    protocol         = "tcp"
    cidr_blocks      = [data.aws_vpc.vpc_name.cidr_block]
    ipv6_cidr_blocks = [data.aws_vpc.vpc_name.ipv6_cidr_block]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge({
    Name = "sg-aurora-db-${var.app_name}"
  }, var.tags)
}


resource "aws_rds_cluster" "onmostealth-aurora-cluster" {
  cluster_identifier              = "onmostealth-aurora-${var.app_name}"
  engine                          = "aurora-mysql"
  engine_version                  = "5.7.mysql_aurora.2.09.2"
  database_name                   = "onmo"
  master_username                 = var.onmostealth_username
  master_password                 = random_password.onmoauth_master_password.result
  port                            = var.onmostealth_port
  vpc_security_group_ids          = [aws_security_group.onmo-aurora.id]
  db_cluster_parameter_group_name = "default.aurora-mysql5.7"
  db_subnet_group_name            = "${var.app_name}-vpc"
  #multi_az                  = false
  backup_retention_period      = 1
  preferred_backup_window      = "11:20-11:50"
  preferred_maintenance_window = "tue:12:36-tue:13:06"
  final_snapshot_identifier    = "onmostealth-aurora-${var.app_name}-final"
  tags = merge({
    Name = "db-${terraform.workspace}"
  }, var.tags)
}

resource "aws_rds_cluster_instance" "onmostealth-aurora-cluster_instances" {
  count              = 1
  identifier         = "onmostealth-aurora-${var.app_name}-instance-1"
  cluster_identifier = aws_rds_cluster.onmostealth-aurora-cluster.id
  instance_class     = "db.r5.large"
  #availability_zone       = ["us-east-1a", "us-east-1b"]
  engine                  = aws_rds_cluster.onmostealth-aurora-cluster.engine
  engine_version          = aws_rds_cluster.onmostealth-aurora-cluster.engine_version
  publicly_accessible     = false
  db_parameter_group_name = "default.aurora-mysql5.7"
  promotion_tier          = 1
}

resource "aws_secretsmanager_secret" "onmostealth-aurora-cluster" {
  name = "onmostealth-aurora-${var.app_name}"
}

resource "aws_secretsmanager_secret_version" "onmostealth_rds_credentials" {
  secret_id     = aws_secretsmanager_secret.onmostealth-aurora-cluster.id
  secret_string = <<EOF
{
  "username": "${var.onmostealth_username}",
  "password": "${random_password.onmoauth_master_password.result}",
  "engine": "mysql",
  "host": "${aws_rds_cluster.onmostealth-aurora-cluster.endpoint}",
  "port": "${var.onmostealth_port}",
  "dbClusterIdentifier": "${aws_rds_cluster.onmostealth-aurora-cluster.cluster_identifier}"
}
EOF
}

resource "aws_db_proxy" "onmostealth-aurora-cluster" {
  name                   = "onmostealth-aurora-${var.app_name}-cluster"
  debug_logging          = false
  engine_family          = "MYSQL"
  idle_client_timeout    = 1800
  require_tls            = false
  role_arn               = aws_iam_role.rds-proxy-role.arn
  vpc_security_group_ids = [aws_security_group.onmo-aurora.id]
  vpc_subnet_ids         = data.aws_subnets.database_subnets.ids

  auth {
    auth_scheme = "SECRETS"
    iam_auth    = "DISABLED"
    secret_arn  = aws_secretsmanager_secret.onmostealth-aurora-cluster.arn
  }

  tags = var.tags
}

resource "aws_db_proxy_default_target_group" "onmostealth-aurora-cluster" {
  db_proxy_name = aws_db_proxy.onmostealth-aurora-cluster.name

  connection_pool_config {
    connection_borrow_timeout    = 120
    max_connections_percent      = 100
    max_idle_connections_percent = 50
  }
}

resource "aws_db_proxy_target" "onmostealth-aurora-cluster" {
  db_cluster_identifier = aws_rds_cluster.onmostealth-aurora-cluster.cluster_identifier
  db_proxy_name         = aws_db_proxy.onmostealth-aurora-cluster.name
  target_group_name     = aws_db_proxy_default_target_group.onmostealth-aurora-cluster.name
}

resource "aws_db_proxy_endpoint" "onmostealth-aurora-cluster" {
  db_proxy_name          = aws_db_proxy.onmostealth-aurora-cluster.name
  db_proxy_endpoint_name = "onmostealth-aurora-cluster-readonly"
  vpc_subnet_ids         = data.aws_subnets.database_subnets.ids
  target_role            = "READ_ONLY"
}

resource "aws_ssm_parameter" "onmoauth_password" {
  name        = "rds-password"
  type        = "String"
  description = "The password of onmostealth-aurora-${var.app_name}-instance-1 database"
  value       = var.onmoauth_password
  tags        = var.tags
}

resource "aws_ssm_parameter" "onmoauth_endpoint" {
  name        = "rds-endpoint"
  type        = "String"
  description = "url of the onmostealth-aurora-${var.app_name}-instance-1 database writer instance "
  value       = aws_rds_cluster.onmostealth-aurora-cluster.endpoint
  tags        = var.tags
}

resource "aws_rds_cluster" "onmoauth-aurora-cluster" {
  cluster_identifier              = "onmoauth-aurora-${var.app_name}"
  engine                          = "aurora-mysql"
  engine_version                  = "5.7.mysql_aurora.2.09.2"
  database_name                   = "onmoauth"
  master_username                 = var.onmoauth_username
  master_password                 = var.onmoauth_password
  port                            = var.onmoauth_port
  vpc_security_group_ids          = [aws_security_group.onmo-aurora.id]
  db_cluster_parameter_group_name = "default.aurora-mysql5.7"
  db_subnet_group_name            = "${var.app_name}-vpc"
  #multi_az                  = false
  backup_retention_period      = 1
  preferred_backup_window      = "11:20-11:50"
  preferred_maintenance_window = "tue:12:36-tue:13:06"
  final_snapshot_identifier    = "onmoauth-aurora-${var.app_name}-cluster-final"
  tags = merge({
    Name = "db-${terraform.workspace}"
  }, var.tags)
}

resource "aws_rds_cluster_instance" "onmoauth-aurora-cluster_instances" {
  count              = 2
  identifier         = "onmoauth-aurora-${var.app_name}-instance-${count.index}"
  cluster_identifier = aws_rds_cluster.onmoauth-aurora-cluster.id
  instance_class     = "db.r5.large"
  #availability_zone       = ["us-east-1a", "us-east-1b"] 
  engine                  = aws_rds_cluster.onmoauth-aurora-cluster.engine
  engine_version          = aws_rds_cluster.onmoauth-aurora-cluster.engine_version
  publicly_accessible     = false
  db_parameter_group_name = "default.aurora-mysql5.7"
  promotion_tier          = 1
}

resource "aws_secretsmanager_secret" "onmoauth-aurora-cluster" {
  name = "onmoauth-aurora-${var.app_name}"
}

resource "aws_secretsmanager_secret_version" "onmoauth_rds_credentials" {
  secret_id     = aws_secretsmanager_secret.onmoauth-aurora-cluster.id
  secret_string = <<EOF
{
  "username": "${var.onmoauth_username}",
  "password": "${var.onmoauth_password}",
  "engine": "mysql",
  "host": "${aws_rds_cluster.onmoauth-aurora-cluster.endpoint}",
  "port": "${var.onmoauth_port}",
  "dbClusterIdentifier": "${aws_rds_cluster.onmoauth-aurora-cluster.cluster_identifier}"
}
EOF
}
