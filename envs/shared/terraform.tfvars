# ============================================================================
# KAMBRIQ - Shared Infrastructure - terraform.tfvars
# ============================================================================
#
# Ce fichier contient les variables pour déployer l'infrastructure partagée.
# Ce stack doit être déployé EN PREMIER avant dev et prod.
#
# UTILISATION :
# 1. Ce fichier est déjà configuré avec les valeurs par défaut
# 2. Ajuster les valeurs si nécessaire
# 3. Déployer : terraform init && terraform plan && terraform apply
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

# CIDR block pour la VPC (par défaut 10.0.0.0/16)
# Cette VPC sera utilisée par tous les environnements (dev, prod)
vpc_cidr = "10.0.0.0/16"

# ============================================================================
# DNS Configuration (Route53)
# ============================================================================
# Route53 hosted zone is created manually in AWS Console.
# Provide the zone_id here after manual setup.
# See docs/setup/ROUTE53_DNS_SETUP.md for manual setup instructions.

# Domaine principal pour Route53 hosted zone
domain_name = "kambriq.com"

# Route53 hosted zone ID (créé manuellement dans AWS Console)
# Format: Z00411721R2YKO3VFIPU4
# Pour obtenir le zone_id :
#   aws route53 list-hosted-zones --query "HostedZones[?Name=='kambriq.com.'].Id" --output text
route53_zone_id = "Z00411721R2YKO3VFIPU4"

# ============================================================================
# SES Configuration
# ============================================================================
# Note: ses_from_email is now environment-specific (configured in dev/prod tfvars)
# This value is kept for backward compatibility but is not used by dev/prod environments
# Dev uses: noreply.dev@kambriq.com
# Prod uses: noreply@kambriq.com
ses_from_email = "noreply@kambriq.com"

# ============================================================================
# S3 Buckets Configuration
# ============================================================================

# Activer le bucket S3 pour les logs
enable_s3_logs = true

# Activer le bucket S3 pour les artifacts
enable_s3_artifacts = true

# ============================================================================
# Bastion Configuration (shared between dev and prod)
# ============================================================================
# Bastion host for manual Prisma database migrations
# The bastion is shared between dev and prod environments
# See docs/integration/BASTION_SHARED_DEV_PROD.md for usage instructions

enable_bastion        = true
bastion_key_pair_name = "kambriq-bastion"
allowed_ssh_cidr      = ["90.25.230.44/32", "90.53.182.41/32"]
# ASG capacity: (0,0,0) to stop bastion, (1,1,1) to start
asg_min_size     = 1
asg_desired_size = 1
asg_max_size     = 1

# ============================================================================
# ACM Certificates Configuration
# ============================================================================
# ACM certificates are created manually in AWS Console.
# Provide the ARNs here after manual setup.
# See docs/setup/SES_AND_ACM_MANUAL_SETUP.md for manual setup instructions.

# ACM certificate for ALB (must be in eu-central-1)
# This certificate is used for HTTPS on the Application Load Balancer
api_acm_certificate_arn = "arn:aws:acm:eu-central-1:051551940370:certificate/6f8bbf35-3058-4083-a8dd-f393d5012300"

# ACM certificate for CloudFront (must be in us-east-1)
# This certificate is used for HTTPS on CloudFront distribution
# Uncomment and configure after creating the certificate in us-east-1:
# cloudfront_acm_certificate_arn = "arn:aws:acm:us-east-1:051551940370:certificate/..."

# ============================================================================
# SES Configuration (created manually in AWS Console)
# ============================================================================
# SES identities are created manually in AWS Console.
# Provide the ARNs here after manual setup.
# See docs/setup/SES_AND_ACM_MANUAL_SETUP.md for manual setup instructions.

# SES domain identity ARN (created manually in AWS Console)
# ses_domain_identity_arn = "arn:aws:ses:eu-central-1:051551940370:identity/kambriq.com"

# SES email identity ARN (created manually in AWS Console)
# ses_email_identity_arn = "arn:aws:ses:eu-central-1:051551940370:identity/noreply@kambriq.com"

# SES domain name
ses_domain = "kambriq.com"

# SES region (where SES identities are created)
ses_region = "eu-central-1"

