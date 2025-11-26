# Frontend
output "frontend_url" {
  description = "CloudFront URL for frontend"
  value       = module.cloudfront.distribution_url
}

output "frontend_domain" {
  description = "CloudFront domain name"
  value       = module.cloudfront.distribution_domain_name
}

# API
output "api_url" {
  description = "API Gateway URL"
  value       = module.api_gateway.api_url
}

output "api_endpoint" {
  description = "API Gateway endpoint"
  value       = module.api_gateway.api_endpoint
}

# Database
output "db_host" {
  description = "Database host"
  value       = module.rds.db_host
}

output "db_port" {
  description = "Database port"
  value       = module.rds.db_port
}

output "db_name" {
  description = "Database name"
  value       = module.rds.db_name
}

output "db_endpoint" {
  description = "Database endpoint (host:port)"
  value       = "${module.rds.db_host}:${module.rds.db_port}"
}

# S3
output "s3_media_bucket" {
  description = "S3 media bucket name"
  value       = module.s3_media.bucket_id
}

output "s3_static_bucket" {
  description = "S3 static site bucket name"
  value       = module.s3_static.bucket_id
}

# SES
output "ses_from_email" {
  description = "SES sender email"
  value       = module.ses.from_email
}

output "ses_identity_arn" {
  description = "SES email identity ARN"
  value       = module.ses.email_identity_arn
}

output "ses_domain_identity_arn" {
  description = "SES domain identity ARN"
  value       = module.ses.domain_identity_arn
}

output "ses_domain_verification_token" {
  description = "SES domain verification token (à ajouter dans DNS)"
  value       = module.ses.domain_identity_verification_token
  sensitive   = false
}

# Lambda
output "lambda_function_name" {
  description = "Lambda function name"
  value       = module.lambda.function_name
}

output "lambda_function_arn" {
  description = "Lambda function ARN"
  value       = module.lambda.function_arn
}

