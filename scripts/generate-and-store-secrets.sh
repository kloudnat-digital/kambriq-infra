#!/bin/bash
# ============================================================================
# Script pour générer et stocker les secrets dans AWS SSM Parameter Store
# ============================================================================
#
# Ce script génère des secrets sécurisés et les stocke dans SSM Parameter Store
# pour les environnements DEV et PROD.
#
# UTILISATION :
#   chmod +x scripts/generate-and-store-secrets.sh
#   ./scripts/generate-and-store-secrets.sh [dev|prod|all]
#
# Prérequis :
#   - AWS CLI configuré avec les credentials appropriés
#   - Permissions pour créer des paramètres SSM
#   - Région AWS : eu-central-1
#
# ============================================================================

set -euo pipefail

AWS_REGION="${AWS_REGION:-eu-central-1}"
ENVIRONMENT="${1:-all}"

# Couleurs pour l'output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# ============================================================================
# Fonctions utilitaires
# ============================================================================

generate_password() {
    # Génère un mot de passe fort (32 caractères)
    # Contient majuscules, minuscules, chiffres et symboles
    openssl rand -base64 24 | tr -d "=+/" | cut -c1-32
}

generate_jwt_secret() {
    # Génère un secret JWT sécurisé (64 caractères en base64)
    openssl rand -base64 48 | tr -d "=+/" | cut -c1-64
}

store_ssm_parameter() {
    local name=$1
    local value=$2
    local description=$3
    local env=$4

    echo -e "${YELLOW}Storing parameter: ${name}${NC}"
    
    # Vérifier si le paramètre existe déjà
    if aws ssm get-parameter --name "$name" --region "$AWS_REGION" &>/dev/null; then
        echo -e "${YELLOW}  ⚠️  Parameter already exists. Updating...${NC}"
        aws ssm put-parameter \
            --name "$name" \
            --value "$value" \
            --type SecureString \
            --overwrite \
            --description "$description" \
            --region "$AWS_REGION" \
            --tags "Key=Environment,Value=$env" "Key=ManagedBy,Value=Terraform"
    else
        aws ssm put-parameter \
            --name "$name" \
            --value "$value" \
            --type SecureString \
            --description "$description" \
            --region "$AWS_REGION" \
            --tags "Key=Environment,Value=$env" "Key=ManagedBy,Value=Terraform"
    fi
    
    echo -e "${GREEN}  ✅ Parameter stored successfully${NC}"
}

# ============================================================================
# Génération et stockage des secrets DEV
# ============================================================================

generate_dev_secrets() {
    echo -e "\n${GREEN}=== Generating DEV secrets ===${NC}\n"
    
    # Générer les secrets
    DB_PASSWORD=$(generate_password)
    JWT_SECRET=$(generate_jwt_secret)
    
    # Stocker dans SSM
    store_ssm_parameter \
        "/kambriq/dev/db/password" \
        "$DB_PASSWORD" \
        "Database master password for KAMBRIQ DEV environment" \
        "dev"
    
    store_ssm_parameter \
        "/kambriq/dev/api/jwt_secret" \
        "$JWT_SECRET" \
        "JWT secret key for KAMBRIQ DEV API authentication" \
        "dev"
    
    echo -e "\n${GREEN}✅ DEV secrets generated and stored${NC}"
    echo -e "${YELLOW}⚠️  IMPORTANT: Save these values securely (they won't be shown again):${NC}"
    echo -e "  DB Password: ${DB_PASSWORD}"
    echo -e "  JWT Secret: ${JWT_SECRET}"
}

# ============================================================================
# Génération et stockage des secrets PROD
# ============================================================================

generate_prod_secrets() {
    echo -e "\n${GREEN}=== Generating PROD secrets ===${NC}\n"
    
    # Générer les secrets
    DB_PASSWORD=$(generate_password)
    JWT_SECRET=$(generate_jwt_secret)
    
    # Stocker dans SSM
    store_ssm_parameter \
        "/kambriq/prod/db/password" \
        "$DB_PASSWORD" \
        "Database master password for KAMBRIQ PROD environment" \
        "prod"
    
    store_ssm_parameter \
        "/kambriq/prod/api/jwt_secret" \
        "$JWT_SECRET" \
        "JWT secret key for KAMBRIQ PROD API authentication" \
        "prod"
    
    echo -e "\n${GREEN}✅ PROD secrets generated and stored${NC}"
    echo -e "${YELLOW}⚠️  IMPORTANT: Save these values securely (they won't be shown again):${NC}"
    echo -e "  DB Password: ${DB_PASSWORD}"
    echo -e "  JWT Secret: ${JWT_SECRET}"
}

# ============================================================================
# Main
# ============================================================================

main() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}KAMBRIQ - Secret Generation Script${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo -e "Region: ${AWS_REGION}"
    echo -e "Environment: ${ENVIRONMENT}"
    echo ""
    
    case "$ENVIRONMENT" in
        dev)
            generate_dev_secrets
            ;;
        prod)
            generate_prod_secrets
            ;;
        all)
            generate_dev_secrets
            generate_prod_secrets
            ;;
        *)
            echo -e "${RED}Error: Invalid environment. Use 'dev', 'prod', or 'all'${NC}"
            exit 1
            ;;
    esac
    
    echo -e "\n${GREEN}========================================${NC}"
    echo -e "${GREEN}✅ All secrets generated and stored${NC}"
    echo -e "${GREEN}========================================${NC}"
}

main

