data "aws_vpc" "vpc_name" {
    filter {
        name   = "Name"
        values = ["${var.app_name}-vpc"]
    }
}

data "aws_subnet_ids" "database_subnets" {
    vpc_id = data.aws_vpc.vpc_name.id
    tags = {
        Name = "demo-vpc-db-*"
   }
}

output "vpc_id" {
  value = data.aws_vpc.vpc_name.id
}

output "aws_subnet_ids" {
  value = data.aws_subnet_ids.database_subnets.ids
}

resource "aws_db_subnet_group" "onmostealth-aurora-instance-1" {
  name       = "onmostealth-aurora-instance-1"
  subnet_ids = [data.aws_subnet_ids.database_subnets.ids]

  tags = {
    Name = "onmostealth-aurora-instance-1 DB subnet group"
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
    vpc_security_group_ids    = ["sg-06d418850e82b99a1"] #[aws_security_group.dbsg.id] 
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
