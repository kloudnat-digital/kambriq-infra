# ============================================================================
# KAMBRIQ - Infrastructure Terraform - Environnement PROD
# ============================================================================
#
# Modules utilisés dans cette configuration :
#
# 1. remote_state (shared) - Consomme les ressources partagées :
#    - VPC et sous-réseaux
#    - Route53 hosted zone
#    - SES domain identity
#    - ACM certificates
#
# 2. rds-postgres (modules/rds-postgres)
#    - Instance PostgreSQL RDS (t4g.micro, 20GB gp3)
#    - Backup retention : 30 jours
#    - skip_final_snapshot = false (toujours créer un snapshot final)
#
# 3. frontend (modules/frontend) - NOUVEAU
#    - S3 bucket pour assets statiques OpenNext
#    - CloudFront distribution
#    - Lambda functions pour SSR (OpenNext)
#    - Utilise les artefacts OpenNext depuis S3 (var.ssr_bundle_s3_key)
#
# 4. s3-media (modules/s3-media)
#    - Bucket S3 pour les médias et documents
#
# 5. iam (modules/iam)
#    - Rôles et policies IAM pour Lambda
#
# 6. lambda-api (modules/lambda-api)
#    - Fonction Lambda pour l'API NestJS
#    - Utilise les artefacts API depuis S3 (var.api_bundle_s3_key)
#    - Handler: dist/lambda.handler (NestJS Lambda adapter)
#
# 7. api-gateway (modules/api-gateway)
#    - API Gateway HTTP API
#    - Support des domaines personnalisés
#
# Différences avec DEV :
# - Backup retention : 30 jours (vs 7 jours)
# - skip_final_snapshot : false (vs true)
# - Domaines personnalisés recommandés pour CloudFront et API Gateway
#
# ============================================================================
# Artifacts S3:
# ============================================================================
# Les artefacts sont uploadés par le repo kambriq via .github/workflows/build-artifacts.yml
# et doivent être passés via variables Terraform :
#   - var.api_bundle_s3_key: S3 key du bundle API (ex: api/api-abc123.zip)
#   - var.ssr_bundle_s3_key: S3 key du bundle OpenNext (ex: web/web-abc123.zip)
#   - var.artifact_bucket_name: Nom du bucket S3 (ex: kambriq-artifacts-prod)
#
# Ces variables peuvent être passées via :
#   - Workflow GitHub Actions (terraform-dev.yml, terraform-prod.yml)
#   - Variables d'environnement TF_VAR_*
#   - Fichier terraform.tfvars (non commité)
#
# ============================================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  env = "prod"
}

# ============================================================================
# Remote State - Shared Infrastructure
# ============================================================================

data "terraform_remote_state" "shared" {
  backend = "s3"

  config = {
    bucket = "kloudnat-infra-shared-store"
    key    = "kambriq/shared/terraform.tfstate"
    region = var.aws_region
  }
}

# ============================================================================
# Security Groups (Environment-specific)
# ============================================================================

# Security Group for RDS
resource "aws_security_group" "rds" {
  name        = "kambriq-rds-${local.env}"
  description = "Security group for RDS PostgreSQL (${local.env})"
  vpc_id      = data.terraform_remote_state.shared.outputs.vpc_id

  ingress {
    description     = "PostgreSQL from Lambda"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "kambriq-rds-${local.env}"
    Env  = local.env
  }
}

# Security Group for Lambda
resource "aws_security_group" "lambda" {
  name        = "kambriq-lambda-${local.env}"
  description = "Security group for Lambda functions (${local.env})"
  vpc_id      = data.terraform_remote_state.shared.outputs.vpc_id

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "kambriq-lambda-${local.env}"
    Env  = local.env
  }
}

# ============================================================================
# SSM Parameter Store - Secrets
# ============================================================================

# Database password from SSM Parameter Store
data "aws_ssm_parameter" "db_password" {
  name = "/kambriq/prod/db/password"
}

# JWT secret from SSM Parameter Store
data "aws_ssm_parameter" "jwt_secret" {
  name = "/kambriq/prod/api/jwt_secret"
}

# ============================================================================
# RDS PostgreSQL
# ============================================================================

module "rds" {
  source = "../../modules/rds-postgres"

