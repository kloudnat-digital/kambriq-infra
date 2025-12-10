locals {
  name_prefix = "${var.project_name}-frontend-${var.env}"
}

# ============================================================================
# S3 Bucket for Static Assets
# ============================================================================

resource "aws_s3_bucket" "static" {
  bucket = "${var.project_name}-static-${var.env}"

  tags = {
    Name = "${local.name_prefix}-static"
    Env  = var.env
  }
}

resource "aws_s3_bucket_versioning" "static" {
  bucket = aws_s3_bucket.static.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "static" {
  bucket = aws_s3_bucket.static.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "static" {
  bucket = aws_s3_bucket.static.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ============================================================================
# OpenNext Bundle Management
# ============================================================================
# 
# OpenNext bundle (web/web-<sha>.zip) contains:
#   - .open-next/assets/ → Static assets for S3 (deployed separately via CI/CD)
#   - .open-next/server/ → Lambda functions for SSR (multiple functions)
#   - .open-next/cache/ → ISR cache configuration
#   - .open-next/image-optimization/ → Lambda@Edge for image optimization
#
# IMPORTANT: The OpenNext bundle ZIP cannot be used directly as a Lambda function.
# The bundle must be extracted and individual Lambda functions from .open-next/server/
# must be deployed separately.
#
# Current approach:
#   - Terraform creates a placeholder Lambda function (dummy) for initial setup
#   - CI/CD workflow (frontend-dev.yml in kambriq repo) extracts the bundle and
#     deploys static assets to S3 (.open-next/assets/)
#   - Lambda functions from .open-next/server/ should be deployed via a separate
#     CI/CD step or Terraform module that extracts the bundle
#
# Future improvement:
#   - Create a Terraform module or external script that extracts .open-next/server/
#     from the bundle and creates Lambda functions for each route
#   - Or use a Lambda layer approach for OpenNext server functions
#
# For now, this module focuses on:
#   1. S3 bucket for static assets (deployed by CI/CD)
#   2. CloudFront distribution (serves static assets from S3)
#   3. Placeholder Lambda SSR function (to be replaced by extracted OpenNext functions)
#
# ============================================================================

# Dummy zip for initial Lambda SSR (code deployed via deploy-app-dev.yml / deploy-app-prod.yml)
data "archive_file" "dummy_ssr" {
  type        = "zip"
  output_path = "${path.module}/dummy-ssr.zip"
  source {
    content  = "exports.handler = async (event) => { return { statusCode: 200, body: JSON.stringify({ message: 'OpenNext SSR Lambda - code deployed via deploy-app-dev.yml / deploy-app-prod.yml' }) }; };"
    filename = "index.js"
  }
}

# Lambda function for SSR (placeholder - actual OpenNext functions should be extracted from bundle)
# Note: This is a simplified placeholder. Full OpenNext deployment requires:
#   - Extracting .open-next/server/ from the bundle ZIP
#   - Creating Lambda functions for each route in .open-next/server/
#   - Configuring CloudFront to use these Lambda functions for SSR routes
resource "aws_lambda_function" "ssr" {
  function_name = "${local.name_prefix}-ssr"
  role          = aws_iam_role.lambda.arn
  runtime       = "nodejs20.x"
  # OpenNext generates handler at .open-next/server-functions/default/index.mjs
  # Lambda with Node.js 20.x supports ESM modules (.mjs)
  # Handler format: path/to/file.handlerFunction (Lambda resolves .mjs automatically)
  handler     = ".open-next/server-functions/default/index.handler"
  timeout     = 30
  memory_size = 1024

  # Source code: Always use dummy placeholder (code deployed via deploy-app-dev.yml / deploy-app-prod.yml)
  filename         = data.archive_file.dummy_ssr.output_path
  source_code_hash = data.archive_file.dummy_ssr.output_base64sha256

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [var.security_group_id]
  }

  environment {
    variables = {
      NODE_ENV             = var.env
      NEXT_PUBLIC_API_URL  = var.api_gateway_url
      NEXT_PUBLIC_SITE_URL = var.domain_name != "" ? "https://${var.domain_name}" : ""
    }
  }

  tags = {
    Name = "${local.name_prefix}-ssr"
    Env  = var.env
  }

  # Note: When OpenNext bundle is provided, this Lambda should be updated via CI/CD
  # to use the extracted functions from .open-next/server/
  lifecycle {
    ignore_changes = [
      filename,
      source_code_hash,
    ]
  }
}

# Lambda Function URL for SSR (used as CloudFront origin)
resource "aws_lambda_function_url" "ssr" {
  function_name = aws_lambda_function.ssr.function_name
  # Note: using NONE here to avoid IAM-auth 403 and allow CloudFront requests.
  # Access remains restricted via the Lambda permission below (CloudFront source ARN).
  authorization_type = "NONE"

  cors {
    allow_credentials = false
    allow_origins     = ["*"]
    allow_methods     = ["*"]
    allow_headers     = ["*"]
    expose_headers    = ["*"]
    max_age           = 3600
  }
}

# Extract domain from Lambda Function URL for CloudFront origin
# Function URL format: https://<id>.lambda-url.<region>.on.aws
# CloudFront needs just the domain without https:// and without any trailing slashes
locals {
  lambda_function_url_domain = replace(replace(aws_lambda_function_url.ssr.function_url, "https://", ""), "/", "")
}

# Lambda permission to allow CloudFront to invoke Function URL
# This will be set after CloudFront distribution is created (see below)

# TODO: Create additional Lambda functions for OpenNext routes
# OpenNext generates multiple Lambda functions in .open-next/server/:
#   - default function (main SSR handler)
#   - image optimization function (Lambda@Edge)
#   - ISR revalidation function
# These should be extracted from the bundle and deployed separately

# ============================================================================
# IAM Role for Lambda Functions
# ============================================================================

resource "aws_iam_role" "lambda" {
  name = "${local.name_prefix}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${local.name_prefix}-lambda-role"
    Env  = var.env
  }
}

resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "lambda_s3" {
  name = "${local.name_prefix}-lambda-s3"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = [
          "${aws_s3_bucket.static.arn}/*"
        ]
      }
    ]
  })
}

