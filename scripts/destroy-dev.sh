#!/bin/bash
# Script to destroy DEV infrastructure - KAMBRIQ v1.0
# Destroys resources in the correct order to avoid dependency issues

set -e

cd "$(dirname "$0")/../envs/dev"

echo "🗑️  Destroying KAMBRIQ DEV infrastructure (v1.0)..."
echo "⚠️  This will destroy ALL resources in the dev environment"
read -p "Are you sure? Type 'yes' to continue: " confirm

if [ "$confirm" != "yes" ]; then
    echo "❌ Aborted"
    exit 1
fi

echo ""
echo "📋 Destroying resources in order..."

# Step 1: Destroy SSM parameters first (they depend on other resources)
echo "1️⃣  Destroying SSM parameters..."
terraform destroy -target=module.ssm_app_parameters -auto-approve || true

# Step 2: Destroy API Gateway
echo "2️⃣  Destroying API Gateway..."
terraform destroy -target=module.api_gateway -auto-approve || true

# Step 3: Destroy Lambda functions
echo "3️⃣  Destroying Lambda functions..."
terraform destroy -target=module.lambda -auto-approve || true

# Step 4: Destroy Frontend (CloudFront + Lambda SSR)
echo "4️⃣  Destroying Frontend (CloudFront + Lambda SSR)..."
terraform destroy -target=module.frontend -auto-approve || true

# Step 5: Destroy ECR repositories
echo "5️⃣  Destroying ECR repositories..."
terraform destroy -target=module.ecr_api -auto-approve || true

# Step 6: Destroy IAM roles
echo "6️⃣  Destroying IAM roles..."
terraform destroy -target=module.iam -auto-approve || true

# Step 7: Destroy S3 buckets (if not protected)
echo "7️⃣  Destroying S3 buckets..."
terraform destroy -target=module.s3_media -auto-approve || true
# Note: verify_store bucket has prevent_destroy, may need manual deletion

# Step 8: Destroy RDS (last, as other resources may depend on it)
echo "8️⃣  Destroying RDS..."
terraform destroy -target=module.rds -auto-approve || true

# Step 9: Destroy Security Groups
echo "9️⃣  Destroying Security Groups..."
terraform destroy -target=aws_security_group.rds -auto-approve || true
terraform destroy -target=aws_security_group.lambda -auto-approve || true

# Step 10: Full destroy (cleanup any remaining resources)
echo "🔟 Final cleanup..."
terraform destroy -auto-approve || true

echo ""
echo "✅ Destruction complete!"
echo ""
echo "⚠️  Note: Some resources may need manual cleanup:"
echo "   - S3 buckets with prevent_destroy (verify_store)"
echo "   - SSM parameters (if you want to keep them)"
echo "   - CloudWatch Log Groups"
echo ""

