locals {
  bucket_name = var.bucket_name != "" ? var.bucket_name : "kambriq-media-${var.env}"

  base_tags = {
    Name        = local.bucket_name
    Project     = var.project_name
    Environment = var.env
    Service     = "media"
    ManagedBy   = "terraform"
  }
}

# S3 bucket for application media and documents (private)
resource "aws_s3_bucket" "main" {
  bucket = local.bucket_name

  tags = merge(local.base_tags, var.extra_tags)
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Versioning. AWS S3 forbids returning to "Disabled" once a bucket has been
# Enabled — the off state is "Suspended". Map the boolean accordingly.
resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id

  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}

# Server-side encryption (SSE-S3 / AES256)
resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Lifecycle: tmp staging expiration + lands archival to STANDARD_IA
resource "aws_s3_bucket_lifecycle_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    id     = "expire-tmp-uploads"
    status = "Enabled"

    filter {
      prefix = var.tmp_prefix
    }

    expiration {
      days = var.tmp_expiration_days
    }
  }

  rule {
    id     = "archive-lands-to-ia"
    status = "Enabled"

    filter {
      prefix = var.lands_prefix
    }

    transition {
      days          = var.lands_ia_transition_days
      storage_class = "STANDARD_IA"
    }
  }
}

# CORS — allow uploads/downloads from the app frontends
resource "aws_s3_bucket_cors_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  cors_rule {
    allowed_methods = var.cors_allowed_methods
    allowed_origins = var.cors_allowed_origins
    allowed_headers = var.cors_allowed_headers
    expose_headers  = var.cors_expose_headers
    max_age_seconds = var.cors_max_age_seconds
  }
}
