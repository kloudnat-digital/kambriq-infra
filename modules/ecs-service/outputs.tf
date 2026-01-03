# ============================================================================
# Outputs - ECS Service Module
# ============================================================================

output "service_id" {
  description = "ECS Service ID"
  value       = aws_ecs_service.main.id
}

output "service_arn" {
  description = "ECS Service ARN"
  value       = aws_ecs_service.main.arn
}

output "service_name" {
  description = "ECS Service name"
  value       = aws_ecs_service.main.name
}

output "task_definition_arn" {
  description = "ECS Task Definition ARN"
  value       = aws_ecs_task_definition.main.arn
}

output "task_definition_family" {
  description = "ECS Task Definition family"
  value       = aws_ecs_task_definition.main.family
}

output "log_group_name" {
  description = "CloudWatch Log Group name"
  value       = aws_cloudwatch_log_group.service.name
}
