variable "project_name" {
  description = "Project name (e.g., kambriq)"
  type        = string
  default     = "kambriq"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = []
}

# Route53 Configuration
variable "domain_name" {
  description = "Domain name for Route53 hosted zone (e.g., kambriq.com)"
  type        = string
  default     = "kambriq.com"
}

# SES Configuration
variable "ses_from_email" {
  description = "Default sender email address for SES"
  type        = string
  default     = "noreply@kambriq.com"
}

# S3 Logs Configuration
variable "enable_s3_logs" {
  description = "Enable S3 bucket for logs"
  type        = bool
  default     = true
}

variable "enable_s3_artifacts" {
  description = "Enable S3 bucket for artifacts"
  type        = bool
  default     = true
}

