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
resource "aws_ssm_parameter" "jwt_secret" {
  name = "/kambriq/${var.env}/api/JWT_SECRET"
  type = "SecureString"
  # Use provided value, or try to read from existing SSM (lowercase), or placeholder
  value = var.jwt_secret != "" ? var.jwt_secret : try(
    data.aws_ssm_parameter.jwt_secret_existing[0].value,
    "CHANGE-ME-GENERATE-A-SECRET-MIN-32-CHARS"
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
# Note: This data source will fail if the parameter doesn't exist, but we handle that
# with try() in the resource value above
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
