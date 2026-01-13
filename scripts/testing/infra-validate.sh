#!/bin/bash
# Infrastructure Validation Script - Auth v3
# Validates Terraform code: fmt, validate, tflint, checkov

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "🔍 Infrastructure Validation - Auth v3"
echo "========================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check terraform
if ! command_exists terraform; then
    echo -e "${RED}❌ terraform not found${NC}"
    exit 1
fi

# Check tflint
if ! command_exists tflint; then
    echo -e "${YELLOW}⚠️  tflint not found, skipping tflint checks${NC}"
    SKIP_TFLINT=true
else
    SKIP_TFLINT=false
fi

# Check checkov
if ! command_exists checkov; then
    echo -e "${YELLOW}⚠️  checkov not found, skipping checkov checks${NC}"
    SKIP_CHECKOV=true
else
    SKIP_CHECKOV=false
fi

# Function to validate a stack
validate_stack() {
    local stack_dir="$1"
    local stack_name="$2"
    
    echo ""
    echo "📦 Validating stack: $stack_name"
    echo "   Directory: $stack_dir"
    echo ""
    
    cd "$stack_dir"
    
    # 1. Terraform fmt
    echo "   [1/4] Running terraform fmt -check..."
    if terraform fmt -check -recursive > /dev/null 2>&1; then
        echo -e "   ${GREEN}✅ terraform fmt: OK${NC}"
    else
        echo -e "   ${RED}❌ terraform fmt: FAILED${NC}"
        echo "   Run 'terraform fmt -recursive' to fix formatting issues"
        ((ERRORS++))
    fi
    
    # 2. Terraform init
    echo "   [2/4] Running terraform init..."
    if terraform init -backend=false > /dev/null 2>&1; then
        echo -e "   ${GREEN}✅ terraform init: OK${NC}"
    else
        echo -e "   ${RED}❌ terraform init: FAILED${NC}"
        ((ERRORS++))
        return
    fi
    
    # 3. Terraform validate
    echo "   [3/4] Running terraform validate..."
    if terraform validate > /dev/null 2>&1; then
        echo -e "   ${GREEN}✅ terraform validate: OK${NC}"
    else
        echo -e "   ${RED}❌ terraform validate: FAILED${NC}"
        terraform validate
        ((ERRORS++))
    fi
    
    # 4. Tflint
    if [ "$SKIP_TFLINT" = false ]; then
        echo "   [4/4] Running tflint..."
        if tflint --init > /dev/null 2>&1 && tflint > /dev/null 2>&1; then
            echo -e "   ${GREEN}✅ tflint: OK${NC}"
        else
            echo -e "   ${YELLOW}⚠️  tflint: Warnings found${NC}"
            tflint || true
        fi
    fi
    
    cd "$PROJECT_ROOT"
}

# Validate stacks
validate_stack "$PROJECT_ROOT/envs/shared" "shared"
validate_stack "$PROJECT_ROOT/envs/dev-v2" "dev-v2"

# Checkov (security baseline)
if [ "$SKIP_CHECKOV" = false ]; then
    echo ""
    echo "🔒 Running checkov (security baseline)..."
    cd "$PROJECT_ROOT"
    if checkov -d . --framework terraform --quiet > /dev/null 2>&1; then
        echo -e "${GREEN}✅ checkov: OK${NC}"
    else
        echo -e "${YELLOW}⚠️  checkov: Security issues found${NC}"
        checkov -d . --framework terraform || true
    fi
fi

# Summary
echo ""
echo "========================================"
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✅ All infrastructure validations passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Found $ERRORS error(s)${NC}"
    exit 1
fi
