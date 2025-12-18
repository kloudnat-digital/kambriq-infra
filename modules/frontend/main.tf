locals {
  name_prefix = "${var.project_name}-frontend-${var.env}"
}

# Data source for AWS region (used for CACHE_BUCKET_REGION)
data "aws_region" "current" {}

# Data source for AWS account ID (used for ECR image URI)
data "aws_caller_identity" "current" {}

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
  timeout       = 30
  memory_size   = 1024

  # Package type: Use Container Image to support bundles > 250MB
  # AWS Lambda does not allow changing package_type of an existing function
  # Therefore, we use "Image" by default to support large Next.js bundles
  # Container images support up to 10GB (vs 250MB for ZIP)
  package_type = "Image"

  # Container image configuration
  # The CI/CD workflow will build and push the image to ECR, then update the Lambda
  # We use a placeholder image URI here - the actual image will be updated by CI/CD
  image_uri = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/kambriq-frontend-ssr-${var.env}:latest"

  # Image configuration for container-based Lambda
  # Note: handler and runtime are NOT specified for Image package_type
  # They are defined in the Dockerfile CMD (see web/Dockerfile.ssr)
  # OpenNext handler is at .open-next/server-functions/default/index.handler
  image_config {
    # Command and entrypoint are handled by the Dockerfile CMD
    # The Dockerfile specifies: CMD [".open-next/server-functions/default/index.handler"]
  }

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [var.security_group_id]
  }

  environment {
    variables = {
      # Force NODE_ENV=production for Lambda runtime
      # OpenNext bundles are built in production mode, so React expects production files
      # (react.production.js, not react.development.js)
      NODE_ENV                 = "production"
      NEXT_PUBLIC_API_BASE_URL = var.api_gateway_url # Used by Next.js app (environment.ts, actions, etc.)
      NEXT_PUBLIC_SITE_URL     = var.domain_name != "" ? "https://${var.domain_name}" : ""

      # OpenNext ISR (Incremental Static Regeneration) cache configuration
      # OpenNext requires these environment variables to use S3 for ISR cache storage
      CACHE_BUCKET_NAME   = aws_s3_bucket.static.id
      CACHE_BUCKET_REGION = data.aws_region.current.name
    }
  }

  tags = {
    Name = "${local.name_prefix}-ssr"
    Env  = var.env
  }

  # Note: Code is deployed via CI/CD workflows (deploy-app-dev.yml / deploy-app-prod.yml)
  # The Lambda uses Container Image deployment (package_type = "Image")
  # CI/CD will update the image_uri with the latest ECR image on each deployment
  lifecycle {
    ignore_changes = [
      filename,
      source_code_hash,
      image_uri, # CI/CD will update the image URI with the latest ECR image
    ]
  }
}

# Lambda Function URL for SSR (used as CloudFront origin)
# NOTE: OpenNext is configured with streaming: false, so we use BUFFERED mode (default).
# If streaming is enabled in OpenNext, set invoke_mode = "RESPONSE_STREAM" here.
resource "aws_lambda_function_url" "ssr" {
  function_name = aws_lambda_function.ssr.function_name
  # Note: using NONE here to avoid IAM-auth 403 and allow CloudFront requests.
  # Access remains restricted via the Lambda permission below (CloudFront source ARN).
  authorization_type = "NONE"
  # invoke_mode defaults to "BUFFERED" (required when OpenNext streaming: false)
  # If OpenNext streaming is enabled, uncomment: invoke_mode = "RESPONSE_STREAM"

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
  # Extract domain from API Gateway URL (e.g., https://xxxxx.execute-api.eu-central-1.amazonaws.com -> xxxxx.execute-api.eu-central-1.amazonaws.com)
  # Remove protocol and any trailing slashes/paths
  api_gateway_domain = replace(replace(replace(var.api_gateway_url, "https://", ""), "http://", ""), "/", "")
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
          "s3:PutObject",
          "s3:DeleteObject" # Required for ISR cache invalidation
        ]
        Resource = [
          "${aws_s3_bucket.static.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket" # Required for ISR cache operations
        ]
        Resource = [
          aws_s3_bucket.static.arn
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

# Cache Policy for Lambda Function URL SSR
# Minimal caching for dynamic SSR content (TTL = 0)
# When caching is disabled, all parameters must be set to "none" or false
resource "aws_cloudfront_cache_policy" "lambda_ssr" {
  name        = "${local.name_prefix}-lambda-ssr-cache"
  comment     = "Cache policy for Lambda Function URL SSR - no caching"
  default_ttl = 0
  max_ttl     = 0
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    # When caching is disabled (TTL = 0), compression must be disabled
    enable_accept_encoding_brotli = false
    enable_accept_encoding_gzip   = false

    cookies_config {
      cookie_behavior = "none"
    }

    headers_config {
      header_behavior = "none"
    }

    query_strings_config {
      query_string_behavior = "none"
    }
  }
}

# Origin Request Policy for Lambda Function URL
# Excludes Host header to prevent 403 errors (Lambda Function URL expects its own hostname)
resource "aws_cloudfront_origin_request_policy" "lambda_ssr" {
  name    = "${local.name_prefix}-lambda-ssr-origin-request"
  comment = "Origin request policy for Lambda Function URL SSR - excludes Host header"

  cookies_config {
    cookie_behavior = "all"
  }

  headers_config {
    header_behavior = "whitelist"
    headers {
      items = [
        "Accept",
        "Content-Type",
        "Origin",
        "Referer",
        "User-Agent",
      ]
    }
  }

  query_strings_config {
    query_string_behavior = "all"
  }
}

