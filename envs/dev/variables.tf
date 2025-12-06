variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

# ============================================================================
# DEPRECATED: These variables are no longer used.
# Secrets are now retrieved from SSM Parameter Store via data sources in main.tf:
#   - /kambriq/dev/db/password
#   - /kambriq/dev/api/jwt_secret
# ============================================================================
# These variables are kept for backward compatibility but are not used.
# They can be removed in a future version.

variable "db_password" {
  description = "[DEPRECATED] Database master password - now retrieved from SSM Parameter Store (/kambriq/dev/db/password)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "jwt_secret" {
  description = "[DEPRECATED] JWT secret key - now retrieved from SSM Parameter Store (/kambriq/dev/api/jwt_secret)"
  type        = string
  sensitive   = true
  default     = ""
}

# Optional: Custom domains (leave empty for default CloudFront/API Gateway URLs)
variable "cloudfront_domain" {
  description = "Custom domain for CloudFront (optional, e.g., app-dev.kambriq.com)"
  type        = string
  default     = ""
}

variable "cloudfront_certificate_arn" {
  description = "ACM certificate ARN for CloudFront custom domain (must be in us-east-1)"
  type        = string
  default     = ""
}

variable "api_domain" {
  description = "Custom domain for API Gateway (optional, e.g., api-dev.kambriq.com)"
  type        = string
  default     = ""
}

variable "api_certificate_arn" {
  description = "ACM certificate ARN for API Gateway custom domain"
  type        = string
  default     = ""
}

# ============================================================================
# SES Configuration
# ============================================================================
# SES sender email address (environment-specific)
# SES identities are managed manually in AWS Console, not by Terraform
# See docs/setup/SES_AND_ACM_MANUAL_SETUP.md for manual setup instructions

variable "ses_from_email" {
  description = "SES sender email address for this environment (e.g., noreply.dev@kambriq.com for dev)"
  type        = string
  default     = "noreply.dev@kambriq.com"
}

# ============================================================================
# Artifact Configuration
# ============================================================================
# These variables specify the S3 artifacts built by the kambriq repo
# (via .github/workflows/build-artifacts.yml)
#
# The artifacts are uploaded to S3 with paths like:
#   - api/api-<sha>.zip (NestJS Lambda bundle)
#   - web/web-<sha>.zip (OpenNext SSR bundle)
#
# These S3 keys should be passed via workflow inputs or environment variables
# when running Terraform workflows.

variable "artifact_bucket_name" {
  description = "S3 bucket name where artifacts are stored (e.g., kambriq-artifacts-dev)"
  type        = string
  default     = ""
}

variable "api_bundle_s3_key" {
  description = "S3 key of the API bundle ZIP (e.g., api/api-abc123.zip). Leave empty to use dummy placeholder."
  type        = string
  default     = ""
}

variable "ssr_bundle_s3_key" {
  description = "S3 key of the OpenNext SSR bundle ZIP (e.g., web/web-abc123.zip). Leave empty to use dummy placeholder."
  type        = string
  default     = ""
}

