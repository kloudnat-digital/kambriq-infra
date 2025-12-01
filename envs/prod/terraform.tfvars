# ============================================================================
# KAMBRIQ - Infrastructure PROD - terraform.tfvars
# ============================================================================
#
# Ce fichier contient les variables pour déployer l'infrastructure PRODUCTION.
#
# UTILISATION :
# 1. Ce fichier est déjà configuré avec les valeurs par défaut pour PROD
# 2. Les secrets (db_password, jwt_secret) sont gérés via SSM Parameter Store
# 3. IMPORTANT : Le stack "shared" doit être déployé AVANT ce stack
# 4. Après le premier déploiement de "shared", mettre à jour les références
#    VPC ci-dessous avec les outputs du stack shared
#
# SECRETS MANAGEMENT :
# Les secrets sont stockés dans AWS SSM Parameter Store :
#   - /kambriq/prod/db/password → Mot de passe de la base de données
#   - /kambriq/prod/api/jwt_secret → Secret JWT pour l'authentification
#
# Pour créer ces secrets dans SSM :
#   aws ssm put-parameter --name /kambriq/prod/db/password \
#     --value "YOUR_STRONG_PASSWORD" --type SecureString
#   aws ssm put-parameter --name /kambriq/prod/api/jwt_secret \
#     --value "YOUR_JWT_SECRET" --type SecureString
#
# ⚠️  PRODUCTION : Utiliser OBLIGATOIREMENT un gestionnaire de secrets
#     (AWS Secrets Manager recommandé pour la production)
#
# ============================================================================

# ============================================================================
# Configuration de base
# ============================================================================

# Région AWS où déployer l'infrastructure
aws_region = "eu-central-1"

# ============================================================================
# VPC Configuration
# ============================================================================
# Note: Les références VPC (vpc_id, subnet_ids) sont automatiquement
# récupérées depuis le stack "shared" via terraform_remote_state dans main.tf.
# Aucune variable VPC n'est nécessaire dans ce fichier.
#
# Les modules utilisent directement :
#   - data.terraform_remote_state.shared.outputs.vpc_id
#   - data.terraform_remote_state.shared.outputs.public_subnet_ids
#   - data.terraform_remote_state.shared.outputs.private_subnet_ids
#
# ⚠️  IMPORTANT : Le stack "shared" doit être déployé AVANT ce stack.

# ============================================================================
# RDS Database Configuration
# ============================================================================
# Note: Le mot de passe de la base de données est récupéré automatiquement
# depuis SSM Parameter Store (/kambriq/prod/db/password) via data source
# dans main.tf. Aucune variable db_password n'est nécessaire dans ce fichier.
#
# ⚠️  PRODUCTION : Utiliser OBLIGATOIREMENT AWS Secrets Manager ou SSM
#     avec SecureString pour stocker le mot de passe.
#
# Pour créer le secret dans SSM :
#   aws ssm put-parameter --name /kambriq/prod/db/password \
#     --value "YOUR_STRONG_PASSWORD" --type SecureString

# ============================================================================
# API Configuration
# ============================================================================
# Note: Le secret JWT est récupéré automatiquement depuis SSM Parameter Store
# (/kambriq/prod/api/jwt_secret) via data source dans main.tf.
# Aucune variable jwt_secret n'est nécessaire dans ce fichier.
#
# ⚠️  PRODUCTION : Utiliser OBLIGATOIREMENT AWS Secrets Manager ou SSM
#     avec SecureString pour stocker le secret JWT.
#
# Pour créer le secret dans SSM :
#   aws ssm put-parameter --name /kambriq/prod/api/jwt_secret \
#     --value "YOUR_JWT_SECRET" --type SecureString

# ============================================================================
# SES Configuration
# ============================================================================
# SES sender email address for PROD environment
# SES identities are managed manually in AWS Console, not by Terraform
# See docs/setup/SES_AND_ACM_MANUAL_SETUP.md for manual setup instructions
ses_from_email = "noreply@kambriq.com"

# ============================================================================
# Domaines personnalisés (recommandé pour PROD)
# ============================================================================
# Pour activer des domaines personnalisés en production :
#
# 1. Récupérer les certificats depuis le stack "shared" :
#    cd ../shared
#    terraform output api_certificate_arn
#    # Pour CloudFront, créer un certificat dans us-east-1 séparément
#
# 2. Configurer les domaines dans Route53 (dans le stack shared) :
#    - app.kambriq.com → CloudFront distribution
#    - api.kambriq.com → API Gateway
#
# 3. Décommenter et remplir les valeurs ci-dessous :

# cloudfront_domain          = "app.kambriq.com"
# Certificat ACM CloudFront créé manuellement en us-east-1
# Voir docs/setup/SES_AND_ACM_MANUAL_SETUP.md pour les instructions
cloudfront_certificate_arn = "arn:aws:acm:us-east-1:051551940370:certificate/78e0e011-48de-4cc5-835c-9f51304f2292"

# api_domain                = "api.kambriq.com"
# api_certificate_arn        = "arn:aws:acm:eu-central-1:ACCOUNT_ID:certificate/CERTIFICATE_ID"
