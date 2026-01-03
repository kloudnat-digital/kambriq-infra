#!/bin/bash
# Script pour appliquer Terraform dev-v2 avec variables depuis SSM ou tfvars

set -e

cd envs/dev-v2

# Vérifier si terraform.tfvars existe
if [ -f terraform.tfvars ]; then
    echo "Using terraform.tfvars"
    terraform apply -auto-approve
else
    echo "terraform.tfvars not found. Using SSM or manual input"
    echo "You can create terraform.tfvars from terraform.tfvars.example"
    terraform apply
fi
