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
