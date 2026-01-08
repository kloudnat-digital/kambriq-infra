#!/bin/bash
# Script pour vérifier l'état réel déployé vs le code Terraform actuel

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Vérification de l'état Terraform ===${NC}"
echo ""

# Configuration
TERRAFORM_DIR="${1:-envs/dev-v2}"
AWS_REGION="${AWS_REGION:-eu-central-1}"

if [ ! -d "$TERRAFORM_DIR" ]; then
    echo -e "${RED}✗ Répertoire $TERRAFORM_DIR introuvable${NC}"
    exit 1
fi

cd "$TERRAFORM_DIR"

# Vérifier AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}✗ AWS CLI n'est pas installé${NC}"
    exit 1
fi

# Vérifier Terraform
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}✗ Terraform n'est pas installé${NC}"
    exit 1
fi

# Vérifier les credentials AWS
echo -e "${YELLOW}Vérification des credentials AWS...${NC}"
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}✗ AWS credentials non configurées${NC}"
    exit 1
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${GREEN}✓ AWS Account ID: $AWS_ACCOUNT_ID${NC}"
echo ""

# Terraform Init
echo -e "${YELLOW}Initialisation Terraform...${NC}"
terraform init -backend-config="bucket=kloudnat-infra-shared-store" \
              -backend-config="key=kambriq/dev-v2/terraform.tfstate" \
              -backend-config="region=$AWS_REGION" \
              -input=false > /dev/null 2>&1

# Terraform Plan
echo -e "${YELLOW}Génération du plan Terraform...${NC}"
terraform plan -out=tfplan-check -input=false > /dev/null 2>&1

# Analyser les changements
echo ""
echo -e "${BLUE}=== Résumé des changements ===${NC}"
echo ""

CHANGES=$(terraform show -json tfplan-check 2>/dev/null | jq -r '.resource_changes[] | select(.change.actions[] | contains("create") or contains("update") or contains("delete")) | "\(.address) - \(.change.actions | join(", "))"' 2>/dev/null || echo "")

if [ -z "$CHANGES" ]; then
    echo -e "${GREEN}✓ Aucun changement détecté - L'infrastructure est à jour${NC}"
else
    echo -e "${YELLOW}⚠️  Changements détectés:${NC}"
    echo "$CHANGES" | while IFS= read -r line; do
        if [[ "$line" == *"create"* ]]; then
            echo -e "  ${GREEN}+ $line${NC}"
        elif [[ "$line" == *"update"* ]]; then
            echo -e "  ${YELLOW}~ $line${NC}"
        elif [[ "$line" == *"delete"* ]]; then
            echo -e "  ${RED}- $line${NC}"
        else
            echo "  $line"
        fi
    done
fi

# Vérifier spécifiquement les ECS Services
echo ""
echo -e "${BLUE}=== Détails ECS Services ===${NC}"
echo ""

# Récupérer les informations des services ECS
ECS_SERVICES=$(terraform show -json tfplan-check 2>/dev/null | jq -r '.resource_changes[] | select(.type == "aws_ecs_service") | {address: .address, desired_count_after: .change.after.desired_count, desired_count_before: .change.before.desired_count}' 2>/dev/null || echo "")

# Récupérer les informations d'autoscaling
AUTOSCALING_TARGETS=$(terraform show -json tfplan-check 2>/dev/null | jq -r '.resource_changes[] | select(.type == "aws_appautoscaling_target") | {address: .address, min_capacity_after: .change.after.min_capacity, min_capacity_before: .change.before.min_capacity, max_capacity_after: .change.after.max_capacity, max_capacity_before: .change.before.max_capacity}' 2>/dev/null || echo "")

if [ ! -z "$ECS_SERVICES" ] && [ "$ECS_SERVICES" != "null" ]; then
    echo "$ECS_SERVICES" | jq -r '. | "\(.address):\n  desired_count: \(.desired_count_before // "N/A") → \(.desired_count_after // "N/A")"' 2>/dev/null || echo "Changements ECS détectés"
fi

# Afficher les informations d'autoscaling si disponibles
if [ ! -z "$AUTOSCALING_TARGETS" ] && [ "$AUTOSCALING_TARGETS" != "null" ]; then
    echo ""
    echo -e "${BLUE}=== Configuration Autoscaling ===${NC}"
    echo ""
    echo "$AUTOSCALING_TARGETS" | jq -r '. | "\(.address):\n  min_capacity: \(.min_capacity_before // "N/A") → \(.min_capacity_after // "N/A")\n  max_capacity: \(.max_capacity_before // "N/A") → \(.max_capacity_after // "N/A")"' 2>/dev/null || echo "Informations autoscaling disponibles"
fi

# Nettoyer
rm -f tfplan-check

echo ""
echo -e "${BLUE}=== Vérification terminée ===${NC}"

