# ============================================================================
# AWS Region
# ============================================================================
output "region" {
  description = "AWS region"
  value       = var.aws_region
}

# ============================================================================
# Frontend (OpenNext - CloudFront + S3 Static + Lambda SSR)
# ============================================================================
output "frontend_cloudfront_domain" {
  description = "CloudFront distribution domain name"
  value       = module.frontend.cloudfront_domain_name
}

output "frontend_cloudfront_url" {
  description = "Full CloudFront URL (https://...)"
  value       = module.frontend.cloudfront_url
}

output "frontend_s3_bucket_name" {
  description = "S3 bucket name for static frontend site"
  value       = module.frontend.s3_bucket_id
}

# ============================================================================
# Media S3 Buckets
# ============================================================================
# Note: Currently only one media bucket exists (private). Both outputs
# reference the same bucket. If separate public/private buckets are needed,
# create an additional S3 bucket module.
output "media_s3_public_bucket_name" {
  description = "S3 bucket name for public media (currently same as private)"
  value       = module.s3_media.bucket_id
}

output "media_s3_private_bucket_name" {
  description = "S3 bucket name for private media"
  value       = module.s3_media.bucket_id
}

# ============================================================================
# API Gateway
# ============================================================================
output "api_gateway_base_url" {
  description = "API Gateway base URL (full URL with https://)"
  value       = module.api_gateway.api_url
}

# ============================================================================
# RDS Database
# ============================================================================
output "rds_endpoint" {
  description = "RDS database endpoint (host:port)"
  value       = "${module.rds.db_host}:${module.rds.db_port}"
}

output "rds_db_name" {
  description = "RDS database name"
  value       = module.rds.db_name
}

output "rds_username" {
  description = "RDS database master username (password stored in SSM Parameter Store)"
  value       = module.rds.db_username
  sensitive   = true
}

# ============================================================================
# SES (Email)
# ============================================================================
# SES resources are in the shared infrastructure stack
output "ses_domain_identity_arn" {
  description = "SES domain identity ARN"
  value       = try(data.terraform_remote_state.shared.outputs.ses_domain_identity_arn, null)
}

output "ses_from_email" {
  description = "SES sender email address (environment-specific)"
  value       = var.ses_from_email
}

# ============================================================================
# Lambda
# ============================================================================
output "lambda_function_name" {
  description = "Lambda function name"
  value       = module.lambda.function_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (for cache invalidation)"
  value       = module.frontend.cloudfront_distribution_id
}

