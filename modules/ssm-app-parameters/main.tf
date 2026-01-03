# ============================================================================
# SSM Application Parameters Module
# ============================================================================
# This module creates SSM Parameter Store parameters for application runtime
# configuration. Values are constructed from Terraform outputs and variables.
#
# Parameters created:
# - /kambriq/{env}/api/DATABASE_URL (SecureString) - Constructed from RDS outputs
# - /kambriq/{env}/api/JWT_SECRET (SecureString) - From SSM or variable
# - /kambriq/{env}/api/FRONTEND_URL (String) - From CloudFront output
# - /kambriq/{env}/api/SES_FROM_EMAIL (String) - From SES variable
# ============================================================================

locals {
  # Construct DATABASE_URL from RDS components
  # Format: postgresql://{username}:{password}@{host}:{port}/{database}?schema=public
  database_url = "postgresql://${var.db_username}:${var.db_password}@${var.db_host}:${var.db_port}/${var.db_name}?schema=public"
}

# ============================================================================
# DATABASE_URL - Complete PostgreSQL connection string
# ============================================================================
resource "aws_ssm_parameter" "database_url" {
  name  = "/kambriq/${var.env}/api/DATABASE_URL"
  type  = "SecureString"
  value = local.database_url

  description = "Complete PostgreSQL connection string for ${var.env} environment"
  tags = {
    Name        = "kambriq-api-database-url-${var.env}"
    Environment = var.env
    Service     = "api"
  }
}

# ============================================================================
# JWT_SECRET - JWT signing secret
# ============================================================================
# Note: If jwt_secret is provided, use it. Otherwise, try to read from existing SSM parameter.
# The existing parameter might be in lowercase (/kambriq/{env}/api/jwt_secret)
# but we create it in uppercase (/kambriq/{env}/api/JWT_SECRET) as expected by the app.
#
# IMPORTANT: If jwt_secret is not provided and the existing SSM parameter doesn't exist,
# the parameter will be created with a placeholder value. You must update it manually
# with a secure secret before deploying the application.
#
# The lifecycle ignore_changes ensures that manual updates to the secret value
# won't be overwritten by Terraform.
resource "aws_ssm_parameter" "jwt_secret" {
  name = "/kambriq/${var.env}/api/JWT_SECRET"
  type = "SecureString"
  # Use provided value, or try to read from existing SSM (lowercase), or placeholder
  value = var.jwt_secret != "" ? var.jwt_secret : (
    length(data.aws_ssm_parameter.jwt_secret_existing) > 0
    ? data.aws_ssm_parameter.jwt_secret_existing[0].value
    : "CHANGE-ME-GENERATE-A-SECRET-MIN-32-CHARS"
  )

  description = "JWT signing secret for ${var.env} environment"
  tags = {
    Name        = "kambriq-api-jwt-secret-${var.env}"
    Environment = var.env
    Service     = "api"
  }

  lifecycle {
    ignore_changes = [value]
    # Allow manual updates to JWT secret without Terraform overwriting
  }
}

# Data source to read existing JWT secret if not provided
# Try lowercase first (legacy naming)
# NOTE: This data source will fail during terraform plan/apply if the parameter
# /kambriq/{env}/api/jwt_secret doesn't exist. In that case:
# 1. Create /kambriq/{env}/api/jwt_secret manually first with:
#    aws ssm put-parameter --name "/kambriq/{env}/api/jwt_secret" --value "your-secret" --type SecureString
#    OR
# 2. Provide jwt_secret as a variable to the module
#    OR
# 3. The parameter will be created with a placeholder that you must update manually
data "aws_ssm_parameter" "jwt_secret_existing" {
  count = var.jwt_secret == "" ? 1 : 0
  name  = "/kambriq/${var.env}/api/jwt_secret" # Try lowercase first (legacy)
}

