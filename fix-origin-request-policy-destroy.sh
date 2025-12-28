#!/bin/bash
# Fix for CloudFront Origin Request Policy destroy error
# This script updates the CloudFront distribution first, then handles the old policy

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_DIR="${SCRIPT_DIR}/envs/dev"

cd "${ENV_DIR}"

echo "Step 1: Updating CloudFront distribution to use AWS managed policy..."
echo "This will update the cache behavior to reference the AWS managed policy instead of the custom one."
terraform apply -target=module.frontend.aws_cloudfront_distribution.main

echo ""
echo "Step 2: Waiting for CloudFront distribution update to complete..."
echo "CloudFront distribution updates can take 15-20 minutes to fully propagate."
echo "Checking if distribution is deployed..."

# Wait for the distribution to be deployed
MAX_WAIT=1800  # 30 minutes max
ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
    STATUS=$(terraform show -json | jq -r '.values.root_module.child_modules[] | select(.address == "module.frontend") | .resources[] | select(.address == "module.frontend.aws_cloudfront_distribution.main") | .values.status' 2>/dev/null || echo "unknown")
    
    if [ "$STATUS" = "Deployed" ]; then
        echo "Distribution is deployed!"
        break
    fi
    
    echo "Waiting for distribution to deploy... (status: ${STATUS:-checking}, elapsed: ${ELAPSED}s)"
    sleep 30
    ELAPSED=$((ELAPSED + 30))
done

if [ $ELAPSED -ge $MAX_WAIT ]; then
    echo "WARNING: Distribution update took longer than expected."
    echo "You may need to manually verify it's deployed before proceeding."
fi

echo ""
echo "Step 3: Removing old origin request policy from Terraform state..."
# Check if the resource exists in state first
if terraform state show module.frontend.aws_cloudfront_origin_request_policy.api_gateway &>/dev/null; then
    echo "Removing origin request policy from Terraform state..."
    terraform state rm module.frontend.aws_cloudfront_origin_request_policy.api_gateway
    echo "✓ Policy removed from state."
    echo ""
    echo "Note: The actual AWS resource may still exist but is no longer managed by Terraform."
    echo "After CloudFront fully disassociates it, you can manually delete it from the"
    echo "AWS Console (CloudFront > Policies > Origin Request) if needed."
else
    echo "Policy not found in state, skipping removal."
fi

echo ""
echo "Step 4: Running full terraform apply to sync state..."
terraform apply

echo ""
echo "✓ Done! The origin request policy should now be properly handled."

