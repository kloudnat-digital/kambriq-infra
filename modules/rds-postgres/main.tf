# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "kambriq-db-subnet-${var.env}"
  subnet_ids = var.subnet_ids

  tags = {
    Name = "kambriq-db-subnet-${var.env}"
    Env  = var.env
  }
}

# RDS Parameter Group
resource "aws_db_parameter_group" "main" {
  name   = "kambriq-postgres-${var.env}"
  family = "postgres15"

  tags = {
    Name = "kambriq-postgres-${var.env}"
    Env  = var.env
  }
}

# RDS Instance
resource "aws_db_instance" "main" {
  identifier = "kambriq-postgres-${var.env}"

  engine         = "postgres"
  engine_version = "15.4"
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage
  storage_type      = var.storage_type
  storage_encrypted = true
  db_name           = var.db_name
  username          = var.db_username
  password          = var.db_password

  vpc_security_group_ids = [var.security_group_id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  parameter_group_name   = aws_db_parameter_group.main.name

  backup_retention_period = var.backup_retention_period
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:00-mon:05:00"

  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "kambriq-postgres-${var.env}-final-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  publicly_accessible = false
  multi_az            = false # Single-AZ pour minimiser les coûts

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  tags = {
    Name = "kambriq-postgres-${var.env}"
    Env  = var.env
  }
}