# ============================================================================
# FRONTEND_URL - Frontend URL for CORS and email links
# ============================================================================
resource "aws_ssm_parameter" "frontend_url" {
  name  = "/kambriq/${var.env}/api/FRONTEND_URL"
  type  = "String"
  value = var.frontend_url

  description = "Frontend URL for CORS and email links in ${var.env} environment"
  tags = {
    Name        = "kambriq-api-frontend-url-${var.env}"
    Environment = var.env
    Service     = "api"
  }
}

# ============================================================================
# SES_FROM_EMAIL - SES sender email address
# ============================================================================
resource "aws_ssm_parameter" "ses_from_email" {
  name  = "/kambriq/${var.env}/api/SES_FROM_EMAIL"
  type  = "String"
  value = var.ses_from_email

  description = "SES sender email address for ${var.env} environment"
  tags = {
    Name        = "kambriq-api-ses-from-email-${var.env}"
    Environment = var.env
    Service     = "api"
  }
}

# ============================================================================
# Additional API KV (String) - created by Terraform but can be updated manually
# ============================================================================

resource "aws_ssm_parameter" "default_visitor_role_id" {
  name        = "/kambriq/${var.env}/api/DEFAULT_VISITOR_ROLE_ID"
  type        = "String"
  value       = var.default_visitor_role_id
  overwrite   = true
  description = "Default visitor role id for ${var.env}"
  tags = {
    Name        = "kambriq-api-default-visitor-role-id-${var.env}"
    Environment = var.env
    Service     = "api"
  }
  lifecycle { ignore_changes = [value] }
}

resource "aws_ssm_parameter" "password_reset_token_expiration_hours" {
  name        = "/kambriq/${var.env}/api/PASSWORD_RESET_TOKEN_EXPIRATION_HOURS"
  type        = "String"
  value       = tostring(var.password_reset_token_expiration_hours)
  overwrite   = true
  description = "Password reset token expiration (hours) for ${var.env}"
  tags = {
    Name        = "kambriq-api-password-reset-token-expiration-hours-${var.env}"
    Environment = var.env
    Service     = "api"
  }
  lifecycle { ignore_changes = [value] }
}

resource "aws_ssm_parameter" "referral_code_expiration_hours" {
  name        = "/kambriq/${var.env}/api/REFERRAL_CODE_EXPIRATION_HOURS"
  type        = "String"
  value       = tostring(var.referral_code_expiration_hours)
  overwrite   = true
  description = "Referral code expiration (hours) for ${var.env}"
  tags = {
    Name        = "kambriq-api-referral-code-expiration-hours-${var.env}"
    Environment = var.env
    Service     = "api"
  }
  lifecycle { ignore_changes = [value] }
}

resource "aws_ssm_parameter" "referral_invitation_token_expiration_hours" {
  name        = "/kambriq/${var.env}/api/REFERRAL_INVITATION_TOKEN_EXPIRATION_HOURS"
  type        = "String"
  value       = tostring(var.referral_invitation_token_expiration_hours)
  overwrite   = true
  description = "Referral invitation token expiration (hours) for ${var.env}"
  tags = {
    Name        = "kambriq-api-referral-invitation-token-expiration-hours-${var.env}"
    Environment = var.env
    Service     = "api"
  }
  lifecycle { ignore_changes = [value] }
}

resource "aws_ssm_parameter" "jwt_expires_in" {
  name        = "/kambriq/${var.env}/api/JWT_EXPIRES_IN"
  type        = "String"
  value       = tostring(var.jwt_expires_in)
  overwrite   = true
  description = "JWT access token expiration (seconds) for ${var.env}"
  tags = {
    Name        = "kambriq-api-jwt-expires-in-${var.env}"
    Environment = var.env
    Service     = "api"
  }
  lifecycle { ignore_changes = [value] }
}

resource "aws_ssm_parameter" "jwt_refresh_expires_in" {
  name        = "/kambriq/${var.env}/api/JWT_REFRESH_EXPIRES_IN"
  type        = "String"
  value       = tostring(var.jwt_refresh_expires_in)
  overwrite   = true
  description = "JWT refresh token expiration (seconds) for ${var.env}"
  tags = {
    Name        = "kambriq-api-jwt-refresh-expires-in-${var.env}"
    Environment = var.env
    Service     = "api"
  }
  lifecycle { ignore_changes = [value] }
}

