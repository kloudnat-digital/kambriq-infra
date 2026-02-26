output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs_cluster.cluster_name
}

output "ecs_cluster_arn" {
  description = "ECS cluster ARN"
  value       = module.ecs_cluster.cluster_arn
}

output "ecs_service_api_name" {
  description = "ECS service name for API"
  value       = module.ecs_service_api.service_name
}

output "ecs_task_definition_family_api" {
  description = "ECS task definition family for API"
  value       = module.ecs_service_api.task_definition_family
}

output "ecs_task_definition_arn_api" {
  description = "ECS task definition ARN for API"
  value       = module.ecs_service_api.task_definition_arn
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = data.terraform_remote_state.shared.outputs.private_subnet_ids
}

output "ecs_security_group_id" {
  description = "ECS security group ID"
  value       = aws_security_group.ecs.id
}

output "task_execution_role_arn" {
  description = "Task execution role ARN"
  value       = module.ecs_cluster.task_execution_role_arn
}

output "task_api_role_arn" {
  description = "Task role ARN for API"
  value       = module.iam_roles_ecs.task_api_role_arn
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.alb.alb_dns_name
}

output "bastion_instance_id" {
  description = "Bastion instance ID"
  value       = module.bastion.instance_id
}

output "bastion_public_ip" {
  description = "Bastion public IP"
  value       = module.bastion.public_ip
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = module.rds.db_endpoint
}

output "redis_endpoint" {
  description = "Redis primary endpoint"
  value       = module.redis.primary_endpoint_address
}

output "database_url_core_parameter_arn" {
  description = "SSM ARN for DATABASE_URL_CORE"
  value       = module.ssm_app_parameters.database_url_core_parameter_arn
}

output "database_url_kbs_parameter_arn" {
  description = "SSM ARN for DATABASE_URL_KBS"
  value       = module.ssm_app_parameters.database_url_kbs_parameter_arn
}

output "db_password_parameter_arn" {
  description = "SSM ARN for DB_PASSWORD"
  value       = module.ssm_app_parameters.db_password_parameter_arn
}

output "jwt_secret_parameter_arn" {
  description = "SSM ARN for JWT_SECRET"
  value       = module.ssm_app_parameters.jwt_secret_parameter_arn
}

output "github_actions_role_arn" {
  description = "GitHub Actions role ARN for deployments"
  value       = aws_iam_role.github_actions.arn
}

output "ecr_api_repository_url" {
  description = "ECR repository URL for API"
  value       = module.ecr_api.repository_url
}

output "ecr_web_repository_url" {
  description = "ECR repository URL for Web"
  value       = module.ecr_web.repository_url
}
