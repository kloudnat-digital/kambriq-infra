# ============================================================================
# Outputs - KAMBRIQ v2.0 DEV
# ============================================================================

output "cloudfront_domain" {
  description = "CloudFront distribution domain name"
  value       = module.cloudfront_v2.distribution_domain_name
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.alb.alb_dns_name
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = module.rds_postgres.db_endpoint
}

output "ecr_api_repo_uri" {
  description = "ECR repository URI for API"
  value       = module.ecr_api.repository_url
}

output "ecr_web_repo_uri" {
  description = "ECR repository URI for Web"
  value       = module.ecr_web.repository_url
}

output "ecs_cluster_name" {
  description = "ECS Cluster name"
  value       = module.ecs_cluster.cluster_name
}

output "ecs_service_api_name" {
  description = "ECS Service name for API"
  value       = module.ecs_service_api.service_name
}

output "ecs_service_web_name" {
  description = "ECS Service name for Web"
  value       = module.ecs_service_web.service_name
}

