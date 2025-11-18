output "api_id" {
  description = "API Gateway ID"
  value       = aws_apigatewayv2_api.main.id
}

output "api_endpoint" {
  description = "API Gateway endpoint URL"
  value       = aws_apigatewayv2_api.main.api_endpoint
}

output "api_url" {
  description = "API Gateway full URL"
  value       = "https://${aws_apigatewayv2_api.main.api_endpoint}"
}

output "api_arn" {
  description = "API Gateway ARN"
  value       = aws_apigatewayv2_api.main.arn
}

output "custom_domain_name" {
  description = "Custom domain name (if configured)"
  value       = var.domain_name != "" ? var.domain_name : null
}

