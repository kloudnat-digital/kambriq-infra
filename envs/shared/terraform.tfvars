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

# Domaine principal pour Route53 hosted zone
domain_name = "kambriq.com"

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

