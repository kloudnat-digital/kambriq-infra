# ============================================================================
# SSM Application Parameters Module
# ============================================================================
# This module creates SSM Parameter Store parameters for application runtime
# configuration. Values are constructed from Terraform outputs and variables.
#
# Parameters created (API):
# - /kambriq/{env}/api/DATABASE_URL_CORE (SecureString)
# - /kambriq/{env}/api/DATABASE_URL_KBS (SecureString)
# - /kambriq/{env}/api/JWT_SECRET (SecureString)
# - /kambriq/{env}/api/FRONTEND_URL (String)
# - Additional runtime parameters required by the NestJS API
# ============================================================================

locals {
  # Construct DATABASE_URLs from RDS components
  # Format: postgresql://{username}:{password}@{host}:{port}/{database}?schema=public
  database_url_core = "postgresql://${var.db_username}:${var.db_password}@${var.db_host}:${var.db_port}/${var.db_core_name}?schema=public&sslmode=require&uselibpqcompat=true"
  database_url_kbs  = "postgresql://${var.db_username}:${var.db_password}@${var.db_host}:${var.db_port}/${var.db_kbs_name}?schema=public&sslmode=require&uselibpqcompat=true"

  database_url_kamnet    = var.db_kamnet_name != "" ? "postgresql://${var.db_username}:${var.db_password}@${var.db_host}:${var.db_port}/${var.db_kamnet_name}?schema=public&sslmode=require&uselibpqcompat=true" : ""
  database_url_lands     = var.db_lands_name != "" ? "postgresql://${var.db_username}:${var.db_password}@${var.db_host}:${var.db_port}/${var.db_lands_name}?schema=public&sslmode=require&uselibpqcompat=true" : ""
  database_url_verify    = var.db_verify_name != "" ? "postgresql://${var.db_username}:${var.db_password}@${var.db_host}:${var.db_port}/${var.db_verify_name}?schema=public&sslmode=require&uselibpqcompat=true" : ""
  database_url_valuation = var.db_valuation_name != "" ? "postgresql://${var.db_username}:${var.db_password}@${var.db_host}:${var.db_port}/${var.db_valuation_name}?schema=public&sslmode=require&uselibpqcompat=true" : ""

  database_url_extra = {
    for key, name in var.db_extra :
    upper(key) => "postgresql://${var.db_username}:${var.db_password}@${var.db_host}:${var.db_port}/${name}?schema=public&sslmode=require&uselibpqcompat=true"
  }
}

# ============================================================================
# DATABASE_URL_CORE - Core PostgreSQL connection string
# ============================================================================
resource "aws_ssm_parameter" "db_password" {
  name  = "/kambriq/${var.env}/db/DB_PASSWORD"
  type  = "SecureString"
  value = var.db_password

  description = "RDS master password for ${var.env} environment"
  tags = {
    Name        = "kambriq-db-password-${var.env}"
    Environment = var.env
    Service     = "db"
  }
}

resource "aws_ssm_parameter" "database_url_core" {
  name  = "/kambriq/${var.env}/api/DATABASE_URL_CORE"
  type  = "SecureString"
  value = local.database_url_core

  description = "Core PostgreSQL connection string for ${var.env} environment"
  tags = {
    Name        = "kambriq-api-database-url-core-${var.env}"
    Environment = var.env
    Service     = "api"
  }
}

# ============================================================================
# DATABASE_URL_KBS - KBS PostgreSQL connection string
# ============================================================================
resource "aws_ssm_parameter" "database_url_kbs" {
  name  = "/kambriq/${var.env}/api/DATABASE_URL_KBS"
  type  = "SecureString"
  value = local.database_url_kbs

  description = "KBS PostgreSQL connection string for ${var.env} environment"
  tags = {
    Name        = "kambriq-api-database-url-kbs-${var.env}"
    Environment = var.env
    Service     = "api"
  }
}

# ============================================================================
# Optional domain databases (created only when names are provided)
# ============================================================================
resource "aws_ssm_parameter" "database_url_kamnet" {
  count = var.db_kamnet_name != "" ? 1 : 0
  name  = "/kambriq/${var.env}/api/DATABASE_URL_KAMNET"
  type  = "SecureString"
  value = local.database_url_kamnet

  description = "Kamnet PostgreSQL connection string for ${var.env} environment"
  tags = {
    Name        = "kambriq-api-database-url-kamnet-${var.env}"
    Environment = var.env
    Service     = "api"
  }
}

resource "aws_ssm_parameter" "database_url_lands" {
  count = var.db_lands_name != "" ? 1 : 0
  name  = "/kambriq/${var.env}/api/DATABASE_URL_LANDS"
  type  = "SecureString"
  value = local.database_url_lands

  description = "Lands PostgreSQL connection string for ${var.env} environment"
  tags = {
    Name        = "kambriq-api-database-url-lands-${var.env}"
    Environment = var.env
    Service     = "api"
  }
}

