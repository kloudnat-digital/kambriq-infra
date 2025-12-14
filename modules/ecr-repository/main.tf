# ECR Repository for Lambda Container Images
resource "aws_ecr_repository" "main" {
  name                 = var.repository_name
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    encryption_type = var.encryption_type
    kms_key         = var.kms_key_id != "" ? var.kms_key_id : null
  }

  tags = {
    Name = var.repository_name
    Env  = var.env
    Type = "lambda-container"
  }
}

# Lifecycle policy to keep only last N images
resource "aws_ecr_lifecycle_policy" "main" {
  repository = aws_ecr_repository.main.name

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

# Create placeholder Docker image for Lambda Container Image
# This is required because Lambda functions with package_type = "Image" need an existing image
# The CI/CD pipeline will replace this placeholder with the actual application image
resource "null_resource" "placeholder_image" {
  depends_on = [aws_ecr_repository.main]

  triggers = {
    repository_url = aws_ecr_repository.main.repository_url
    # Recreate if repository URL changes
  }

  provisioner "local-exec" {
    command = <<-EOT
      REPO_URI="${aws_ecr_repository.main.repository_url}"
      REGION="${var.aws_region}"
      
      echo "🐳 Creating placeholder Docker image for Lambda Container Image..."
      echo "   Repository: $REPO_URI"
      echo "   Region: $REGION"
      
      # Login to ECR (ignore errors - Docker might not be available)
      echo "🔐 Logging in to ECR..."
      if aws ecr get-login-password --region "$REGION" 2>/dev/null | \
         docker login --username AWS --password-stdin "$REPO_URI" 2>/dev/null; then
        echo "✅ ECR login successful"
      else
        echo "⚠️  Warning: Docker login failed. Make sure Docker is running and AWS credentials are configured."
        echo "   You can create the placeholder image manually using:"
        echo "   ./scripts/create-ecr-placeholder-image.sh ${aws_ecr_repository.main.name} $REGION"
        exit 0  # Don't fail terraform apply if Docker is not available
      fi
      
      # Pull AWS Lambda base image (ignore errors)
      echo "📥 Pulling AWS Lambda Node.js 20 base image..."
      if docker pull public.ecr.aws/lambda/nodejs:20 2>/dev/null; then
        echo "✅ Base image pulled successfully"
      else
        echo "⚠️  Warning: Failed to pull base image. Make sure Docker is running."
        echo "   You can create the placeholder image manually using:"
        echo "   ./scripts/create-ecr-placeholder-image.sh ${aws_ecr_repository.main.name} $REGION"
        exit 0  # Don't fail terraform apply if Docker is not available
      fi
      
      # Tag it for the ECR repository (ignore errors)
      echo "🏷️  Tagging image for ECR repository..."
      docker tag public.ecr.aws/lambda/nodejs:20 "$REPO_URI:latest" 2>/dev/null || {
        echo "⚠️  Warning: Failed to tag image."
        exit 0
      }
      
      # Push to ECR (ignore errors)
      echo "📤 Pushing placeholder image to ECR..."
      if docker push "$REPO_URI:latest" 2>/dev/null; then
        echo "✅ Placeholder image created successfully!"
      else
        echo "⚠️  Warning: Failed to push image to ECR."
        echo "   You can create the placeholder image manually using:"
        echo "   ./scripts/create-ecr-placeholder-image.sh ${aws_ecr_repository.main.name} $REGION"
        exit 0  # Don't fail terraform apply if Docker is not available
      fi
    EOT

    # Continue even if the command fails (Docker might not be available)
    on_failure = continue
  }
}
