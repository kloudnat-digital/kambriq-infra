variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "domain_name" {
  description = "Domain name for Route53 and SES (e.g., kambriq.com)"
  type        = string
  default     = "kambriq.com"
}

variable "ses_from_email" {
  description = "Default sender email address for SES"
  type        = string
  default     = "noreply@kambriq.com"
}

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

