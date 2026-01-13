#!/bin/bash

# ============================================================================
# Script de Déploiement Terraform - KAMBRIQ v3.0
# ============================================================================
# Ce script déploie l'infrastructure Terraform depuis le local
# Usage: ./scripts/deploy-terraform.sh [shared|dev-v2|prod|all]
# ============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Default values
ENVIRONMENT="${1:-all}"
AWS_REGION="${AWS_REGION:-eu-central-1}"

# Function to print colored messages
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to check prerequisites
check_prerequisites() {
    print_info "Vérification des prérequis..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI n'est pas installé. Installez-le: https://aws.amazon.com/cli/"
        exit 1
    fi
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform n'est pas installé. Installez-le: https://www.terraform.io/downloads"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials non configurées. Configurez-les avec: aws configure"
        exit 1
    fi
    
    print_success "Tous les prérequis sont satisfaits"
}

# Function to deploy a stack
deploy_stack() {
    local stack_name=$1
    local stack_path="${PROJECT_ROOT}/envs/${stack_name}"
    
    if [ ! -d "${stack_path}" ]; then
        print_error "Stack ${stack_name} n'existe pas dans ${stack_path}"
        return 1
    fi
    
    print_info "Déploiement du stack: ${stack_name}"
    cd "${stack_path}"
    
    # Initialize Terraform
    print_info "Initialisation Terraform..."
    terraform init -upgrade
    
    # Validate Terraform configuration
    print_info "Validation de la configuration Terraform..."
    terraform validate
    if [ $? -ne 0 ]; then
        print_error "Validation Terraform échouée"
        return 1
    fi
    
    # Plan
    print_info "Plan Terraform..."
    terraform plan -out=tfplan
    if [ $? -ne 0 ]; then
        print_error "Plan Terraform échoué"
        return 1
    fi
    
    # Validate plan file exists
    if [ ! -f tfplan ]; then
        print_error "Échec de la création du plan Terraform"
        return 1
    fi
    
    # Auto-apply (no confirmation needed)
    print_info "Application automatique du plan Terraform..."
    terraform apply -auto-approve tfplan
    APPLY_EXIT_CODE=$?
    rm -f tfplan
    
    if [ $APPLY_EXIT_CODE -ne 0 ]; then
        print_error "Application Terraform échouée"
        return 1
    fi
    
    print_success "Stack ${stack_name} déployé avec succès"
}

# Main execution
main() {
    print_info "🚀 Déploiement Terraform KAMBRIQ v3.0"
    print_info "Environnement: ${ENVIRONMENT}"
    print_info "Région AWS: ${AWS_REGION}"
    echo ""
    
    # Check prerequisites
    check_prerequisites
    echo ""
    
    # Deploy stacks in order
    case "${ENVIRONMENT}" in
        shared)
            deploy_stack "shared"
            ;;
        dev-v2)
            print_warning "Assurez-vous que le stack 'shared' est déployé avant 'dev-v2'"
            deploy_stack "dev-v2"
            ;;
        prod)
            print_warning "Assurez-vous que le stack 'shared' est déployé avant 'prod'"
            deploy_stack "prod"
            ;;
        all)
            print_info "Déploiement de tous les stacks dans l'ordre..."
            deploy_stack "shared"
            echo ""
            print_warning "Après le déploiement de 'shared', configurez manuellement:"
            print_warning "  - Route53 hosted zone (récupérer zone_id)"
            print_warning "  - SES identities (récupérer ARNs)"
            print_warning "  - ACM certificates (récupérer ARNs)"
            echo ""
            print_info "Poursuite automatique avec dev-v2 dans 5 secondes..."
            sleep 5
            deploy_stack "dev-v2"
            ;;
        *)
            print_error "Environnement invalide: ${ENVIRONMENT}"
            print_info "Usage: $0 [shared|dev-v2|prod|all]"
            exit 1
            ;;
    esac
    
    print_success "🎉 Déploiement terminé avec succès!"
}

# Run main function
main "$@"
