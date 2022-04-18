data "aws_vpc" "vpc_name" {
  filter {
    name   = "tag:Name"
    values = ["${var.app_name}-vpc"]
  }
}

data "aws_subnet_ids" "database_subnets" {
  vpc_id = data.aws_vpc.vpc_name.id
  tags = {
    Name = "demo-vpc-db-*"
  }
}

resource "aws_db_subnet_group" "onmo" {
  name       = "onmo"
  subnet_ids = data.aws_subnet_ids.database_subnets.ids

  tags = {
    Name = "onmo DB subnet group"
  }
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
  master_password                 = var.onmostealth_password
  port                            = var.onmostealth_port
  vpc_security_group_ids          = [aws_security_group.onmo-aurora.id]
  db_cluster_parameter_group_name = "default.aurora-mysql5.7"
  db_subnet_group_name    = aws_db_subnet_group.onmo.name #"default-vpc-04be9032fa38110b8"
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


resource "aws_rds_cluster" "onmoauth-aurora-cluster" {
  cluster_identifier              = "onmoauth-aurora-${var.app_name}"
  engine                          = "aurora-mysql"
  engine_version                  = "5.7.mysql_aurora.2.09.2"
  database_name                   = "onmo"
  master_username                 = var.onmoauth_username
  master_password                 = var.onmoauth_password
  port                            = var.onmoauth_port
  vpc_security_group_ids          = [aws_security_group.onmo-aurora.id]
  db_cluster_parameter_group_name = "default.aurora-mysql5.7"
  db_subnet_group_name    = aws_db_subnet_group.onmo.name #"default-vpc-04be9032fa38110b8"
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

