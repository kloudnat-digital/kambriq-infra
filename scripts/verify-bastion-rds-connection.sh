#!/bin/bash
# Verify Bastion to RDS Security Group Rule
# This script checks if the security group rule exists and provides instructions to fix it

set -e

echo "🔍 Verifying Bastion to RDS Security Group Rule..."
echo ""

# Check if we're in the right directory
if [ ! -d "envs/shared" ]; then
    echo "❌ Error: This script must be run from kambriq-infra directory"
    exit 1
fi

cd envs/shared

echo "📋 Step 1: Checking if bastion module is deployed..."
if ! terraform state list 2>/dev/null | grep -q "module.bastion"; then
    echo "❌ Bastion module not found in Terraform state"
    echo "   Run: terraform init && terraform apply"
    exit 1
fi

echo "✅ Bastion module found"
echo ""

echo "📋 Step 2: Checking if RDS security group rule exists..."
RULE_FOUND=$(terraform state list 2>/dev/null | grep "aws_security_group_rule.rds_from_bastion" || true)

if [ -z "$RULE_FOUND" ]; then
    echo "❌ Security group rule NOT found in Terraform state"
    echo ""
    echo "🔧 This means the shared stack needs to be updated after dev stack was deployed."
    echo "   The bastion module reads RDS security group IDs from dev/prod remote states."
    echo ""
    echo "📝 To fix this, run:"
    echo "   cd envs/shared"
    echo "   terraform init"
    echo "   terraform plan  # Should show: aws_security_group_rule.rds_from_bastion will be created"
    echo "   terraform apply"
    exit 1
fi

echo "✅ Security group rule found: $RULE_FOUND"
echo ""

echo "📋 Step 3: Getting rule details..."
RULE_ID=$(echo "$RULE_FOUND" | head -1 | sed 's/.*\["\(.*\)"\].*/\1/')
if [ -n "$RULE_ID" ]; then
    terraform state show "$RULE_FOUND" 2>/dev/null | grep -E "(type|from_port|to_port|protocol|source_security_group_id|security_group_id|description)" || true
fi

echo ""
echo "✅ Verification complete!"
echo ""
echo "💡 If connection still fails, check:"
echo "   1. AWS Console → EC2 → Security Groups → RDS Security Group → Inbound Rules"
echo "   2. Verify there's a rule allowing PostgreSQL (5432) from bastion security group"
echo "   3. Check Network ACLs aren't blocking traffic"
echo "   4. Verify bastion and RDS are in the same VPC"

