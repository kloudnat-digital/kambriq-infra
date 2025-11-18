variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "JWT secret key"
  type        = string
  sensitive   = true
}

variable "ses_domain" {
  description = "SES domain name"
  type        = string
  default     = "kambriq.com"
}

variable "ses_from_email" {
  description = "SES sender email address"
  type        = string
  default     = "noreply@kambriq.com"
}

