locals {
  bucket_name = var.bucket_name != "" ? var.bucket_name : "kambriq-web-${var.env}"
}

# S3 Bucket pour le frontend Next.js static
resource "aws_s3_bucket" "main" {
  bucket = local.bucket_name

  tags = {
    Name = "kambriq-web-${var.env}"
    Env  = var.env
  }
}

# Block public access (CloudFront OAI accède via bucket policy)
resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Versioning (optionnel, peut être activé plus tard)
resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id

  versioning_configuration {
    status = "Disabled"
  }
}

# Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Bucket policy sera créée dans les environnements après la création de CloudFront

