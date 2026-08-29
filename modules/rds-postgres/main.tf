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

  engine = "postgres"
  # Major version only. auto_minor_version_upgrade is on, so AWS owns the minor
  # and a hard-coded one drifts into a downgrade Terraform cannot apply.
  engine_version             = var.engine_version
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  instance_class             = var.instance_class

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
  multi_az            = var.multi_az

  enabled_cloudwatch_logs_exports = var.enable_cloudwatch_logs ? ["postgresql", "upgrade"] : []

  tags = {
    Name = "kambriq-postgres-${var.env}"
    Env  = var.env
  }

  # To enable destroy protection on an existing prd instance, uncomment below.
  # prevent_destroy cannot be set dynamically in Terraform — enable manually
  # in the prd workspace after first apply.
  #
  # lifecycle {
  #   prevent_destroy = true
  # }
}
