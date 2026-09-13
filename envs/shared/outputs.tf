output "vpc_id" {
  description = "VPC ID"
  value       = module.shared.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.shared.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.shared.private_subnet_ids
}

output "nat_gateway_ids" {
  description = "NAT Gateway IDs"
  value       = module.shared.nat_gateway_ids
}

output "route53_zone_id" {
  description = "Route53 zone ID"
  value       = module.shared.route53_zone_id
}

output "route53_zone_name" {
  description = "Route53 zone name"
  value       = module.shared.route53_zone_name
}

output "route53_name_servers" {
  description = "Route53 name servers"
  value       = module.shared.route53_name_servers
}

output "github_oidc_provider_arn" {
  description = "GitHub Actions OIDC provider ARN"
  value       = aws_iam_openid_connect_provider.github.arn
}

output "github_actions_infra_role_arn" {
  description = "GitHub Actions role ARN for infra workflows"
  value       = aws_iam_role.github_actions_infra.arn
}

# The newsletter contact list lives here because SES permits one per account per
# region. envs/dev consumes both of these - an IAM policy resource ARN and the
# task's AWS_SES_CONTACT_LIST_NAME - so they cross by remote state, the way dev
# already reads the VPC and the subnets.
output "newsletter_contact_list_arn" {
  description = "ARN of the shared SES newsletter contact list"
  value       = aws_sesv2_contact_list.newsletter.arn
}

output "newsletter_contact_list_name" {
  description = "Name of the shared SES newsletter contact list"
  value       = aws_sesv2_contact_list.newsletter.contact_list_name
}
