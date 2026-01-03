output "task_api_role_arn" {
  description = "IAM Role ARN for ECS Task (API)"
  value       = aws_iam_role.task_api.arn
}

output "task_web_role_arn" {
  description = "IAM Role ARN for ECS Task (Web)"
  value       = aws_iam_role.task_web.arn
}

