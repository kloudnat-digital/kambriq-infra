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
# Note: SES identities (domain/email) must be created and verified manually in AWS Console.
# Provide the ARNs and domain/email values here after manual setup.

variable "ses_domain" {
  description = "SES domain already verified in AWS Console (e.g., kambriq.com)"
  type        = string
  default     = "kambriq.com"
}

variable "ses_domain_identity_arn" {
  description = "ARN of SES domain identity (created manually in AWS Console)"
  type        = string
  default     = ""
}

variable "ses_from_email" {
  description = "SES sender email address already verified in AWS Console (e.g., noreply@kambriq.com)"
  type        = string
  default     = "noreply@kambriq.com"
}

variable "ses_email_identity_arn" {
  description = "ARN of SES email identity (created manually in AWS Console)"
  type        = string
  default     = ""
}

# ACM Certificate Configuration
# Note: ACM certificates must be created and validated manually in AWS Console.
# Provide the ARNs here after manual setup.

variable "api_acm_certificate_arn" {
  description = "ACM certificate ARN for API Gateway (created manually in AWS Console, must be in eu-central-1)"
  type        = string
  default     = ""
}

variable "cloudfront_acm_certificate_arn" {
  description = "ACM certificate ARN for CloudFront (created manually in AWS Console, must be in us-east-1)"
  type        = string
  default     = ""
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

