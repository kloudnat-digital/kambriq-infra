# ============================================================================
# KAMBRIQ v2.0 - Infrastructure Terraform - Environnement DEV
# ============================================================================
# Architecture V2: ECS Fargate + ALB + CloudFront + FastAPI + Next.js
# ============================================================================

# Configuration de base
aws_region = "eu-central-1"
project_name = "kambriq"
env = "dev"

# ============================================================================
# CloudFront Certificate (ACM)
# ============================================================================
# IMPORTANT: Le certificat CloudFront DOIT être créé en us-east-1
# Créer le certificat dans AWS Console (us-east-1) puis fournir l'ARN ici
# Format: arn:aws:acm:us-east-1:ACCOUNT_ID:certificate/12345678-1234-1234-1234-123456789012
#
# Pour créer le certificat:
# 1. Aller dans AWS Certificate Manager (us-east-1)
# 2. Demander un certificat public
# 3. Domaine: *.kambriq.com (wildcard) ou dev.kambriq.com (spécifique)
# 4. Valider via DNS (ajouter les enregistrements CNAME dans Route53)
# 5. Récupérer l'ARN et le mettre ci-dessous
#
# Certificat CloudFront (us-east-1) - Déjà configuré dans main.tf avec valeur par défaut
# Si vous voulez utiliser un autre certificat, décommentez et modifiez:
# cloudfront_certificate_arn = "arn:aws:acm:us-east-1:051551940370:certificate/061b780e-6b44-4535-96e3-e36c537d802f"

# ============================================================================
# Database Configuration
# ============================================================================
# IMPORTANT: Les credentials de la base de données sont gérés UNIQUEMENT via SSM Parameter Store
# 
# Le mot de passe est récupéré depuis: /kambriq/dev/db/password
# Le username est hardcodé à "kambriq_admin" (peut être déplacé vers SSM si nécessaire)
#
# Les secrets DOIVENT être créés AVANT le déploiement Terraform via:
#   cd kambriq-infra
#   ./scripts/generate-and-store-secrets.sh dev
#
# Ou manuellement:
#   aws ssm put-parameter \
#     --name /kambriq/dev/db/password \
#     --value "YOUR_STRONG_PASSWORD" \
#     --type SecureString \
#     --region eu-central-1
