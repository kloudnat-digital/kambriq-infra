variable "env" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "rds_security_group_id" {
  description = "RDS security group ID (for policy reference)"
  type        = string
}

variable "s3_media_bucket_arn" {
  description = "S3 media bucket ARN"
  type        = string
}

variable "ses_identity_arn" {
  description = "SES identity ARN for sending emails (can be null if SES is not configured)"
  type        = string
  default     = ""
}