# ============================================================================
# CloudFront Distribution
# ============================================================================

# OAC for S3 bucket (static assets)
resource "aws_cloudfront_origin_access_control" "main" {
  name                              = "${local.name_prefix}-oac-s3"
  description                       = "OAC for S3 static assets - ${local.name_prefix}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# OAC for Lambda Function URL (SSR) - kept but not referenced when auth = "NONE"
# Keep in place to avoid destroy-in-use errors; not used by any origin.
resource "aws_cloudfront_origin_access_control" "lambda" {
  name                              = "${local.name_prefix}-oac-lambda"
  description                       = "OAC for Lambda SSR Function URL - ${local.name_prefix} (unused when auth=NONE)"
  origin_access_control_origin_type = "lambda"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_cloudfront_distribution" "main" {
  enabled         = true
  is_ipv6_enabled = true
  comment         = "KAMBRIQ frontend distribution - ${var.env}"
  # No default_root_object for OpenNext SSR (Lambda handles all routes including /)
  price_class = var.price_class

  # CloudFront alternate domain names (aliases)
  # Managed via Terraform from envs/dev/main.tf or envs/prod/main.tf
  aliases = var.domain_name != "" ? [var.domain_name] : []

  # ============================================================================
  # CloudFront Origins
  # ============================================================================
  # Origin 1: Lambda Function URL for SSR (default for all routes)
  # With authorization_type = "NONE", we don't use OAC (no signing needed)
  # Access is restricted via Lambda permission with CloudFront source ARN
  origin {
    domain_name = local.lambda_function_url_domain
    origin_id   = "LambdaSSR-${aws_lambda_function.ssr.function_name}"
    custom_origin_config {
      http_port              = 443
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Origin 2: S3 bucket for static assets only
  origin {
    domain_name              = aws_s3_bucket.static.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.static.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.main.id
  }

  # ============================================================================
  # CloudFront Cache Behaviors
  # ============================================================================
  # Default behavior: Route all requests to Lambda SSR (for pages, API routes, etc.)
  default_cache_behavior {
    target_origin_id       = "LambdaSSR-${aws_lambda_function.ssr.function_name}"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods  = ["GET", "HEAD"]

    # Forward query strings, headers, and cookies for SSR
    forwarded_values {
      query_string = true
      headers      = ["*"]
      cookies {
        forward = "all"
      }
    }

    # Minimal caching for SSR (dynamic content)
    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
    compress    = true
  }

  # Cache behavior 1: Static Next.js assets (/_next/static/*)
  ordered_cache_behavior {
    path_pattern     = "/_next/static/*"
    target_origin_id = "S3-${aws_s3_bucket.static.id}"

    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD"]

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    # Aggressive caching for static assets (1 year)
    min_ttl     = 31536000
    default_ttl = 31536000
    max_ttl     = 31536000
    compress    = true
  }

  # Cache behavior 2: Other static assets (/assets/*)
  ordered_cache_behavior {
    path_pattern     = "/assets/*"
    target_origin_id = "S3-${aws_s3_bucket.static.id}"

    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD"]

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    # Aggressive caching for static assets (1 year)
    min_ttl     = 31536000
    default_ttl = 31536000
    max_ttl     = 31536000
    compress    = true
  }

  # No custom_error_response for 404/403 - let Lambda SSR handle errors

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = var.certificate_arn == ""
    acm_certificate_arn            = var.certificate_arn != "" ? var.certificate_arn : null
    ssl_support_method             = var.certificate_arn != "" ? "sni-only" : null
    minimum_protocol_version       = var.certificate_arn != "" ? "TLSv1.2_2021" : null
  }

  tags = {
    Name = local.name_prefix
    Env  = var.env
  }
}

# S3 bucket policy for CloudFront with OAC
resource "aws_s3_bucket_policy" "static" {
  bucket = aws_s3_bucket.static.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.static.arn,
          "${aws_s3_bucket.static.arn}/*"
        ]
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.main.arn
          }
        }
      }
    ]
  })

  depends_on = [aws_cloudfront_distribution.main]
}

# Lambda permission to allow CloudFront to invoke Function URL
resource "aws_lambda_permission" "cloudfront" {
  statement_id  = "AllowCloudFrontInvoke"
  action        = "lambda:InvokeFunctionUrl"
  function_name = aws_lambda_function.ssr.function_name
  principal     = "cloudfront.amazonaws.com"
  source_arn    = "${aws_cloudfront_distribution.main.arn}/*"
}
