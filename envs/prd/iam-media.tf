# ============================================================================
# IAM access to the kambriq-media bucket — dev environment
# ============================================================================
# - Inline policy on the API ECS task role: full read/write/delete on the bucket
# (the dev-only developer-user grant is intentionally omitted for prod)
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

# The dev-only developer-user grant (a human IAM user with read/write to the
# media bucket) is deliberately NOT reproduced for prod: prod media holds clients'
# identity documents, and no standing human user should have bucket access. Only
# the API task role does, above.
