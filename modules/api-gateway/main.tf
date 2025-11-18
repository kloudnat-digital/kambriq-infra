# API Gateway HTTP API
resource "aws_apigatewayv2_api" "main" {
  name          = "kambriq-api-${var.env}"
  protocol_type = "HTTP"
  description   = "KAMBRIQ API Gateway - ${var.env}"

  cors_configuration {
    allow_origins = ["*"] # À restreindre en production
    allow_methods = ["*"]
    allow_headers = ["*"]
    max_age       = 300
  }

  tags = {
    Name = "kambriq-api-${var.env}"
    Env  = var.env
  }
}

# Integration Lambda
resource "aws_apigatewayv2_integration" "lambda" {
  api_id = aws_apigatewayv2_api.main.id

  integration_type   = "AWS_PROXY"
  integration_uri     = var.lambda_function_arn
  integration_method  = "POST"
  payload_format_version = "2.0"
}

# Permission pour API Gateway d'invoquer Lambda
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

# Route par défaut (catch-all)
resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# Route pour toutes les méthodes HTTP
resource "aws_apigatewayv2_route" "proxy" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# Stage
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_rate_limit  = 100
    throttling_burst_limit = 50
  }

  tags = {
    Name = "kambriq-api-${var.env}"
    Env  = var.env
  }
}

# Custom domain (optionnel)
resource "aws_apigatewayv2_domain_name" "main" {
  count       = var.domain_name != "" ? 1 : 0
  domain_name = var.domain_name

  domain_name_configuration {
    certificate_arn = var.certificate_arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }

  tags = {
    Name = "kambriq-api-${var.env}"
    Env  = var.env
  }
}

# API mapping pour custom domain
resource "aws_apigatewayv2_api_mapping" "main" {
  count       = var.domain_name != "" ? 1 : 0
  api_id      = aws_apigatewayv2_api.main.id
  domain_name = aws_apigatewayv2_domain_name.main[0].id
  stage       = aws_apigatewayv2_stage.default.id
}

