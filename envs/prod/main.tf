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
#    - Lambda SSR code deployed via deploy-app-prod.yml
#
# 4. s3-media (modules/s3-media)
#    - Bucket S3 pour les médias et documents
#
# 5. iam (modules/iam)
#    - Rôles et policies IAM pour Lambda
#
# 6. lambda-api (modules/lambda-api)
#    - Fonction Lambda pour l'API NestJS
#    - Lambda API code deployed via deploy-app-prod.yml
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
# Application Code Deployment:
# ============================================================================
# Application code (API + Web) is deployed via workflows deploy-app-dev.yml and
# deploy-app-prod.yml in the kambriq repository. Terraform only creates the
# Lambda function structure with dummy placeholder code.
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
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
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

  env = local.env

  vpc_id            = data.terraform_remote_state.shared.outputs.vpc_id
  subnet_ids        = data.terraform_remote_state.shared.outputs.private_subnet_ids
  security_group_id = aws_security_group.lambda.id

  # CloudFront alias: kambriq.com (managed via Terraform)
  domain_name     = var.cloudfront_domain
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
# S3 Verify Store (Verification Documents)
# ============================================================================

resource "aws_s3_bucket" "verify_store" {
  bucket = "kambriq-verify-store-prod"

  # ⚠️ Protection forte contre la suppression
  force_destroy = false

  tags = {
    Name = "kambriq-verify-store-prod"
    Env  = local.env
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "verify_store" {
  bucket = aws_s3_bucket.verify_store.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Versioning (pour documents de vérification importants)
resource "aws_s3_bucket_versioning" "verify_store" {
  bucket = aws_s3_bucket.verify_store.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "verify_store" {
  bucket = aws_s3_bucket.verify_store.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ============================================================================
# IAM
# ============================================================================

module "iam" {
  source = "../../modules/iam"

  env                   = local.env
  aws_region            = var.aws_region
  rds_security_group_id = aws_security_group.rds.id
  s3_media_bucket_arn   = module.s3_media.bucket_arn
  ses_identity_arn      = try(data.terraform_remote_state.shared.outputs.ses_email_identity_arn, "")
}

# ============================================================================
# ECR Repository for API Lambda Container Image
# ============================================================================

module "ecr_api" {
  source = "../../modules/ecr-repository"

  repository_name = "kambriq-api-${local.env}"
  env             = local.env
  aws_region      = var.aws_region
}

# ============================================================================
# API (Lambda NestJS + API Gateway)
# ============================================================================
# Note: Lambda code is deployed via deploy-app-prod.yml in the kambriq repository
# Using Container Image (ECR) instead of ZIP to support bundles > 250MB

module "lambda" {
  source = "../../modules/lambda-api"

  env                   = local.env
  timeout               = 30
  memory_size           = 512
  ecr_repository_url    = module.ecr_api.repository_url
  ecr_placeholder_ready = module.ecr_api.placeholder_image_ready

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
  frontend_url    = var.cloudfront_domain != "" ? "https://${var.cloudfront_domain}" : module.frontend.cloudfront_url
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

# ============================================================================
# SSM Application Parameters
# ============================================================================
# Create SSM parameters for application runtime configuration
# These parameters are read by the application at runtime (see check-ssm-params.js)

module "ssm_app_parameters" {
  source = "../../modules/ssm-app-parameters"

  env = local.env

  # Database connection details
  db_host     = module.rds.db_host
  db_port     = module.rds.db_port
  db_name     = module.rds.db_name
  db_username = module.rds.db_username
  db_password = data.aws_ssm_parameter.db_password.value

  # JWT secret (read from existing SSM - will create /kambriq/{env}/api/JWT_SECRET from /kambriq/{env}/api/jwt_secret)
  # If jwt_secret doesn't exist in SSM, it will be created with a placeholder that you must update manually
  jwt_secret = data.aws_ssm_parameter.jwt_secret.value

  # Frontend URL from CloudFront
  frontend_url = module.frontend.cloudfront_url

  # SES sender email
  ses_from_email = var.ses_from_email

  # Additional API KV (String)
  default_visitor_role_id                    = "550e8400-e29b-41d4-a716-446655440002"
  password_reset_token_expiration_hours      = 24
  referral_code_expiration_hours             = 24
  referral_invitation_token_expiration_hours = 24
  jwt_expires_in                             = 900
  jwt_refresh_expires_in                     = 604800
  jwt_algorithm                              = "HS256"
  cookie_secure                              = "true"
  cookie_same_site                           = "strict"
  cookie_domain                              = ".kambriq.com"
  verification_cost                          = 99
  aws_ses_to_admin_contact                   = "contact@kambriq.com"
  contact_whatsapp_number                    = "+237670000000"
  paypal_environment                         = "production"

  # Web KV (public) - stored under /kambriq/prod/web/*
  api_gateway_base_url                   = module.api_gateway.api_url
  frontend_cloudfront_domain             = module.frontend.cloudfront_domain_name
  next_public_jwt_expires_in             = 900
  next_public_jwt_refresh_buffer_seconds = 180
  next_public_stale_time                 = 300
  next_public_refetch_interval           = 300
  # Keep empty by default (set manually in SSM later)
  next_public_paypal_client_id = ""
}

# ============================================================================
# Bastion Host - REMOVED
# ============================================================================
# The bastion is now deployed in the "shared" stack and is shared between
# dev and prod environments. See envs/shared/main.tf for bastion configuration.
#
# The bastion can access both dev and prod RDS instances via Security Groups.