  env               = local.env
  db_name           = "kambriq"
  db_username       = "kambriq_admin"
  db_password       = data.aws_ssm_parameter.db_password.value
  instance_class    = "db.t4g.micro"
  allocated_storage = 20
  storage_type      = "gp3"

  vpc_id            = data.terraform_remote_state.shared.outputs.vpc_id
  subnet_ids        = data.terraform_remote_state.shared.outputs.private_subnet_ids
  security_group_id = aws_security_group.rds.id

  backup_retention_period = 30    # Plus de backups en prod
  skip_final_snapshot     = false # Toujours créer un snapshot final en prod
}

# ============================================================================
# Frontend (OpenNext)
# ============================================================================
# Module frontend gère : S3 static assets + CloudFront + Lambda SSR (OpenNext)
# Utilise les artefacts OpenNext uploadés depuis le repo kambriq

module "frontend" {
  source = "../../modules/frontend"

  env                 = local.env
  artifact_bucket_name = var.artifact_bucket_name != "" ? var.artifact_bucket_name : ""
  ssr_bundle_s3_key   = var.ssr_bundle_s3_key != "" ? var.ssr_bundle_s3_key : ""

  vpc_id            = data.terraform_remote_state.shared.outputs.vpc_id
  subnet_ids        = data.terraform_remote_state.shared.outputs.private_subnet_ids
  security_group_id = aws_security_group.lambda.id

  domain_name     = var.cloudfront_domain != "" ? var.cloudfront_domain : ""
  certificate_arn = var.cloudfront_certificate_arn != "" ? var.cloudfront_certificate_arn : ""

  # API Gateway URL for frontend environment variables
  api_gateway_url = module.api_gateway.api_url
}

# ============================================================================
# S3 Media (Documents)
# ============================================================================

module "s3_media" {
  source = "../../modules/s3-media"

  env = local.env
}

# ============================================================================
# IAM
# ============================================================================

module "iam" {
  source = "../../modules/iam"

  env                   = local.env
  rds_security_group_id = aws_security_group.rds.id
  s3_media_bucket_arn   = module.s3_media.bucket_arn
  ses_identity_arn      = try(data.terraform_remote_state.shared.outputs.ses_email_identity_arn, "")
}

# ============================================================================
# API (Lambda NestJS + API Gateway)
# ============================================================================
# Module lambda-api utilise les artefacts API uploadés depuis le repo kambriq

module "lambda" {
  source = "../../modules/lambda-api"

  env         = local.env
  runtime     = "nodejs20.x"
  handler     = "dist/lambda.handler"  # Updated: use lambda.handler for NestJS Lambda adapter
  timeout     = 30
  memory_size = 512

  role_arn          = module.iam.lambda_role_arn
  vpc_id            = data.terraform_remote_state.shared.outputs.vpc_id
  subnet_ids        = data.terraform_remote_state.shared.outputs.private_subnet_ids
  security_group_id = aws_security_group.lambda.id

  db_host     = module.rds.db_host
  db_port     = module.rds.db_port
  db_name     = module.rds.db_name
  db_username = module.rds.db_username
  db_password = data.aws_ssm_parameter.db_password.value

  s3_media_bucket = module.s3_media.bucket_id
  ses_from_email  = var.ses_from_email
  jwt_secret      = data.aws_ssm_parameter.jwt_secret.value

  # Use S3 artifacts if provided
  artifact_bucket_name = var.artifact_bucket_name != "" ? var.artifact_bucket_name : ""
  api_bundle_s3_key    = var.api_bundle_s3_key != "" ? var.api_bundle_s3_key : ""
}

# ============================================================================
# API Gateway
# ============================================================================

module "api_gateway" {
  source = "../../modules/api-gateway"

  env                  = local.env
  lambda_function_arn  = module.lambda.function_arn
  lambda_function_name = module.lambda.function_name
  # ACM certificates are managed manually - Terraform only consumes ARNs passed via tfvars.
  # API Gateway certificates must be created in eu-central-1.
  # See docs/setup/SES_AND_ACM_MANUAL_SETUP.md for manual setup instructions.
  domain_name     = var.api_domain
  certificate_arn = var.api_certificate_arn
}
