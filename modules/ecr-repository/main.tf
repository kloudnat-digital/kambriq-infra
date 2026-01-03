# ============================================================================
# ECR Repository Module - KAMBRIQ v2.0
# ============================================================================
# References existing ECR repositories (created manually or via CI/CD)
# Applies lifecycle policies to manage image retention
# ============================================================================

# Data source to reference existing ECR repository
# If repository doesn't exist, Terraform will fail and you'll need to create it first
# Repositories are typically created via GitHub Actions workflows or manually
data "aws_ecr_repository" "main" {
  name = var.repository_name
}

# Lifecycle policy to keep only last N images
# Note: Repository must exist before applying this policy
resource "aws_ecr_lifecycle_policy" "main" {
  repository = data.aws_ecr_repository.main.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last ${var.image_retention_count} images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.image_retention_count
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