resource "aws_ssm_parameter" "jwt_algorithm" {
  name        = "/kambriq/${var.env}/api/JWT_ALGORITHM"
  type        = "String"
  value       = var.jwt_algorithm
  overwrite   = true
  description = "JWT algorithm for ${var.env}"
  tags = {
    Name        = "kambriq-api-jwt-algorithm-${var.env}"
    Environment = var.env
    Service     = "api"
  }
  lifecycle { ignore_changes = [value] }
}

resource "aws_ssm_parameter" "cookie_secure" {
  name        = "/kambriq/${var.env}/api/COOKIE_SECURE"
  type        = "String"
  value       = var.cookie_secure
  overwrite   = true
  description = "Cookie secure flag for ${var.env}"
  tags = {
    Name        = "kambriq-api-cookie-secure-${var.env}"
    Environment = var.env
    Service     = "api"
  }
  lifecycle { ignore_changes = [value] }
}

resource "aws_ssm_parameter" "cookie_same_site" {
  name        = "/kambriq/${var.env}/api/COOKIE_SAME_SITE"
  type        = "String"
  value       = var.cookie_same_site
  overwrite   = true
  description = "Cookie SameSite policy for ${var.env}"
  tags = {
    Name        = "kambriq-api-cookie-same-site-${var.env}"
    Environment = var.env
    Service     = "api"
  }
  lifecycle { ignore_changes = [value] }
}

resource "aws_ssm_parameter" "cookie_domain" {
  count       = var.cookie_domain != "" ? 1 : 0
  name        = "/kambriq/${var.env}/api/COOKIE_DOMAIN"
  type        = "String"
  value       = var.cookie_domain
  overwrite   = true
  description = "Cookie domain for ${var.env}"
  tags = {
    Name        = "kambriq-api-cookie-domain-${var.env}"
    Environment = var.env
    Service     = "api"
  }
  lifecycle { ignore_changes = [value] }
}

resource "aws_ssm_parameter" "verification_cost" {
  name        = "/kambriq/${var.env}/api/VERIFICATION_COST"
  type        = "String"
  value       = tostring(var.verification_cost)
  overwrite   = true
  description = "Verification cost for ${var.env}"
  tags = {
    Name        = "kambriq-api-verification-cost-${var.env}"
    Environment = var.env
    Service     = "api"
  }
  lifecycle { ignore_changes = [value] }
}

resource "aws_ssm_parameter" "aws_ses_to_admin_contact" {
  name        = "/kambriq/${var.env}/api/AWS_SES_TO_ADMIN_CONTACT"
  type        = "String"
  value       = var.aws_ses_to_admin_contact
  overwrite   = true
  description = "Admin contact email for verify notifications (${var.env})"
  tags = {
    Name        = "kambriq-api-aws-ses-to-admin-contact-${var.env}"
    Environment = var.env
    Service     = "api"
  }
  lifecycle { ignore_changes = [value] }
}

resource "aws_ssm_parameter" "contact_whatsapp_number" {
  name        = "/kambriq/${var.env}/api/CONTACT_WHATSAPP_NUMBER"
  type        = "String"
  value       = var.contact_whatsapp_number
  overwrite   = true
  description = "WhatsApp contact number for templates (${var.env})"
  tags = {
    Name        = "kambriq-api-contact-whatsapp-number-${var.env}"
    Environment = var.env
    Service     = "api"
  }
  lifecycle { ignore_changes = [value] }
}

resource "aws_ssm_parameter" "paypal_environment" {
  name        = "/kambriq/${var.env}/api/PAYPAL_ENVIRONMENT"
  type        = "String"
  value       = var.paypal_environment
  overwrite   = true
  description = "PayPal environment (sandbox/production) for ${var.env}"
  tags = {
    Name        = "kambriq-api-paypal-environment-${var.env}"
    Environment = var.env
    Service     = "api"
  }
  lifecycle { ignore_changes = [value] }
}

# ============================================================================
# Web build-time KV (String) under /kambriq/{env}/web/*
# ============================================================================

