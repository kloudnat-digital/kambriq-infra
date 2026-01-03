#!/bin/bash
# Script de déploiement Terraform pour KAMBRIQ v2.0
# Déploie les stacks dans l'ordre: shared -> dev -> prod

set -e

# Configuration
ENVIRONMENT="${1:-dev}"
ACTION="${2:-apply}"
AWS_REGION="${AWS_REGION:-eu-central-1}"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=== Déploiement Terraform - KAMBRIQ v2.0 ==="
echo "Environnement: $ENVIRONMENT"
echo "Action: $ACTION"
echo ""

# Vérifier Terraform
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}✗ Terraform n'est pas installé${NC}"
    exit 1
fi

# Fonction pour déployer un stack
deploy_stack() {
    local stack_name=$1
    local stack_path="envs/$stack_name"
    
    if [ ! -d "$stack_path" ]; then
        echo -e "${YELLOW}⚠ Stack $stack_name n'existe pas, ignoré${NC}"
        return 0
    fi
    
    echo ""
    echo "=== Stack: $stack_name ==="
    cd "$stack_path"
    
    echo "Initialisation..."
    terraform init -upgrade
    
    echo "Plan..."
    terraform plan -out=tfplan
    
    if [ "$ACTION" = "apply" ]; then
        echo "Application..."
        terraform apply tfplan
        echo -e "${GREEN}✓ Stack $stack_name déployé${NC}"
    else
        echo -e "${YELLOW}⚠ Mode plan uniquement (pas d'application)${NC}"
    fi
    
    cd - > /dev/null
}

# Déployer shared en premier
deploy_stack "shared"

# Déployer l'environnement demandé
if [ "$ENVIRONMENT" = "dev" ]; then
    deploy_stack "dev-v2"
elif [ "$ENVIRONMENT" = "prod" ]; then
    deploy_stack "prod-v2"
else
    echo -e "${RED}✗ Environnement invalide: $ENVIRONMENT (dev ou prod)${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}=== Déploiement Terraform terminé ===${NC}"
