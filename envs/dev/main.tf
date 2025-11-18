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
  env = "dev"
}

# Network
module "network" {
  source = "../../modules/network"

  env = local.env
}

# RDS PostgreSQL
module "rds" {
  source = "../../modules/rds-postgres"

  env              = local.env
  db_name          = "kambriq"
  db_username      = "kambriq_admin"
  db_password      = var.db_password
  instance_class   = "db.t4g.micro"
  allocated_storage = 20
  storage_type     = "gp3"

  vpc_id            = module.network.vpc_id
  subnet_ids        = module.network.subnet_ids
  security_group_id = module.network.rds_security_group_id

  backup_retention_period = 7
  skip_final_snapshot    = true # Pour dev, on peut supprimer sans snapshot
}

# S3 Static Site (Frontend)
module "s3_static" {
  source = "../../modules/s3-static-site"

  env = local.env
}

# S3 Media (Documents)
module "s3_media" {
  source = "../../modules/s3-media"

  env = local.env
}

# CloudFront
module "cloudfront" {
  source = "../../modules/cloudfront"

  env                            = local.env
  s3_bucket_id                   = module.s3_static.bucket_id
  s3_bucket_regional_domain_name = module.s3_static.bucket_regional_domain_name
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

# SES
module "ses" {
  source = "../../modules/ses"

  env        = local.env
  domain     = var.ses_domain
  from_email = var.ses_from_email
}

# IAM
module "iam" {
  source = "../../modules/iam"

  env                  = local.env
  rds_security_group_id = module.network.rds_security_group_id
  s3_media_bucket_arn  = module.s3_media.bucket_arn
  ses_identity_arn     = module.ses.email_identity_arn
}

# Lambda API
module "lambda" {
  source = "../../modules/lambda-api"

  env              = local.env
  runtime          = "nodejs20.x"
  handler          = "dist/main.handler"
  timeout          = 30
  memory_size      = 512

  role_arn         = module.iam.lambda_role_arn
  vpc_id           = module.network.vpc_id
  subnet_ids       = module.network.subnet_ids
  security_group_id = module.network.lambda_security_group_id

  db_host     = module.rds.db_host
  db_port     = module.rds.db_port
  db_name     = module.rds.db_name
  db_username = module.rds.db_username
  db_password = var.db_password

  s3_media_bucket = module.s3_media.bucket_id
  ses_from_email  = module.ses.from_email
  jwt_secret      = var.jwt_secret
}

# API Gateway
module "api_gateway" {
  source = "../../modules/api-gateway"

  env                  = local.env
  lambda_function_arn  = module.lambda.function_arn
  lambda_function_name = module.lambda.function_name
}

