variable "env" {
  description = "Environment name (dev, prd)"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "kambriq"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "kambriq_admin"
}

variable "db_password" {
  description = "Database master password (should be moved to Secrets Manager in production)"
  type        = string
  sensitive   = true
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "storage_type" {
  description = "Storage type"
  type        = string
  default     = "gp3"
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for RDS"
  type        = string
}

variable "backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on deletion (for dev)"
  type        = bool
  default     = true
}

variable "enable_cloudwatch_logs" {
  description = "Export postgresql and upgrade logs to CloudWatch"
  type        = bool
  default     = true
}

variable "multi_az" {
  description = "Enable Multi-AZ for automatic failover (set true for production)"
  type        = bool
  default     = false
}

variable "engine_version" {
  description = "PostgreSQL engine version. A major-only value (\"15\") prefix-matches, so AWS minor upgrades do not produce a perpetual diff. Pass a full version only to freeze a specific minor."
  type        = string
  default     = "15"
}

variable "auto_minor_version_upgrade" {
  description = "Let AWS apply minor version upgrades during the maintenance window"
  type        = bool
  default     = true
}
