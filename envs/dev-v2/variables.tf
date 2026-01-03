variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Project name prefix"
  type        = string
  default     = "kambriq"
}

variable "env" {
  description = "Environment name (dev, prod)"
  type        = string
  default     = "dev"
}

# Note: db_username et db_password ne sont plus des variables
# Ils sont récupérés depuis SSM Parameter Store:
#   - /kambriq/dev/db/password (via data.aws_ssm_parameter.db_password)
#   - db_username est hardcodé à "kambriq_admin" (peut être déplacé vers SSM si nécessaire)
#
# Les secrets doivent être créés AVANT le déploiement Terraform via:
#   ./scripts/generate-and-store-secrets.sh dev

# Note: cloudfront_certificate_arn est déclaré dans main.tf (ligne 167)
# pour éviter la duplication, elle n'est pas redéclarée ici