resource "aws_ssm_parameter" "database_url_verify" {
  count = var.db_verify_name != "" ? 1 : 0
  name  = "/kambriq/${var.env}/api/DATABASE_URL_VERIFY"
  type  = "SecureString"
  value = local.database_url_verify

  description = "Verify PostgreSQL connection string for ${var.env} environment"
  tags = {
    Name        = "kambriq-api-database-url-verify-${var.env}"
    Environment = var.env
    Service     = "api"
  }
}

resource "aws_ssm_parameter" "database_url_valuation" {
  count = var.db_valuation_name != "" ? 1 : 0
  name  = "/kambriq/${var.env}/api/DATABASE_URL_VALUATION"
  type  = "SecureString"
  value = local.database_url_valuation

  description = "Valuation PostgreSQL connection string for ${var.env} environment"
  tags = {
    Name        = "kambriq-api-database-url-valuation-${var.env}"
    Environment = var.env
    Service     = "api"
  }
}

resource "aws_ssm_parameter" "database_url_extra" {
  for_each = local.database_url_extra
  name     = "/kambriq/${var.env}/api/DATABASE_URL_${each.key}"
  type     = "SecureString"
  value    = each.value

  description = "Extra PostgreSQL connection string for ${var.env} environment"
  tags = {
    Name        = "kambriq-api-database-url-${lower(each.key)}-${var.env}"
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
    var.use_existing_jwt_secret && length(data.aws_ssm_parameter.jwt_secret_existing) > 0
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

# ============================================================================
# Core API runtime parameters (NestJS)
# ============================================================================
resource "aws_ssm_parameter" "node_env" {
  name  = "/kambriq/${var.env}/api/NODE_ENV"
  type  = "String"
  value = var.node_env

  description = "Runtime environment for ${var.env}"
  tags = {
    Name        = "kambriq-api-node-env-${var.env}"
    Environment = var.env
    Service     = "api"
  }
}

resource "aws_ssm_parameter" "port" {
  name  = "/kambriq/${var.env}/api/PORT"
  type  = "String"
  value = tostring(var.port)

  description = "API listening port for ${var.env}"
  tags = {
    Name        = "kambriq-api-port-${var.env}"
    Environment = var.env
    Service     = "api"
  }
}

resource "aws_ssm_parameter" "api_prefix" {
  name  = "/kambriq/${var.env}/api/API_PREFIX"
  type  = "String"
  value = var.api_prefix

  description = "API prefix for ${var.env}"
  tags = {
    Name        = "kambriq-api-prefix-${var.env}"
    Environment = var.env
    Service     = "api"
  }
}

resource "aws_ssm_parameter" "jwt_access_expiration" {
  name  = "/kambriq/${var.env}/api/JWT_ACCESS_EXPIRATION"
  type  = "String"
  value = var.jwt_access_expiration

  description = "JWT access token lifetime for ${var.env}"
  tags = {
    Name        = "kambriq-api-jwt-access-expiration-${var.env}"
    Environment = var.env
    Service     = "api"
  }
}

resource "aws_ssm_parameter" "jwt_refresh_expiration" {
  name  = "/kambriq/${var.env}/api/JWT_REFRESH_EXPIRATION"
  type  = "String"
  value = var.jwt_refresh_expiration

  description = "JWT refresh token lifetime for ${var.env}"
  tags = {
    Name        = "kambriq-api-jwt-refresh-expiration-${var.env}"
    Environment = var.env
    Service     = "api"
  }
}

resource "aws_ssm_parameter" "cors_origins" {
  name  = "/kambriq/${var.env}/api/CORS_ORIGINS"
  type  = "String"
  value = var.cors_origins

  description = "CORS allowed origins for ${var.env}"
  tags = {
    Name        = "kambriq-api-cors-origins-${var.env}"
    Environment = var.env
    Service     = "api"
  }
}

resource "aws_ssm_parameter" "throttle_ttl" {
  name  = "/kambriq/${var.env}/api/THROTTLE_TTL"
  type  = "String"
  value = tostring(var.throttle_ttl)

  description = "Rate limit window (ms) for ${var.env}"
  tags = {
    Name        = "kambriq-api-throttle-ttl-${var.env}"
    Environment = var.env
    Service     = "api"
  }
}

resource "aws_ssm_parameter" "throttle_limit" {
  name  = "/kambriq/${var.env}/api/THROTTLE_LIMIT"
  type  = "String"
  value = tostring(var.throttle_limit)

  description = "Rate limit max requests for ${var.env}"
  tags = {
    Name        = "kambriq-api-throttle-limit-${var.env}"
    Environment = var.env
    Service     = "api"
  }
}

resource "aws_ssm_parameter" "redis_host" {
  name  = "/kambriq/${var.env}/api/REDIS_HOST"
  type  = "String"
  value = var.redis_host

  description = "Redis host for ${var.env}"
  tags = {
    Name        = "kambriq-api-redis-host-${var.env}"
    Environment = var.env
    Service     = "api"
  }
}

resource "aws_ssm_parameter" "redis_port" {
  name  = "/kambriq/${var.env}/api/REDIS_PORT"
  type  = "String"
  value = tostring(var.redis_port)

  description = "Redis port for ${var.env}"
  tags = {
    Name        = "kambriq-api-redis-port-${var.env}"
    Environment = var.env
    Service     = "api"
  }
}

resource "aws_ssm_parameter" "aws_s3_bucket" {
  name  = "/kambriq/${var.env}/api/AWS_S3_BUCKET"
  type  = "String"
  value = var.aws_s3_bucket

  description = "S3 bucket for uploads in ${var.env}"
  tags = {
    Name        = "kambriq-api-aws-s3-bucket-${var.env}"
    Environment = var.env
    Service     = "api"
  }
}

resource "aws_ssm_parameter" "aws_region" {
  name  = "/kambriq/${var.env}/api/AWS_REGION"
  type  = "String"
  value = var.aws_region

  description = "AWS region for SDK in ${var.env}"
  tags = {
    Name        = "kambriq-api-aws-region-${var.env}"
    Environment = var.env
    Service     = "api"
  }
}

resource "aws_ssm_parameter" "aws_s3_region" {
  name  = "/kambriq/${var.env}/api/AWS_S3_REGION"
  type  = "String"
  value = var.aws_s3_region

  description = "AWS region for the S3 media bucket in ${var.env}"
  tags = {
    Name        = "kambriq-api-aws-s3-region-${var.env}"
    Environment = var.env
    Service     = "api"
  }
}

resource "aws_ssm_parameter" "s3_presigned_url_ttl_seconds" {
  name  = "/kambriq/${var.env}/api/S3_PRESIGNED_URL_TTL_SECONDS"
  type  = "String"
  value = tostring(var.s3_presigned_url_ttl_seconds)

  description = "TTL (seconds) for S3 presigned URLs in ${var.env}"
  tags = {
    Name        = "kambriq-api-s3-presigned-url-ttl-seconds-${var.env}"
    Environment = var.env
    Service     = "api"
  }
}

resource "aws_ssm_parameter" "s3_max_upload_size_mb" {
  name  = "/kambriq/${var.env}/api/S3_MAX_UPLOAD_SIZE_MB"
  type  = "String"
  value = tostring(var.s3_max_upload_size_mb)

  description = "Max single-object upload size (MB) for ${var.env}"
  tags = {
    Name        = "kambriq-api-s3-max-upload-size-mb-${var.env}"
    Environment = var.env
    Service     = "api"
  }
}

resource "aws_ssm_parameter" "email_from" {
  name  = "/kambriq/${var.env}/api/EMAIL_FROM"
  type  = "String"
  value = var.email_from

  description = "Email sender address for ${var.env}"
  tags = {
    Name        = "kambriq-api-email-from-${var.env}"
    Environment = var.env
    Service     = "api"
  }
}

resource "aws_ssm_parameter" "email_from_name" {
  name  = "/kambriq/${var.env}/api/EMAIL_FROM_NAME"
  type  = "String"
  value = var.email_from_name

  description = "Email sender display name for ${var.env}"
  tags = {
    Name        = "kambriq-api-email-from-name-${var.env}"
    Environment = var.env
    Service     = "api"
  }
}

resource "aws_ssm_parameter" "salt_rounds" {
  name  = "/kambriq/${var.env}/api/SALT_ROUNDS"
  type  = "String"
  value = tostring(var.salt_rounds)

  description = "bcrypt salt rounds for ${var.env}"
  tags = {
    Name        = "kambriq-api-salt-rounds-${var.env}"
    Environment = var.env
    Service     = "api"
  }
}

resource "aws_ssm_parameter" "aws_access_key_id" {
  count = var.aws_access_key_id != "" ? 1 : 0
  name  = "/kambriq/${var.env}/api/AWS_ACCESS_KEY_ID"
  type  = "SecureString"
  value = var.aws_access_key_id

  description = "AWS access key for ${var.env} (optional, prefer IAM roles)"
  tags = {
    Name        = "kambriq-api-aws-access-key-id-${var.env}"
    Environment = var.env
    Service     = "api"
  }
}

resource "aws_ssm_parameter" "aws_secret_access_key" {
  count = var.aws_secret_access_key != "" ? 1 : 0
  name  = "/kambriq/${var.env}/api/AWS_SECRET_ACCESS_KEY"
  type  = "SecureString"
  value = var.aws_secret_access_key

  description = "AWS secret key for ${var.env} (optional, prefer IAM roles)"
  tags = {
    Name        = "kambriq-api-aws-secret-access-key-${var.env}"
    Environment = var.env
    Service     = "api"
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
  count = var.jwt_secret == "" && var.use_existing_jwt_secret ? 1 : 0
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
  name = "/kambriq/${var.env}/web/NEXTAUTH_SECRET"
  type = "SecureString"
  # Use provided value, or generate new random password
  # Note: If parameter already exists and is imported, lifecycle ignore_changes will protect the value
  value       = var.nextauth_secret != "" ? var.nextauth_secret : random_password.web_nextauth_secret[0].result
  overwrite   = false # Prevent overwriting existing secrets (will fail if exists and value differs)
  description = "NextAuth JWT signing secret for ${var.env} (auto-generated if not provided)"
  tags = {
    Name          = "kambriq-web-nextauth-secret-${var.env}"
    Environment   = var.env
    Service       = "web"
    ManagedBy     = "Terraform"
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
