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
# 3. s3-static-site (modules/s3-static-site)
#    - Bucket S3 pour le frontend Next.js (static export)
#
# 4. s3-media (modules/s3-media)
#    - Bucket S3 pour les médias et documents
#
# 5. cloudfront (modules/cloudfront)
#    - Distribution CloudFront pour servir le frontend depuis S3
#    - Support des domaines personnalisés
#
# 6. iam (modules/iam)
#    - Rôles et policies IAM pour Lambda
#
# 7. lambda-api (modules/lambda-api)
#    - Fonction Lambda pour l'API NestJS
#
# 8. api-gateway (modules/api-gateway)
#    - API Gateway HTTP API
#    - Support des domaines personnalisés
#
# Différences avec DEV :
# - Backup retention : 30 jours (vs 7 jours)
# - skip_final_snapshot : false (vs true)
# - Domaines personnalisés recommandés pour CloudFront et API Gateway
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
# RDS PostgreSQL
# ============================================================================

module "rds" {
  source = "../../modules/rds-postgres"

  env              = local.env
  db_name          = "kambriq"
  db_username      = "kambriq_admin"
  db_password      = var.db_password
  instance_class   = "db.t4g.micro"
  allocated_storage = 20
  storage_type     = "gp3"

  vpc_id            = data.terraform_remote_state.shared.outputs.vpc_id
  subnet_ids        = data.terraform_remote_state.shared.outputs.private_subnet_ids
  security_group_id = aws_security_group.rds.id

  backup_retention_period = 30 # Plus de backups en prod
  skip_final_snapshot    = false # Toujours créer un snapshot final en prod
}

# ============================================================================
# S3 Static Site (Frontend)
# ============================================================================

module "s3_static" {
  source = "../../modules/s3-static-site"

  env = local.env
}

# ============================================================================
# S3 Media (Documents)
# ============================================================================

module "s3_media" {
  source = "../../modules/s3-media"

  env = local.env
}

# ============================================================================
# CloudFront
# ============================================================================

module "cloudfront" {
  source = "../../modules/cloudfront"

  env                            = local.env
  s3_bucket_id                   = module.s3_static.bucket_id
  s3_bucket_regional_domain_name = module.s3_static.bucket_regional_domain_name
  domain_name                    = var.cloudfront_domain
  certificate_arn               = var.cloudfront_certificate_arn
}

# Bucket policy S3 pour CloudFront OAI
resource "aws_s3_bucket_policy" "static" {
  bucket = module.s3_static.bucket_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${module.s3_static.bucket_arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = module.cloudfront.distribution_arn
          }
        }
      }
    ]
  })

  depends_on = [module.cloudfront]
}

# ============================================================================
# IAM
# ============================================================================

module "iam" {
  source = "../../modules/iam"

  env                  = local.env
  rds_security_group_id = aws_security_group.rds.id
  s3_media_bucket_arn  = module.s3_media.bucket_arn
  ses_identity_arn     = data.terraform_remote_state.shared.outputs.ses_email_identity_arn
}

# ============================================================================
# Lambda API
# ============================================================================

module "lambda" {
  source = "../../modules/lambda-api"

  env              = local.env
  runtime          = "nodejs20.x"
  handler          = "dist/main.handler"
  timeout          = 30
  memory_size      = 512

  role_arn         = module.iam.lambda_role_arn
  vpc_id           = data.terraform_remote_state.shared.outputs.vpc_id
  subnet_ids       = data.terraform_remote_state.shared.outputs.private_subnet_ids
  security_group_id = aws_security_group.lambda.id

  db_host     = module.rds.db_host
  db_port     = module.rds.db_port
  db_name     = module.rds.db_name
  db_username = module.rds.db_username
  db_password = var.db_password

  s3_media_bucket = module.s3_media.bucket_id
  ses_from_email  = data.terraform_remote_state.shared.outputs.ses_from_email
  jwt_secret      = var.jwt_secret
}

# ============================================================================
# API Gateway
# ============================================================================

module "api_gateway" {
  source = "../../modules/api-gateway"

  env                  = local.env
  lambda_function_arn  = module.lambda.function_arn
  lambda_function_name = module.lambda.function_name
  domain_name          = var.api_domain
  certificate_arn      = var.api_certificate_arn
}
