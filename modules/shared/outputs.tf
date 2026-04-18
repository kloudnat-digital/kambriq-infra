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
  value       = aws_nat_gateway.main[0].id
}

output "nat_gateway_ids" {
  description = "NAT Gateway IDs"
  value       = aws_nat_gateway.main[*].id
}

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = aws_internet_gateway.main.id
}

# ============================================================================
# Route53 Outputs
# ============================================================================
# Route53 hosted zone is created manually in AWS Console.
# These outputs reflect the existing zone referenced via data source.
# See docs/adr/ADR-005-production-automation-prerequisites.md for the bootstrap guide.

output "route53_zone_id" {
  description = "Route53 hosted zone ID (provided via variable or data source, created manually in AWS Console)"
  value       = local.route53_zone != null ? local.route53_zone.zone_id : null
}

output "route53_zone_name" {
  description = "Route53 hosted zone name"
  value       = local.route53_zone != null ? local.route53_zone.name : null
}

output "route53_name_servers" {
  description = "Route53 name servers"
  value       = local.route53_zone != null ? local.route53_zone.name_servers : []
}

# ============================================================================
# SES Outputs
# ============================================================================
# SES identities are created manually in AWS Console.
# These outputs reflect the ARNs and values provided via variables.
# SES and ACM certificates are managed manually - Terraform only consumes ARNs passed via tfvars.
# See docs/adr/ADR-005-production-automation-prerequisites.md for the bootstrap guide.

output "ses_domain_identity_arn" {
  description = "SES domain identity ARN (provided via variable, created manually in AWS Console)"
  value       = var.ses_domain_identity_arn != "" ? var.ses_domain_identity_arn : null
}

output "ses_email_identity_arn" {
  description = "SES email identity ARN (provided via variable, created manually in AWS Console)"
  value       = var.ses_email_identity_arn != "" ? var.ses_email_identity_arn : null
}

output "ses_domain" {
  description = "SES domain (e.g., kambriq.com)"
  value       = var.ses_domain
}

output "ses_region" {
  description = "AWS region where SES identities are created (e.g., eu-central-1)"
  value       = var.ses_region
}

output "ses_from_email" {
  description = "SES sender email address (e.g., noreply@kambriq.com)"
  value       = var.ses_from_email
}

# ============================================================================
# ACM Certificate Outputs
# ============================================================================
# ACM certificates are created manually in AWS Console.
# These outputs reflect the ARNs provided via variables.
# SES and ACM certificates are managed manually - Terraform only consumes ARNs passed via tfvars.
# See docs/adr/ADR-005-production-automation-prerequisites.md for the bootstrap guide.

output "api_certificate_arn" {
  description = "ACM certificate ARN for API Gateway (provided via variable, created manually in AWS Console, must be in eu-central-1)"
  value       = var.api_acm_certificate_arn != "" ? var.api_acm_certificate_arn : null
}

output "cloudfront_certificate_arn" {
  description = "ACM certificate ARN for CloudFront (provided via variable, created manually in AWS Console, must be in us-east-1)"
  value       = var.cloudfront_acm_certificate_arn != "" ? var.cloudfront_acm_certificate_arn : null
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

