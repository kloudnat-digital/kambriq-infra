# ============================================================================
# Shared Infrastructure Outputs
# ============================================================================
# These outputs are consumed by dev and prod environments via remote_state
# ============================================================================

# VPC & Networking
output "vpc_id" {
  description = "VPC ID"
  value       = module.shared.vpc_id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = module.shared.vpc_cidr
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = module.shared.public_subnet_ids
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = module.shared.private_subnet_ids
}

output "all_subnet_ids" {
  description = "List of all subnet IDs (public + private)"
  value       = module.shared.all_subnet_ids
}

output "nat_gateway_id" {
  description = "NAT Gateway ID"
  value       = module.shared.nat_gateway_id
}

# Route53
output "route53_zone_id" {
  description = "Route53 hosted zone ID"
  value       = module.shared.route53_zone_id
}

output "route53_zone_name" {
  description = "Route53 hosted zone name"
  value       = module.shared.route53_zone_name
}

output "route53_name_servers" {
  description = "Route53 name servers (to configure in domain registrar)"
  value       = module.shared.route53_name_servers
}

# SES
output "ses_domain_identity_arn" {
  description = "SES domain identity ARN"
  value       = module.shared.ses_domain_identity_arn
}

output "ses_email_identity_arn" {
  description = "SES email identity ARN"
  value       = module.shared.ses_email_identity_arn
}

output "ses_from_email" {
  description = "[DEPRECATED] Default sender email address - Use environment-specific ses_from_email in dev/prod instead"
  value       = module.shared.ses_from_email
}

output "ses_domain_verification_token" {
  description = "SES domain verification token (for DNS)"
  value       = module.shared.ses_domain_verification_token
}

# ACM Certificates
output "api_certificate_arn" {
  description = "ACM certificate ARN for API Gateway"
  value       = module.shared.api_certificate_arn
}

# S3
output "logs_bucket_id" {
  description = "S3 bucket ID for logs"
  value       = module.shared.logs_bucket_id
}

output "artifacts_bucket_id" {
  description = "S3 bucket ID for artifacts"
  value       = module.shared.artifacts_bucket_id
}

# ============================================================================
# Bastion Outputs (shared between dev and prod)
# ============================================================================

output "bastion_public_ip" {
  description = "Public IP address of the bastion host (Elastic IP, shared between dev and prod)"
  value       = var.enable_bastion ? module.bastion[0].bastion_public_ip : null
}

output "bastion_instance_id" {
  description = "EC2 Instance ID of the bastion (shared between dev and prod)"
  value       = var.enable_bastion ? module.bastion[0].bastion_instance_id : null
}

output "bastion_ssh_command" {
  description = "SSH command example to connect to the bastion (shared between dev and prod)"
  value       = var.enable_bastion ? module.bastion[0].bastion_ssh_command : null
}

output "bastion_stop_command" {
  description = "Command to stop the bastion"
  value       = var.enable_bastion ? module.bastion[0].bastion_stop_command : null
}

output "bastion_start_command" {
  description = "Command to start the bastion"
  value       = var.enable_bastion ? module.bastion[0].bastion_start_command : null
}
