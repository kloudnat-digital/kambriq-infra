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

variable "cloudfront_domain" {
  description = "Custom domain for CloudFront (optional)"
  type        = string
  default     = ""
}

variable "cloudfront_certificate_arn" {
  description = "ACM certificate ARN for CloudFront custom domain (optional)"
  type        = string
  default     = ""
}

variable "api_domain" {
  description = "Custom domain for API Gateway (optional)"
  type        = string
  default     = ""
}

variable "api_certificate_arn" {
  description = "ACM certificate ARN for API Gateway custom domain (optional)"
  type        = string
  default     = ""
}

