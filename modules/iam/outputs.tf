output "lambda_role_arn" {
  description = "IAM role ARN for Lambda"
  value       = aws_iam_role.lambda.arn
}

output "lambda_role_name" {
  description = "IAM role name for Lambda"
  value       = aws_iam_role.lambda.name
}

