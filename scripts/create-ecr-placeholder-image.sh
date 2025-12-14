#!/bin/bash
# Script to create a placeholder Docker image in ECR for Lambda Container Image
# Usage: ./create-ecr-placeholder-image.sh <repository-name> <aws-region>

set -e

REPO_NAME="${1:-kambriq-api-dev}"
AWS_REGION="${2:-eu-central-1}"

if [ -z "$REPO_NAME" ]; then
  echo "❌ Error: Repository name is required"
  echo "Usage: $0 <repository-name> [aws-region]"
  exit 1
fi

echo "🐳 Creating placeholder Docker image for Lambda Container Image..."
echo "   Repository: $REPO_NAME"
echo "   Region: $AWS_REGION"

# Get AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
if [ -z "$AWS_ACCOUNT_ID" ]; then
  echo "❌ Error: Cannot get AWS Account ID. Make sure AWS credentials are configured."
  exit 1
fi

ECR_REPO_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPO_NAME}"

# Check if repository exists
if ! aws ecr describe-repositories --repository-names "$REPO_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
  echo "❌ Error: ECR repository '$REPO_NAME' does not exist."
  echo "   Please create it first with Terraform or manually."
  exit 1
fi

# Login to ECR
echo "🔐 Logging in to ECR..."
aws ecr get-login-password --region "$AWS_REGION" | \
  docker login --username AWS --password-stdin "$ECR_REPO_URI"

# Pull AWS Lambda base image
echo "📥 Pulling AWS Lambda Node.js 20 base image..."
docker pull public.ecr.aws/lambda/nodejs:20

# Tag it for the ECR repository
echo "🏷️  Tagging image for ECR repository..."
docker tag public.ecr.aws/lambda/nodejs:20 "${ECR_REPO_URI}:latest"

# Push to ECR
echo "📤 Pushing placeholder image to ECR..."
docker push "${ECR_REPO_URI}:latest"

echo "✅ Placeholder image created successfully!"
echo "   Image URI: ${ECR_REPO_URI}:latest"
echo ""
echo "💡 You can now create the Lambda function with Terraform."
echo "   The CI/CD pipeline will replace this placeholder with the actual application image."
