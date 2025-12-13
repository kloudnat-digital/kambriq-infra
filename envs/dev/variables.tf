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
  description = "Custom domain for CloudFront (e.g., dev.kambriq.com for dev, kambriq.com for prod)"
  type        = string
  default     = "dev.kambriq.com" # Default value for dev environment
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
# Artifact Configuration - REMOVED
# ============================================================================
# These variables have been removed as Terraform no longer manages application code deployment.
# Application code is deployed via workflows deploy-app-dev.yml and deploy-app-prod.yml in the kambriq repository.
# Terraform only creates the Lambda function structure (with dummy placeholder code).

# ============================================================================
# Bastion Configuration
# ============================================================================

variable "enable_bastion" {
  description = "Enable bastion host for manual database migrations"
  type        = bool
  default     = true
}

variable "bastion_key_pair_name" {
  description = "Name of the existing EC2 Key Pair for SSH access to bastion (must exist in AWS). Required if enable_bastion = true."
  type        = string
  default     = ""

  validation {
    condition     = var.enable_bastion == false || var.bastion_key_pair_name != ""
    error_message = "bastion_key_pair_name is required when enable_bastion is true. Please provide a valid EC2 Key Pair name."
  }
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH into the bastion (e.g., '1.2.3.4/32' for single IP, '0.0.0.0/0' for any - NOT RECOMMENDED). Required if enable_bastion = true."
  type        = string
  default     = ""

  validation {
    condition     = var.enable_bastion == false || (var.allowed_ssh_cidr != "" && can(cidrhost(var.allowed_ssh_cidr, 0)))
    error_message = "allowed_ssh_cidr is required when enable_bastion is true. Please provide a valid CIDR block (e.g., '1.2.3.4/32')."
  }
}

variable "enable_bastion_autostop" {
  description = "Enable automatic daily stop of bastion at 23:00 Europe/Paris (21:00 UTC)"
  type        = bool
  default     = true
}


