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

output "database_url_kamnet_parameter_arn" {
  description = "SSM parameter ARN for DATABASE_URL_KAMNET"
  value       = try(aws_ssm_parameter.database_url_kamnet[0].arn, null)
}

output "database_url_lands_parameter_arn" {
  description = "SSM parameter ARN for DATABASE_URL_LANDS"
  value       = try(aws_ssm_parameter.database_url_lands[0].arn, null)
}

output "database_url_extra_parameter_arns" {
  description = "SSM parameter ARNs for extra DATABASE_URL_*"
  value = {
    for key, param in aws_ssm_parameter.database_url_extra :
    "DATABASE_URL_${key}" => param.arn
  }
}

output "db_password_parameter_name" {
  description = "SSM parameter name for DB_PASSWORD"
  value       = aws_ssm_parameter.db_password.name
}

output "db_password_parameter_arn" {
  description = "SSM parameter ARN for DB_PASSWORD"
  value       = aws_ssm_parameter.db_password.arn
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

output "email_from_parameter_name" {
  description = "SSM parameter name for EMAIL_FROM"
  value       = aws_ssm_parameter.email_from.name
}

output "email_from_name_parameter_name" {
  description = "SSM parameter name for EMAIL_FROM_NAME"
  value       = aws_ssm_parameter.email_from_name.name
}

output "web_nextauth_secret_parameter_arn" {
  description = "SSM parameter ARN for NEXTAUTH_SECRET (web)"
  value       = aws_ssm_parameter.web_nextauth_secret.arn
}

output "web_jwt_expires_in_parameter_arn" {
  description = "SSM parameter ARN for JWT_EXPIRES_IN (web)"
  value       = aws_ssm_parameter.web_jwt_expires_in.arn
}
