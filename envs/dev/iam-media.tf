# ============================================================================
# IAM access to the kambriq-media bucket — dev environment
# ============================================================================
# - Inline policy on the API ECS task role: full read/write/delete on the bucket
# - Managed policy attached to the kambriq-app-dev IAM user: read/write only
#   (no DeleteObject — only ECS can delete)
# Both reference module.s3_media.bucket_arn so the policies follow the bucket
# if it is ever renamed via var.s3_media_bucket_name.
# ============================================================================

# ---------------------------------------------------------------------------
# ECS task role: media bucket access
# ---------------------------------------------------------------------------
resource "aws_iam_role_policy" "api_media_bucket" {
  name = "kambriq-media-${var.env}-access"
  role = module.iam_roles_ecs.task_api_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "MediaBucketFullAccess"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:HeadObject",
        ]
        Resource = [
          module.s3_media.bucket_arn,
          "${module.s3_media.bucket_arn}/*",
        ]
      }
    ]
  })
}

# ---------------------------------------------------------------------------
# Pre-existing developer IAM user (created out of band)
# ---------------------------------------------------------------------------
data "aws_iam_user" "kambriq_app" {
  user_name = var.media_developer_user_name
}

# ---------------------------------------------------------------------------
# Managed policy: developer read/write to media bucket (no delete)
# ---------------------------------------------------------------------------
resource "aws_iam_policy" "media_bucket_developer" {
  name        = "kambriq-media-${var.env}-developer"
  description = "Developer read/write access to the kambriq-media-${var.env} bucket. No DeleteObject — only ECS can delete."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "MediaBucketDevReadWrite"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:HeadObject",
        ]
        Resource = [
          module.s3_media.bucket_arn,
          "${module.s3_media.bucket_arn}/*",
        ]
      }
    ]
  })

  tags = {
    Name        = "kambriq-media-${var.env}-developer"
    Project     = "kambriq"
    Environment = var.env
    Service     = "media"
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_user_policy_attachment" "media_bucket_developer" {
  user       = data.aws_iam_user.kambriq_app.user_name
  policy_arn = aws_iam_policy.media_bucket_developer.arn
}
