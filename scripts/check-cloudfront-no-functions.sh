#!/bin/bash
# ============================================================================
# CloudFront Function Validation Script
# ============================================================================
# 
# This script validates that NO CloudFront Functions are associated with
# any cache behaviors in the CloudFront distribution.
# 
# Purpose: Prevent regression of the 502 error caused by CloudFront Functions
# trying to modify disallowed headers (e.g., Host header).
# 
# Exit codes:
#   0 = Success (no function associations found)
#   1 = Failure (function associations found or error)
# ============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get distribution ID from Terraform output or environment variable
DISTRIBUTION_ID="${CLOUDFRONT_DISTRIBUTION_ID:-}"

if [ -z "$DISTRIBUTION_ID" ]; then
  # Try to get from Terraform output
  if command -v terraform &> /dev/null; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    TERRAFORM_DIR="${SCRIPT_DIR}/../envs/dev"
    if [ -d "$TERRAFORM_DIR" ]; then
      DISTRIBUTION_ID=$(cd "$TERRAFORM_DIR" && terraform output -raw cloudfront_distribution_id 2>/dev/null || echo "")
    fi
  fi
fi

if [ -z "$DISTRIBUTION_ID" ]; then
  echo -e "${RED}ERROR: CloudFront distribution ID not found.${NC}"
  echo "Set CLOUDFRONT_DISTRIBUTION_ID environment variable or run from terraform directory."
  exit 1
fi

echo "Checking CloudFront distribution: $DISTRIBUTION_ID"

# Fetch distribution config
CONFIG_FILE=$(mktemp)
trap "rm -f $CONFIG_FILE" EXIT

if ! aws cloudfront get-distribution-config --id "$DISTRIBUTION_ID" --output json > "$CONFIG_FILE" 2>&1; then
  echo -e "${RED}ERROR: Failed to fetch CloudFront distribution config${NC}"
  cat "$CONFIG_FILE"
  exit 1
fi

# Check for function associations in default cache behavior
DEFAULT_FUNCTIONS=$(jq -r '.DistributionConfig.DefaultCacheBehavior.FunctionAssociations.Quantity // 0' "$CONFIG_FILE" 2>/dev/null || echo "0")

# Check for function associations in ordered cache behaviors
ORDERED_FUNCTIONS=$(jq -r '[.DistributionConfig.OrderedCacheBehaviors.Items[]? | .FunctionAssociations.Quantity // 0] | add // 0' "$CONFIG_FILE" 2>/dev/null || echo "0")

TOTAL_FUNCTIONS=$((DEFAULT_FUNCTIONS + ORDERED_FUNCTIONS))

if [ "$TOTAL_FUNCTIONS" -gt 0 ]; then
  echo -e "${RED}❌ FAILED: CloudFront Functions are associated with cache behaviors!${NC}"
  echo ""
  echo "Default cache behavior function associations: $DEFAULT_FUNCTIONS"
  echo "Ordered cache behaviors function associations: $ORDERED_FUNCTIONS"
  echo "Total: $TOTAL_FUNCTIONS"
  echo ""
  echo "This will cause 502 errors: 'The CloudFront function tried to add a disallowed header'"
  echo ""
  echo "Details:"
  if [ "$DEFAULT_FUNCTIONS" -gt 0 ]; then
    echo "  Default cache behavior:"
    jq -r '.DistributionConfig.DefaultCacheBehavior.FunctionAssociations.Items[]? | "    - \(.EventType): \(.FunctionARN)"' "$CONFIG_FILE" 2>/dev/null || true
  fi
  if [ "$ORDERED_FUNCTIONS" -gt 0 ]; then
    echo "  Ordered cache behaviors:"
    jq -r '.DistributionConfig.OrderedCacheBehaviors.Items[]? | select((.FunctionAssociations.Quantity // 0) > 0) | "    \(.PathPattern // "default"): \(.FunctionAssociations.Items[]? | "\(.EventType): \(.FunctionARN)")"' "$CONFIG_FILE" 2>/dev/null || true
  fi
  exit 1
fi

echo -e "${GREEN}✅ SUCCESS: No CloudFront Functions are associated with any cache behaviors${NC}"
echo "  Default cache behavior: $DEFAULT_FUNCTIONS function associations"
echo "  Ordered cache behaviors: $ORDERED_FUNCTIONS function associations"
exit 0

