locals {
  function_name = var.function_name != "" ? var.function_name : "kambriq-api-${var.env}"
}

# Lambda Function (Container Image)
resource "aws_lambda_function" "main" {
  function_name = local.function_name
  role          = var.role_arn
  timeout       = var.timeout
  memory_size   = var.memory_size
  package_type  = "Image"

  # Container image: Use provided image_uri or default to ECR repository URL with latest tag
  # Note: The image must exist in ECR before creating the Lambda function.
  # The ECR module creates a placeholder image automatically via null_resource.
  # CI/CD will build and push the actual image, then update this Lambda function.
  image_uri = var.image_uri != "" ? var.image_uri : "${var.ecr_repository_url}:latest"

  # Allow Terraform to ignore image_uri changes (CI/CD will manage image updates)
  lifecycle {
    ignore_changes = [image_uri]
  }

  # Wait for placeholder image to be created (if Docker is available)
  # If Docker is not available, user must create placeholder manually using the script
  depends_on = [var.ecr_placeholder_ready]


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

