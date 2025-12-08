output "database_url_parameter_name" {
  description = "SSM parameter name for DATABASE_URL"
  value       = aws_ssm_parameter.database_url.name
}

output "jwt_secret_parameter_name" {
  description = "SSM parameter name for JWT_SECRET"
  value       = aws_ssm_parameter.jwt_secret.name
}

output "frontend_url_parameter_name" {
  description = "SSM parameter name for FRONTEND_URL"
  value       = aws_ssm_parameter.frontend_url.name
}

output "ses_from_email_parameter_name" {
  description = "SSM parameter name for SES_FROM_EMAIL"
  value       = aws_ssm_parameter.ses_from_email.name
}
