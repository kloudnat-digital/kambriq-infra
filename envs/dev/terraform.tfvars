# ============================================================================
# KAMBRIQ - Infrastructure DEV - terraform.tfvars
# ============================================================================
#
# Ce fichier contient les variables pour déployer l'infrastructure DEV.
#
# UTILISATION :
# 1. Ce fichier est déjà configuré avec les valeurs par défaut pour DEV
# 2. Les secrets (db_password, jwt_secret) sont gérés via SSM Parameter Store
# 3. IMPORTANT : Le stack "shared" doit être déployé AVANT ce stack
# 4. Après le premier déploiement de "shared", mettre à jour les références
#    VPC ci-dessous avec les outputs du stack shared
#
# SECRETS MANAGEMENT :
# Les secrets sont stockés dans AWS SSM Parameter Store :
#   - /kambriq/dev/db/password → Mot de passe de la base de données
#   - /kambriq/dev/api/jwt_secret → Secret JWT pour l'authentification
#
# Pour créer ces secrets dans SSM :
#   aws ssm put-parameter --name /kambriq/dev/db/password \
#     --value "YOUR_STRONG_PASSWORD" --type SecureString
#   aws ssm put-parameter --name /kambriq/dev/api/jwt_secret \
#     --value "YOUR_JWT_SECRET" --type SecureString
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
# depuis SSM Parameter Store (/kambriq/dev/db/password) via data source
# dans main.tf. Aucune variable db_password n'est nécessaire dans ce fichier.
#
# Pour créer le secret dans SSM :
#   aws ssm put-parameter --name /kambriq/dev/db/password \
#     --value "YOUR_STRONG_PASSWORD" --type SecureString

# ============================================================================
# API Configuration
# ============================================================================
# Note: Le secret JWT est récupéré automatiquement depuis SSM Parameter Store
# (/kambriq/dev/api/jwt_secret) via data source dans main.tf.
# Aucune variable jwt_secret n'est nécessaire dans ce fichier.
#
# Pour créer le secret dans SSM :
#   aws ssm put-parameter --name /kambriq/dev/api/jwt_secret \
#     --value "YOUR_JWT_SECRET" --type SecureString

# ============================================================================
# SES Configuration
# ============================================================================
# SES sender email address for DEV environment
# SES identities are managed manually in AWS Console, not by Terraform
# See docs/setup/SES_AND_ACM_MANUAL_SETUP.md for manual setup instructions
ses_from_email = "noreply.dev@kambriq.com"

# ============================================================================
# Domaines personnalisés (optionnel pour DEV)
# ============================================================================
# Par défaut, CloudFront et API Gateway utilisent leurs URLs par défaut.
# Pour activer des domaines personnalisés, décommenter et remplir :

# cloudfront_domain          = "app-dev.kambriq.com"
# Certificat ACM CloudFront créé manuellement en us-east-1
# Voir docs/setup/SES_AND_ACM_MANUAL_SETUP.md pour les instructions
cloudfront_certificate_arn = "arn:aws:acm:us-east-1:051551940370:certificate/061b780e-6b44-4535-96e3-e36c537d802f"

# api_domain                = "api-dev.kambriq.com"
# api_certificate_arn        = "arn:aws:acm:eu-central-1:ACCOUNT_ID:certificate/CERTIFICATE_ID"

# ============================================================================
# Bastion Configuration
# ============================================================================
# Bastion host for manual Prisma database migrations
# See modules/bastion/README.md for usage instructions

enable_bastion = true
bastion_key_pair_name = "kambriq-bastion"
allowed_ssh_cidr = "90.25.230.44/32"
enable_bastion_autostop = true
