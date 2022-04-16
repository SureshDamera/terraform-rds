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

resource "aws_db_subnet_group" "onmostealth-aurora-instance-1" {
  name       = "onmostealth-aurora-instance-1"
  subnet_ids = data.aws_subnet_ids.database_subnets.ids

  tags = {
    Name = "onmostealth-aurora-instance-1 DB subnet group"
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

  tags = {
    Name = "allow_tls"
  }
}


resource "aws_db_instance" "onmostealth-aurora-instance-1" {
    identifier                = "onmostealth-aurora-${var.app_name}-instance-1"
    allocated_storage         = 1
    storage_type              = "aurora"
    engine                    = "aurora-mysql"
    engine_version            = "5.7.mysql_aurora.2.09.2"
    instance_class            = "db.r5.large"
    name                      = "onmo"
    username                  = var.onmostealth_username
    password                  = var.onmostealth_password
    port                      = var.onmostealth_port
    publicly_accessible       = false
    # availability_zone         = "me-south-1b"
    security_group_names      = []
    vpc_security_group_ids    = [aws_security_group.onmo-aurora.id] 
    db_subnet_group_name      = aws_db_subnet_group.onmostealth-aurora-instance-1.name #"default-vpc-04be9032fa38110b8"
    parameter_group_name      = "default.aurora-mysql5.7"
    multi_az                  = true #false
    backup_retention_period   = 1
    backup_window             = "11:20-11:50"
    maintenance_window        = "tue:12:36-tue:13:06"
    final_snapshot_identifier = "onmostealth-aurora-${var.app_name}-instance-1-final"
    tags = merge({
                    Name = "db-${terraform.workspace}"
                 }, var.tags)
}
