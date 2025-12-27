#!/bin/bash
set -euo pipefail

# ============================================================================
# Deploy NextAuth Routing Fix
# ============================================================================
# This script deploys all fixes for NextAuth routing and configuration
#
# Usage:
#   ./scripts/deploy-nextauth-fix.sh <env>
#
# Example:
#   ./scripts/deploy-nextauth-fix.sh dev
# ============================================================================

ENV="${1:-dev}"

if [[ "$ENV" != "dev" && "$ENV" != "prod" ]]; then
  echo "Error: Environment must be 'dev' or 'prod'"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_DIR="$ROOT_DIR/envs/$ENV"

echo "=========================================="
echo "Deploying NextAuth Fix for $ENV"
echo "=========================================="
echo ""

# Step 1: Generate and store NextAuth SSM parameters
echo "Step 1: Setting up NextAuth SSM parameters..."
"$SCRIPT_DIR/setup-nextauth-ssm.sh" "$ENV" || {
  echo "Warning: SSM setup failed, continuing with Terraform (may create parameters)"
}

echo ""

# Step 2: Apply Terraform changes
echo "Step 2: Applying Terraform changes..."
cd "$ENV_DIR"

# Initialize Terraform if needed
if [[ ! -d ".terraform" ]]; then
  echo "Initializing Terraform..."
  terraform init
fi

# Plan to see what will change
echo "Running terraform plan..."
terraform plan -out=tfplan

# Apply changes
echo ""
echo "Applying Terraform changes..."
terraform apply tfplan

# Clean up plan file
rm -f tfplan

cd "$ROOT_DIR"

echo ""
echo "✅ Terraform deployment complete!"
echo ""

# Step 3: Invalidate CloudFront cache
echo "Step 3: Invalidating CloudFront cache..."
cd "$ENV_DIR"

DISTRIBUTION_ID=$(terraform output -raw cloudfront_distribution_id 2>/dev/null || echo "")

if [[ -n "$DISTRIBUTION_ID" ]]; then
  echo "Invalidating CloudFront distribution: $DISTRIBUTION_ID"
  
  INVALIDATION_ID=$(aws cloudfront create-invalidation \
    --distribution-id "$DISTRIBUTION_ID" \
    --paths "/api/auth/*" "/api/*" "/_next/*" \
    --query 'Invalidation.Id' \
    --output text)
  
  echo "Invalidation created: $INVALIDATION_ID"
  echo "Waiting for invalidation to complete (this may take a few minutes)..."
  
  aws cloudfront wait invalidation-completed \
    --distribution-id "$DISTRIBUTION_ID" \
    --id "$INVALIDATION_ID"
  
  echo "✅ CloudFront cache invalidation complete!"
else
  echo "⚠️  Could not get CloudFront distribution ID, skipping cache invalidation"
fi

cd "$ROOT_DIR"

echo ""
echo "=========================================="
echo "✅ Deployment Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Deploy SSR Lambda with updated NextAuth code"
echo "2. Test NextAuth endpoints:"
echo "   - GET https://dev.kambriq.com/api/auth/providers"
echo "   - GET https://dev.kambriq.com/api/auth/csrf"
echo "   - POST https://dev.kambriq.com/api/auth/signin"
echo "3. Verify routing: /api/auth/* should route to SSR Lambda, not API Gateway"
echo ""

