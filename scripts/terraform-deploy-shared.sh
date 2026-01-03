#!/bin/bash
# Script de déploiement Terraform - Stack Shared
# Déploie l'infrastructure partagée (VPC, Route53, SES, ACM, S3)

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Déploiement Terraform - Stack SHARED ===${NC}"
echo ""

# Configuration
TERRAFORM_DIR="envs/shared"
AWS_REGION="${AWS_REGION:-eu-central-1}"

# Vérifier que nous sommes dans le bon répertoire
if [ ! -d "$TERRAFORM_DIR" ]; then
    echo -e "${RED}✗ Répertoire $TERRAFORM_DIR introuvable${NC}"
    echo "   Exécutez ce script depuis la racine du repo kambriq-aws-iac-terraform"
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

# Vérifier le backend S3
echo -e "${YELLOW}Vérification du backend S3...${NC}"
BACKEND_BUCKET="kloudnat-infra-shared-store"
if ! aws s3 ls "s3://$BACKEND_BUCKET" &> /dev/null; then
    echo -e "${YELLOW}⚠️  Bucket S3 $BACKEND_BUCKET n'existe pas${NC}"
    echo "   Création du bucket..."
    aws s3 mb "s3://$BACKEND_BUCKET" --region "$AWS_REGION" || true
    aws s3api put-bucket-versioning \
        --bucket "$BACKEND_BUCKET" \
        --versioning-configuration Status=Enabled \
        --region "$AWS_REGION" || true
    echo -e "${GREEN}✓ Bucket créé${NC}"
else
    echo -e "${GREEN}✓ Bucket S3 existe${NC}"
fi
echo ""

# Vérifier terraform.tfvars
if [ ! -f "terraform.tfvars" ]; then
    echo -e "${YELLOW}⚠️  terraform.tfvars n'existe pas${NC}"
    echo "   Création d'un fichier terraform.tfvars.example..."
    cat > terraform.tfvars.example << 'TFVARS'
# Configuration Shared Stack
aws_region = "eu-central-1"
project_name = "kambriq"

# Route53 (à configurer manuellement)
# route53_zone_id = "Z1234567890ABC"

# SES (à configurer manuellement)
# ses_domain_identity_arn = "arn:aws:ses:eu-central-1:ACCOUNT_ID:identity/kambriq.com"
# ses_email_identity_arn = "arn:aws:ses:eu-central-1:ACCOUNT_ID:identity/noreply@kambriq.com"

# ACM Certificates (à configurer manuellement)
# acm_alb_certificate_arn = "arn:aws:acm:eu-central-1:ACCOUNT_ID:certificate/12345678-1234-1234-1234-123456789012"
# acm_cloudfront_certificate_arn = "arn:aws:acm:us-east-1:ACCOUNT_ID:certificate/12345678-1234-1234-1234-123456789012"
TFVARS
    echo -e "${YELLOW}   Veuillez créer terraform.tfvars avec vos valeurs${NC}"
    echo "   Copiez terraform.tfvars.example vers terraform.tfvars et remplissez les valeurs"
    exit 1
fi

echo -e "${GREEN}✓ terraform.tfvars trouvé${NC}"
echo ""

# Terraform Init
echo -e "${YELLOW}1. Terraform Init...${NC}"
terraform init
echo ""

# Terraform Validate
echo -e "${YELLOW}2. Terraform Validate...${NC}"
if ! terraform validate; then
    echo -e "${RED}✗ Validation Terraform échouée${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Validation OK${NC}"
echo ""

# Terraform Plan
echo -e "${YELLOW}3. Terraform Plan...${NC}"
terraform plan -out=tfplan
echo ""

# Demander confirmation
read -p "Voulez-vous appliquer ce plan ? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo -e "${YELLOW}Déploiement annulé${NC}"
    exit 0
fi

# Terraform Apply
echo -e "${YELLOW}4. Terraform Apply...${NC}"
terraform apply tfplan

# Nettoyer
rm -f tfplan

echo ""
echo -e "${GREEN}=== ✅ Déploiement SHARED terminé ===${NC}"
echo ""
echo "📋 Prochaines étapes:"
echo "  1. Vérifier les outputs: terraform output"
echo "  2. Configurer manuellement (si nécessaire):"
echo "     - Route53 hosted zone"
echo "     - SES domain/email identities"
echo "     - ACM certificates"
echo "  3. Déployer dev-v2: cd ../dev-v2 && terraform init && terraform plan && terraform apply"
