output "repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.main.repository_url
}

output "repository_arn" {
  description = "ARN of the ECR repository"
  value       = aws_ecr_repository.main.arn
}

output "repository_name" {
  description = "Name of the ECR repository"
  value       = aws_ecr_repository.main.name
}

output "placeholder_image_ready" {
  description = "Indicates that placeholder image creation has been attempted (may have failed if Docker unavailable)"
  value       = null_resource.placeholder_image.id
}
