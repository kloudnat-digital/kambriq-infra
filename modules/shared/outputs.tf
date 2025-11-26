# ============================================================================
# VPC & Networking Outputs
# ============================================================================

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "all_subnet_ids" {
  description = "List of all subnet IDs (public + private)"
  value       = concat(aws_subnet.public[*].id, aws_subnet.private[*].id)
}

output "nat_gateway_id" {
  description = "NAT Gateway ID"
  value       = aws_nat_gateway.main.id
}

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = aws_internet_gateway.main.id
}

# ============================================================================
# Route53 Outputs
# ============================================================================

output "route53_zone_id" {
  description = "Route53 hosted zone ID"
  value       = aws_route53_zone.main.zone_id
}

output "route53_zone_name" {
  description = "Route53 hosted zone name"
  value       = aws_route53_zone.main.name
}

output "route53_name_servers" {
  description = "Route53 name servers"
  value       = aws_route53_zone.main.name_servers
}

# ============================================================================
# SES Outputs
# ============================================================================

output "ses_domain_identity_arn" {
  description = "SES domain identity ARN"
  value       = aws_ses_domain_identity.main.arn
}

output "ses_email_identity_arn" {
  description = "SES email identity ARN"
  value       = aws_ses_email_identity.main.arn
}

output "ses_from_email" {
  description = "Default sender email address"
  value       = var.ses_from_email
}

output "ses_domain_verification_token" {
  description = "SES domain verification token (for DNS)"
  value       = aws_ses_domain_identity.main.verification_token
}

output "ses_dkim_tokens" {
  description = "SES DKIM tokens for DNS configuration"
  value       = aws_ses_domain_dkim.main.dkim_tokens
}

# ============================================================================
# ACM Certificate Outputs
# ============================================================================

output "api_certificate_arn" {
  description = "ACM certificate ARN for API Gateway"
  value       = aws_acm_certificate_validation.api.certificate_arn
}

# Note: CloudFront certificates must be in us-east-1.
# If needed, create a separate certificate in us-east-1 in the root module.
output "cloudfront_certificate_arn" {
  description = "ACM certificate ARN for CloudFront (must be created in us-east-1 separately)"
  value       = null
}

# ============================================================================
# S3 Outputs
# ============================================================================

output "logs_bucket_id" {
  description = "S3 bucket ID for logs"
  value       = var.enable_s3_logs ? aws_s3_bucket.logs[0].id : null
}

output "logs_bucket_arn" {
  description = "S3 bucket ARN for logs"
  value       = var.enable_s3_logs ? aws_s3_bucket.logs[0].arn : null
}

output "artifacts_bucket_id" {
  description = "S3 bucket ID for artifacts"
  value       = var.enable_s3_artifacts ? aws_s3_bucket.artifacts[0].id : null
}

output "artifacts_bucket_arn" {
  description = "S3 bucket ARN for artifacts"
  value       = var.enable_s3_artifacts ? aws_s3_bucket.artifacts[0].arn : null
}

