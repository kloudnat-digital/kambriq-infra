variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

# ============================================================================
# DEPRECATED: These variables are no longer used.
# Secrets are now retrieved from SSM Parameter Store via data sources in main.tf:
#   - /kambriq/prod/db/password
#   - /kambriq/prod/api/jwt_secret
# ============================================================================
# These variables are kept for backward compatibility but are not used.
# They can be removed in a future version.

variable "db_password" {
  description = "[DEPRECATED] Database master password - now retrieved from SSM Parameter Store (/kambriq/prod/db/password)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "jwt_secret" {
  description = "[DEPRECATED] JWT secret key - now retrieved from SSM Parameter Store (/kambriq/prod/api/jwt_secret)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "ses_domain" {
  description = "SES domain name"
  type        = string
  default     = "kambriq.com"
}

# ============================================================================
# SES Configuration
# ============================================================================
# SES sender email address (environment-specific)
# SES identities are managed manually in AWS Console, not by Terraform
# See docs/setup/SES_AND_ACM_MANUAL_SETUP.md for manual setup instructions

variable "ses_from_email" {
  description = "SES sender email address for this environment (e.g., noreply@kambriq.com for prod)"
  type        = string
  default     = "noreply@kambriq.com"
}

variable "cloudfront_domain" {
  description = "Custom domain for CloudFront (e.g., dev.kambriq.com for dev, kambriq.com for prod)"
  type        = string
  default     = "kambriq.com" # Default value for prod environment
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

# ============================================================================
# Artifact Configuration - REMOVED
# ============================================================================
# These variables have been removed as Terraform no longer manages application code deployment.
# Application code is deployed via workflows deploy-app-dev.yml and deploy-app-prod.yml in the kambriq repository.
# Terraform only creates the Lambda function structure (with dummy placeholder code).

