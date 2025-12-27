#!/bin/bash
set -euo pipefail

# ============================================================================
# Setup NextAuth SSM Parameters
# ============================================================================
# This script generates NEXTAUTH_SECRET and stores NextAuth config in SSM
# 
# Usage:
#   ./scripts/setup-nextauth-ssm.sh <env> [nextauth_url] [api_base_url]
#
# Example:
#   ./scripts/setup-nextauth-ssm.sh dev https://dev.kambriq.com https://5h6kowefig.execute-api.eu-central-1.amazonaws.com
# ============================================================================

ENV="${1:-dev}"

if [[ "$ENV" != "dev" && "$ENV" != "prod" ]]; then
  echo "Error: Environment must be 'dev' or 'prod'"
  exit 1
fi

# Get values from arguments or use defaults
NEXTAUTH_URL="${2:-}"
API_BASE_URL="${3:-}"

# If not provided, try to get from Terraform outputs
if [[ -z "$NEXTAUTH_URL" ]]; then
  echo "Getting NEXTAUTH_URL from Terraform outputs..."
  cd "$(dirname "$0")/../envs/$ENV"
  if command -v terraform >/dev/null 2>&1; then
    NEXTAUTH_URL=$(terraform output -raw frontend_cloudfront_url 2>/dev/null || echo "")
    if [[ -z "$NEXTAUTH_URL" ]]; then
      # Try to get from domain if custom domain is set
      CLOUDFRONT_DOMAIN=$(terraform output -raw frontend_cloudfront_domain 2>/dev/null || echo "")
      if [[ -n "$CLOUDFRONT_DOMAIN" ]]; then
        NEXTAUTH_URL="https://$CLOUDFRONT_DOMAIN"
      fi
    fi
  fi
  cd - >/dev/null
fi

if [[ -z "$API_BASE_URL" ]]; then
  echo "Getting API_BASE_URL from Terraform outputs..."
  cd "$(dirname "$0")/../envs/$ENV"
  if command -v terraform >/dev/null 2>&1; then
    API_BASE_URL=$(terraform output -raw api_gateway_base_url 2>/dev/null || echo "")
  fi
  cd - >/dev/null
fi

if [[ -z "$NEXTAUTH_URL" ]]; then
  echo "Error: NEXTAUTH_URL not provided and could not be retrieved from Terraform"
  echo "Usage: $0 <env> [nextauth_url] [api_base_url]"
  exit 1
fi

if [[ -z "$API_BASE_URL" ]]; then
  echo "Error: API_BASE_URL not provided and could not be retrieved from Terraform"
  echo "Usage: $0 <env> [nextauth_url] [api_base_url]"
  exit 1
fi

echo "Environment: $ENV"
echo "NEXTAUTH_URL: $NEXTAUTH_URL"
echo "API_BASE_URL: $API_BASE_URL"
echo ""

# Generate NEXTAUTH_SECRET
echo "Generating NEXTAUTH_SECRET..."
NEXTAUTH_SECRET=$(openssl rand -base64 32)
echo "NEXTAUTH_SECRET generated (stored securely, not displayed)"
echo ""

# AWS Region
REGION="${AWS_REGION:-eu-central-1}"

# SSM Parameter paths
BASE_PATH="/kambriq/$ENV/web"
NEXTAUTH_URL_PARAM="${BASE_PATH}/NEXTAUTH_URL"
NEXTAUTH_SECRET_PARAM="${BASE_PATH}/NEXTAUTH_SECRET"
API_BASE_URL_PARAM="${BASE_PATH}/API_BASE_URL"

echo "Creating/updating SSM parameters..."
echo ""

# Helper function to create or update parameter with tags
create_or_update_param() {
  local param_name="$1"
  local param_type="$2"
  local param_value="$3"
  local param_description="$4"
  local tag_name="$5"
  
  # Check if parameter exists
  if aws ssm get-parameter --region "$REGION" --name "$param_name" >/dev/null 2>&1; then
    # Update existing parameter (without tags)
    aws ssm put-parameter \
      --region "$REGION" \
      --name "$param_name" \
      --type "$param_type" \
      --value "$param_value" \
      --overwrite \
      --description "$param_description" \
      >/dev/null
    
    # Update tags separately
    aws ssm add-tags-to-resource \
      --region "$REGION" \
      --resource-type "Parameter" \
      --resource-id "$param_name" \
      --tags "Key=Name,Value=$tag_name" "Key=Environment,Value=$ENV" "Key=Service,Value=web" \
      >/dev/null 2>&1 || true
  else
    # Create new parameter with tags
    aws ssm put-parameter \
      --region "$REGION" \
      --name "$param_name" \
      --type "$param_type" \
      --value "$param_value" \
      --description "$param_description" \
      --tags "Key=Name,Value=$tag_name" "Key=Environment,Value=$ENV" "Key=Service,Value=web" \
      >/dev/null
  fi
}

# Create/update NEXTAUTH_URL
echo "Setting ${NEXTAUTH_URL_PARAM}..."
create_or_update_param \
  "$NEXTAUTH_URL_PARAM" \
  "String" \
  "$NEXTAUTH_URL" \
  "NextAuth base URL for $ENV" \
  "kambriq-web-nextauth-url-$ENV"
echo "✅ ${NEXTAUTH_URL_PARAM}"

# Create/update NEXTAUTH_SECRET
echo "Setting ${NEXTAUTH_SECRET_PARAM}..."
create_or_update_param \
  "$NEXTAUTH_SECRET_PARAM" \
  "SecureString" \
  "$NEXTAUTH_SECRET" \
  "NextAuth JWT signing secret for $ENV" \
  "kambriq-web-nextauth-secret-$ENV"
echo "✅ ${NEXTAUTH_SECRET_PARAM} (SecureString)"

# Create/update API_BASE_URL
echo "Setting ${API_BASE_URL_PARAM}..."
create_or_update_param \
  "$API_BASE_URL_PARAM" \
  "String" \
  "$API_BASE_URL" \
  "API Gateway base URL for SSR server-to-server calls ($ENV)" \
  "kambriq-web-api-base-url-$ENV"
echo "✅ ${API_BASE_URL_PARAM}"

# Verify JWT_EXPIRES_IN exists (should be created by Terraform, but verify)
JWT_EXPIRES_IN_PARAM="${BASE_PATH}/JWT_EXPIRES_IN"
if ! aws ssm get-parameter --region "$REGION" --name "$JWT_EXPIRES_IN_PARAM" >/dev/null 2>&1; then
  echo ""
  echo "Setting ${JWT_EXPIRES_IN_PARAM} (default: 3600)..."
  create_or_update_param \
    "$JWT_EXPIRES_IN_PARAM" \
    "String" \
    "3600" \
    "JWT access token expiration (seconds) for $ENV" \
    "kambriq-web-jwt-expires-in-$ENV"
  echo "✅ ${JWT_EXPIRES_IN_PARAM}"
fi

echo ""
echo "✅ All NextAuth SSM parameters created/updated successfully!"
echo ""
echo "Next steps:"
echo "1. Update Terraform to pass nextauth_secret (optional, SSM is source of truth)"
echo "2. Apply Terraform changes"
echo "3. Deploy SSR Lambda with updated code"
echo "4. Test NextAuth endpoints"

