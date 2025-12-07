locals {
  function_name = var.function_name != "" ? var.function_name : "kambriq-api-${var.env}"
}

# Dummy zip file pour initialiser la fonction (sera remplacé par le vrai code via CI/CD)
data "archive_file" "dummy" {
  type        = "zip"
  output_path = "${path.module}/dummy.zip"
  source {
    content  = "exports.handler = async (event) => { return { statusCode: 200, body: JSON.stringify({ message: 'Lambda initialized - deploy code via CI/CD' }) }; };"
    filename = "index.js"
  }
}

# Lambda Function
resource "aws_lambda_function" "main" {
  function_name = local.function_name
  runtime       = var.runtime
  handler       = var.handler
  role          = var.role_arn
  timeout       = var.timeout
  memory_size   = var.memory_size

  # Source code: Always use dummy placeholder (code deployed via deploy-app-dev.yml / deploy-app-prod.yml)
  filename         = data.archive_file.dummy.output_path
  source_code_hash = var.source_code_hash != "" ? var.source_code_hash : data.archive_file.dummy.output_base64sha256

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [var.security_group_id]
  }

  environment {
    variables = {
      NODE_ENV        = var.env
      DB_HOST         = var.db_host
      DB_PORT         = tostring(var.db_port)
      DB_NAME         = var.db_name
      DB_USERNAME     = var.db_username
      DB_PASSWORD     = var.db_password
      S3_MEDIA_BUCKET = var.s3_media_bucket
      SES_FROM_EMAIL  = var.ses_from_email
      JWT_SECRET      = var.jwt_secret
    }
  }

  tags = {
    Name = local.function_name
    Env  = var.env
  }
}

