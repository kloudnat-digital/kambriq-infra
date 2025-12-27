variable "env" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "db_host" {
  description = "Database host (RDS endpoint)"
  type        = string
}

variable "db_port" {
  description = "Database port"
  type        = number
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "db_username" {
  description = "Database username"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Database password (from SSM /kambriq/{env}/db/password)"
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "JWT secret key. If empty, will try to read from existing SSM parameter /kambriq/{env}/api/jwt_secret"
  type        = string
  sensitive   = true
  default     = ""
}

variable "frontend_url" {
  description = "Frontend URL (CloudFront URL or custom domain)"
  type        = string
}

variable "ses_from_email" {
  description = "SES sender email address"
  type        = string
}

# ============================================================================
# Additional API runtime parameters (non-sensitive)
# ============================================================================

variable "default_visitor_role_id" {
  description = "Default visitor role id"
  type        = string
  default     = "550e8400-e29b-41d4-a716-446655440002"
}

variable "password_reset_token_expiration_hours" {
  description = "Password reset token expiration (hours)"
  type        = number
  default     = 24
}

variable "referral_code_expiration_hours" {
  description = "Referral code expiration (hours)"
  type        = number
  default     = 24
}

variable "referral_invitation_token_expiration_hours" {
  description = "Referral invitation token expiration (hours)"
  type        = number
  default     = 24
}

variable "jwt_expires_in" {
  description = "JWT access token expiration (seconds)"
  type        = number
  default     = 900
}

variable "jwt_refresh_expires_in" {
  description = "JWT refresh token expiration (seconds)"
  type        = number
  default     = 604800
}

variable "jwt_algorithm" {
  description = "JWT algorithm"
  type        = string
  default     = "HS256"
}

variable "cookie_secure" {
  description = "Cookie secure flag (true/false as string)"
  type        = string
  default     = "true"
}

variable "cookie_same_site" {
  description = "Cookie SameSite policy (strict/lax/none)"
  type        = string
  default     = "strict"
}

variable "cookie_domain" {
  description = "Cookie domain (optional, can be empty)"
  type        = string
  default     = ""
}

variable "verification_cost" {
  description = "Verification cost"
  type        = number
  default     = 99
}

variable "aws_ses_to_admin_contact" {
  description = "Admin contact email for verify notifications"
  type        = string
  default     = "contact@kambriq.com"
}

variable "contact_whatsapp_number" {
  description = "WhatsApp contact number used in templates"
  type        = string
  default     = "+237670000000"
}

variable "paypal_environment" {
  description = "PayPal environment (sandbox/production)"
  type        = string
  default     = "sandbox"
}

# ============================================================================
# Web build-time parameters (public) stored under /kambriq/{env}/web/*
# ============================================================================

variable "api_gateway_base_url" {
  description = "API Gateway base URL (used for NEXT_PUBLIC_API_BASE_URL)"
  type        = string
  default     = ""
}

variable "frontend_cloudfront_domain" {
  description = "CloudFront domain name (used for NEXT_PUBLIC_SITE_URL)"
  type        = string
  default     = ""
}

variable "next_public_jwt_expires_in" {
  description = "NEXT_PUBLIC_JWT_EXPIRES_IN (seconds)"
  type        = number
  default     = 900
}

variable "next_public_jwt_refresh_buffer_seconds" {
  description = "NEXT_PUBLIC_JWT_REFRESH_BUFFER_SECONDS (seconds)"
  type        = number
  default     = 180
}

variable "next_public_stale_time" {
  description = "NEXT_PUBLIC_STALE_TIME (seconds)"
  type        = number
  default     = 300
}

variable "next_public_refetch_interval" {
  description = "NEXT_PUBLIC_REFETCH_INTERVAL (seconds)"
  type        = number
  default     = 300
}

variable "next_public_paypal_client_id" {
  description = "NEXT_PUBLIC_PAYPAL_CLIENT_ID (public)"
  type        = string
  default     = ""
}

# ============================================================================
# Web runtime parameters (SSR) stored under /kambriq/{env}/web/*
# These are loaded by SSR Lambda at runtime (not build-time)
# ============================================================================

variable "nextauth_url" {
  description = "NEXTAUTH_URL - Base URL for NextAuth (CloudFront custom domain or CloudFront domain)"
  type        = string
  default     = ""
}

variable "nextauth_secret" {
  description = "NEXTAUTH_SECRET - Secret key for NextAuth JWT signing (SecureString)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "api_base_url" {
  description = "API_BASE_URL - Direct API Gateway URL for SSR server-to-server calls (not CloudFront)"
  type        = string
  default     = ""
}