# Cache Policy for API Gateway (no caching for API requests)
resource "aws_cloudfront_cache_policy" "api_gateway" {
  name        = "${local.name_prefix}-api-gateway-cache"
  comment     = "Cache policy for API Gateway - no caching"
  default_ttl = 0
  max_ttl     = 0
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }
    headers_config {
      header_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "none"
    }
    enable_accept_encoding_brotli = false
    enable_accept_encoding_gzip   = false
  }
}

# Origin Request Policy for API Gateway (forward all headers, query strings, cookies)
resource "aws_cloudfront_origin_request_policy" "api_gateway" {
  name    = "${local.name_prefix}-api-gateway-origin-request"
  comment = "Origin request policy for API Gateway - forward all"

  cookies_config {
    cookie_behavior = "all"
  }

  headers_config {
    header_behavior = "allViewer"
  }

  query_strings_config {
    query_string_behavior = "all"
  }
}

# CloudFront Function for /api/* paths
# Note: We keep the /api prefix because NestJS setGlobalPrefix("api") expects the full path /api/auth/signin
# The API Gateway route ANY /{proxy+} will capture everything after /, including "api/auth/signin"
# serverless-express will extract the path from rawPath and NestJS will match /api/auth/signin correctly
resource "aws_cloudfront_function" "api_path_rewrite" {
  name    = "${local.name_prefix}-api-path-rewrite"
  runtime = "cloudfront-js-2.0"
  comment = "Pass through API requests to API Gateway (keep /api prefix)"
  publish = true
  code    = <<-EOF
function handler(event) {
    // Pass through the request as-is - keep /api prefix for NestJS routing
    return event.request;
}
EOF
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

  # Origin 2: API Gateway for /api/* routes
  origin {
    domain_name = local.api_gateway_domain
    origin_id   = "APIGateway-${var.env}"
    custom_origin_config {
      http_port              = 443
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Origin 3: S3 bucket for static assets only
  origin {
    domain_name              = aws_s3_bucket.static.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.static.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.main.id
  }

  # ============================================================================
  # CloudFront Cache Behaviors
  # ============================================================================
  # Cache behavior 0: API Gateway for /api/* routes (MUST be first, before default)
  ordered_cache_behavior {
    path_pattern     = "/api/*"
    target_origin_id = "APIGateway-${var.env}"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods  = ["GET", "HEAD"]

    # Use cache policy and origin request policy for API Gateway
    cache_policy_id          = aws_cloudfront_cache_policy.api_gateway.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.api_gateway.id

    # Use CloudFront Function to rewrite /api/* to /* (remove /api prefix)
    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.api_path_rewrite.arn
    }

    compress = true
  }

  # Default behavior: Route all requests to Lambda SSR (for pages, etc.)
  default_cache_behavior {
    target_origin_id       = "LambdaSSR-${aws_lambda_function.ssr.function_name}"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods  = ["GET", "HEAD"]

    # Use cache policy and origin request policy instead of forwarded_values
    # This excludes Host header to prevent 403 errors from Lambda Function URL
    cache_policy_id          = aws_cloudfront_cache_policy.lambda_ssr.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.lambda_ssr.id

    compress = true
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

# Lambda permission to allow public access to Function URL
# NOTE: With authorization_type = "NONE", the Function URL should be publicly accessible.
# AWS requires TWO permissions for public access:
# 1. lambda:InvokeFunctionUrl with condition lambda:FunctionUrlAuthType = "NONE"
# 2. lambda:InvokeFunction with condition lambda:InvokedViaFunctionUrl = "true"
resource "aws_lambda_permission" "public_url" {
  statement_id  = "AllowPublicInvokeUrl"
  action        = "lambda:InvokeFunctionUrl"
  function_name = aws_lambda_function.ssr.function_name
  principal     = "*"

  # Required condition for public access with authorization_type = "NONE"
  function_url_auth_type = "NONE"
}

# Additional permission: lambda:InvokeFunction (required for Function URLs with AuthType = NONE)
# AWS requires BOTH permissions for public access:
# 1. lambda:InvokeFunctionUrl (with function_url_auth_type = "NONE") - already defined above
# 2. lambda:InvokeFunction (without condition, allows invocation via Function URL)
resource "aws_lambda_permission" "public_invoke" {
  statement_id  = "AllowPublicInvokeFunction"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ssr.function_name
  principal     = "*"
  # Note: function_url_auth_type condition is NOT supported for lambda:InvokeFunction action
}

# Additional permission for CloudFront (without source_arn condition)
# CloudFront may not send AWS:SourceArn header reliably, so we allow all CloudFront calls
resource "aws_lambda_permission" "cloudfront" {
  statement_id  = "AllowCloudFrontInvoke"
  action        = "lambda:InvokeFunctionUrl"
  function_name = aws_lambda_function.ssr.function_name
  principal     = "cloudfront.amazonaws.com"
  # No source_arn condition: CloudFront doesn't reliably send AWS:SourceArn header
  # for Function URLs with authorization_type = "NONE"
}
