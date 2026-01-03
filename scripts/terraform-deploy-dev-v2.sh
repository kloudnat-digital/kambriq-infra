#!/bin/bash
# Script de déploiement Terraform - Stack Dev-V2
# Déploie l'infrastructure dev (ECS, ALB, CloudFront, RDS, ECR, SSM, IAM)

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Déploiement Terraform - Stack DEV-V2 ===${NC}"
echo ""

# Configuration
TERRAFORM_DIR="envs/dev-v2"
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

# Vérifier que shared est déployé
echo -e "${YELLOW}Vérification du stack SHARED...${NC}"
BACKEND_BUCKET="kloudnat-infra-shared-store"
SHARED_STATE="s3://$BACKEND_BUCKET/kambriq/shared/terraform.tfstate"
if ! aws s3 ls "$SHARED_STATE" &> /dev/null; then
    echo -e "${RED}✗ Le stack SHARED n'est pas déployé${NC}"
    echo "   Déployez d'abord le stack shared:"
    echo "   cd ../shared && terraform init && terraform apply"
    exit 1
fi
echo -e "${GREEN}✓ Stack SHARED trouvé${NC}"
echo ""

# Vérifier que les secrets SSM existent
echo -e "${YELLOW}Vérification des secrets SSM Parameter Store...${NC}"
SSM_DB_PASSWORD="/kambriq/dev/db/password"
if ! aws ssm get-parameter --name "$SSM_DB_PASSWORD" --region "$AWS_REGION" &> /dev/null; then
    echo -e "${RED}✗ Le secret SSM $SSM_DB_PASSWORD n'existe pas${NC}"
    echo ""
    echo "   ⚠️  IMPORTANT: Les secrets DOIVENT être créés AVANT le déploiement Terraform"
    echo ""
    echo "   Créez les secrets avec:"
    echo "   cd ../.."
    echo "   ./scripts/generate-and-store-secrets.sh dev"
    echo ""
    echo "   Ou manuellement:"
    echo "   aws ssm put-parameter \\"
    echo "     --name /kambriq/dev/db/password \\"
    echo "     --value \"YOUR_STRONG_PASSWORD\" \\"
    echo "     --type SecureString \\"
    echo "     --region $AWS_REGION"
    exit 1
fi
echo -e "${GREEN}✓ Secret SSM $SSM_DB_PASSWORD trouvé${NC}"
echo ""

# Vérifier terraform.tfvars
if [ ! -f "terraform.tfvars" ]; then
    echo -e "${YELLOW}⚠️  terraform.tfvars n'existe pas${NC}"
    echo "   Création d'un fichier terraform.tfvars.example..."
    cat > terraform.tfvars.example << 'TFVARS'
# Configuration Dev-V2 Stack
aws_region = "eu-central-1"
project_name = "kambriq"
env = "dev"

# CloudFront Certificate (us-east-1)
# cloudfront_certificate_arn = "arn:aws:acm:us-east-1:ACCOUNT_ID:certificate/12345678-1234-1234-1234-123456789012"
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
echo -e "${GREEN}=== ✅ Déploiement DEV-V2 terminé ===${NC}"
echo ""
echo "📋 Prochaines étapes:"
echo "  1. Vérifier les outputs: terraform output"
echo "  2. Générer les secrets SSM: ../../scripts/generate-and-store-secrets.sh dev"
echo "  3. Déployer l'application: cd ../../kambriq && ./scripts/deploy-local.sh"