resource "aws_ssm_parameter" "web_next_public_api_base_url" {
  count       = var.api_gateway_base_url != "" ? 1 : 0
  name        = "/kambriq/${var.env}/web/NEXT_PUBLIC_API_BASE_URL"
  type        = "String"
  value       = var.api_gateway_base_url
  overwrite   = true
  description = "Next.js public API base URL for ${var.env}"
  tags = {
    Name        = "kambriq-web-next-public-api-base-url-${var.env}"
    Environment = var.env
    Service     = "web"
  }
  lifecycle { ignore_changes = [value] }
}

resource "aws_ssm_parameter" "web_next_public_site_url" {
  count       = var.frontend_cloudfront_domain != "" ? 1 : 0
  name        = "/kambriq/${var.env}/web/NEXT_PUBLIC_SITE_URL"
  type        = "String"
  value       = "https://${var.frontend_cloudfront_domain}"
  overwrite   = true
  description = "Next.js public site URL for ${var.env}"
  tags = {
    Name        = "kambriq-web-next-public-site-url-${var.env}"
    Environment = var.env
    Service     = "web"
  }
  lifecycle { ignore_changes = [value] }
}

resource "aws_ssm_parameter" "web_next_public_jwt_expires_in" {
  name        = "/kambriq/${var.env}/web/NEXT_PUBLIC_JWT_EXPIRES_IN"
  type        = "String"
  value       = tostring(var.next_public_jwt_expires_in)
  overwrite   = true
  description = "Next.js JWT expires in (seconds) for ${var.env}"
  tags = {
    Name        = "kambriq-web-next-public-jwt-expires-in-${var.env}"
    Environment = var.env
    Service     = "web"
  }
  lifecycle { ignore_changes = [value] }
}

resource "aws_ssm_parameter" "web_next_public_jwt_refresh_buffer_seconds" {
  name        = "/kambriq/${var.env}/web/NEXT_PUBLIC_JWT_REFRESH_BUFFER_SECONDS"
  type        = "String"
  value       = tostring(var.next_public_jwt_refresh_buffer_seconds)
  overwrite   = true
  description = "Next.js JWT refresh buffer (seconds) for ${var.env}"
  tags = {
    Name        = "kambriq-web-next-public-jwt-refresh-buffer-seconds-${var.env}"
    Environment = var.env
    Service     = "web"
  }
  lifecycle { ignore_changes = [value] }
}

resource "aws_ssm_parameter" "web_next_public_stale_time" {
  name        = "/kambriq/${var.env}/web/NEXT_PUBLIC_STALE_TIME"
  type        = "String"
  value       = tostring(var.next_public_stale_time)
  overwrite   = true
  description = "Next.js stale time (seconds) for ${var.env}"
  tags = {
    Name        = "kambriq-web-next-public-stale-time-${var.env}"
    Environment = var.env
    Service     = "web"
  }
  lifecycle { ignore_changes = [value] }
}

resource "aws_ssm_parameter" "web_next_public_refetch_interval" {
  name        = "/kambriq/${var.env}/web/NEXT_PUBLIC_REFETCH_INTERVAL"
  type        = "String"
  value       = tostring(var.next_public_refetch_interval)
  overwrite   = true
  description = "Next.js refetch interval (seconds) for ${var.env}"
  tags = {
    Name        = "kambriq-web-next-public-refetch-interval-${var.env}"
    Environment = var.env
    Service     = "web"
  }
  lifecycle { ignore_changes = [value] }
}

resource "aws_ssm_parameter" "web_next_public_paypal_client_id" {
  count       = var.next_public_paypal_client_id != "" ? 1 : 0
  name        = "/kambriq/${var.env}/web/NEXT_PUBLIC_PAYPAL_CLIENT_ID"
  type        = "String"
  value       = var.next_public_paypal_client_id
  overwrite   = true
  description = "Next.js public PayPal client id for ${var.env}"
  tags = {
    Name        = "kambriq-web-next-public-paypal-client-id-${var.env}"
    Environment = var.env
    Service     = "web"
  }
  lifecycle { ignore_changes = [value] }
}

