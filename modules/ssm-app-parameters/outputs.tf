output "database_url_core_parameter_name" {
  description = "SSM parameter name for DATABASE_URL_CORE"
  value       = aws_ssm_parameter.database_url_core.name
}

output "database_url_kbs_parameter_name" {
  description = "SSM parameter name for DATABASE_URL_KBS"
  value       = aws_ssm_parameter.database_url_kbs.name
}

output "database_url_core_parameter_arn" {
  description = "SSM parameter ARN for DATABASE_URL_CORE"
  value       = aws_ssm_parameter.database_url_core.arn
}

output "database_url_kbs_parameter_arn" {
  description = "SSM parameter ARN for DATABASE_URL_KBS"
  value       = aws_ssm_parameter.database_url_kbs.arn
}

output "jwt_secret_parameter_name" {
  description = "SSM parameter name for JWT_SECRET"
  value       = aws_ssm_parameter.jwt_secret.name
}

output "jwt_secret_parameter_arn" {
  description = "SSM parameter ARN for JWT_SECRET"
  value       = aws_ssm_parameter.jwt_secret.arn
}

output "frontend_url_parameter_name" {
  description = "SSM parameter name for FRONTEND_URL"
  value       = aws_ssm_parameter.frontend_url.name
}

output "ses_from_email_parameter_name" {
  description = "SSM parameter name for SES_FROM_EMAIL"
  value       = aws_ssm_parameter.ses_from_email.name
}

output "email_from_parameter_name" {
  description = "SSM parameter name for EMAIL_FROM"
  value       = aws_ssm_parameter.email_from.name
}

output "email_from_name_parameter_name" {
  description = "SSM parameter name for EMAIL_FROM_NAME"
  value       = aws_ssm_parameter.email_from_name.name
}
