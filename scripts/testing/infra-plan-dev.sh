#!/bin/bash
# Infrastructure Plan Dry-Run - Auth v3
# Runs terraform plan on dev-v2 stack (dry-run, no apply)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "📋 Infrastructure Plan Dry-Run - Dev v2"
echo "======================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

STACK_DIR="$PROJECT_ROOT/envs/dev-v2"

if [ ! -d "$STACK_DIR" ]; then
    echo -e "${RED}❌ Stack directory not found: $STACK_DIR${NC}"
    exit 1
fi

cd "$STACK_DIR"

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo -e "${YELLOW}⚠️  terraform.tfvars not found${NC}"
    echo "   Using terraform.tfvars.example as reference"
fi

# Initialize terraform
echo "🔧 Initializing Terraform..."
terraform init

# Plan
echo ""
echo "📋 Running terraform plan (dry-run)..."
echo ""

if terraform plan -out=tfplan > plan_output.txt 2>&1; then
    echo -e "${GREEN}✅ terraform plan: SUCCESS${NC}"
    echo ""
    echo "Plan saved to: $STACK_DIR/tfplan"
    echo "Plan output saved to: $STACK_DIR/plan_output.txt"
    echo ""
    echo "To review the plan:"
    echo "  cd $STACK_DIR"
    echo "  terraform show tfplan"
else
    echo -e "${RED}❌ terraform plan: FAILED${NC}"
    echo ""
    cat plan_output.txt
    exit 1
fi

# Cleanup
rm -f tfplan

echo -e "${GREEN}✅ Plan dry-run completed successfully!${NC}"
