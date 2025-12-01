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

# SES Configuration
# Note: SES identities must be created and verified manually in AWS Console.
# After manual setup, provide the ARNs and domain/email values here.
# SES and ACM certificates are managed manually - Terraform only consumes ARNs passed via tfvars.
# See docs/setup/SES_AND_ACM_MANUAL_SETUP.md for manual setup instructions.

variable "ses_domain" {
  description = "SES domain already verified in AWS Console (e.g., kambriq.com)"
  type        = string
  default     = "kambriq.com"
}

variable "ses_region" {
  description = "AWS region where SES identities are created (e.g., eu-central-1)"
  type        = string
  default     = "eu-central-1"
}

variable "ses_domain_identity_arn" {
  description = "ARN of SES domain identity (created manually in AWS Console, e.g., arn:aws:ses:eu-central-1:123456789012:identity/kambriq.com)"
  type        = string
  default     = ""
}

variable "ses_from_email" {
  description = "SES sender email address already verified in AWS Console (e.g., noreply@kambriq.com)"
  type        = string
  default     = "noreply@kambriq.com"
}

variable "ses_email_identity_arn" {
  description = "ARN of SES email identity (created manually in AWS Console, e.g., arn:aws:ses:eu-central-1:123456789012:identity/noreply@kambriq.com)"
  type        = string
  default     = ""
}

# ACM Certificate Configuration
# Note: ACM certificates must be created and validated manually in AWS Console.
# After manual setup, provide the ARNs here.
# CloudFront certificates must be created in us-east-1, API Gateway certificates in eu-central-1.
# See docs/setup/SES_AND_ACM_MANUAL_SETUP.md for manual setup instructions.

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