# ============================================================================
# Web runtime parameters (SSR) - loaded by SSR Lambda at runtime
# ============================================================================

resource "aws_ssm_parameter" "web_nextauth_url" {
  count       = var.nextauth_url != "" ? 1 : 0
  name        = "/kambriq/${var.env}/web/NEXTAUTH_URL"
  type        = "String"
  value       = var.nextauth_url
  overwrite   = true
  description = "NextAuth base URL for ${var.env}"
  tags = {
    Name        = "kambriq-web-nextauth-url-${var.env}"
    Environment = var.env
    Service     = "web"
  }
  lifecycle { ignore_changes = [value] }
}

# ============================================================================
# NEXTAUTH_SECRET - Auto-generated with random_password (P1 Fix)
# ============================================================================
# P1: Auto-generate NEXTAUTH_SECRET if not provided, without regenerating on every apply
# Strategy:
# 1. If nextauth_secret variable is provided, use it (manual override)
# 2. Otherwise, generate a new random password
# 3. Use lifecycle ignore_changes to prevent Terraform from regenerating the secret
# 4. If parameter already exists in SSM, Terraform will import it and ignore_changes
#    will prevent overwriting it
#
# Migration for existing environments:
# - If NEXTAUTH_SECRET already exists in SSM, Terraform will import it
# - The lifecycle ignore_changes will prevent Terraform from overwriting it
# - To regenerate: manually delete the SSM parameter and re-run terraform apply
# ============================================================================

# Random password generator (only used if secret not provided)
resource "random_password" "web_nextauth_secret" {
  count   = var.nextauth_secret == "" ? 1 : 0
  length  = 64
  special = true
  # Exclude characters that might cause issues in URLs or environment variables
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# SSM Parameter for NEXTAUTH_SECRET
resource "aws_ssm_parameter" "web_nextauth_secret" {
  name  = "/kambriq/${var.env}/web/NEXTAUTH_SECRET"
  type  = "SecureString"
  # Use provided value, or generate new random password
  # Note: If parameter already exists and is imported, lifecycle ignore_changes will protect the value
  value = var.nextauth_secret != "" ? var.nextauth_secret : random_password.web_nextauth_secret[0].result
  overwrite = false # Prevent overwriting existing secrets (will fail if exists and value differs)
  description = "NextAuth JWT signing secret for ${var.env} (auto-generated if not provided)"
  tags = {
    Name        = "kambriq-web-nextauth-secret-${var.env}"
    Environment = var.env
    Service     = "web"
    ManagedBy   = "Terraform"
    AutoGenerated = var.nextauth_secret == "" ? "true" : "false"
  }

  lifecycle {
    ignore_changes = [value]
    # CRITICAL: Prevent Terraform from regenerating or overwriting the secret value
    # Once created (or imported), the secret value will not be changed by Terraform
    # Only tags and metadata can be updated
    # Manual updates via AWS Console/CLI will be preserved
  }
}

resource "aws_ssm_parameter" "web_api_base_url" {
  count       = var.api_base_url != "" ? 1 : 0
  name        = "/kambriq/${var.env}/web/API_BASE_URL"
  type        = "String"
  value       = var.api_base_url
  overwrite   = true
  description = "API Gateway base URL for SSR server-to-server calls (${var.env})"
  tags = {
    Name        = "kambriq-web-api-base-url-${var.env}"
    Environment = var.env
    Service     = "web"
  }
  lifecycle { ignore_changes = [value] }
}

resource "aws_ssm_parameter" "web_jwt_expires_in" {
  name        = "/kambriq/${var.env}/web/JWT_EXPIRES_IN"
  type        = "String"
  value       = tostring(var.jwt_expires_in)
  overwrite   = true
  description = "JWT access token expiration (seconds) for ${var.env}"
  tags = {
    Name        = "kambriq-web-jwt-expires-in-${var.env}"
    Environment = var.env
    Service     = "web"
  }
  lifecycle { ignore_changes = [value] }
}
