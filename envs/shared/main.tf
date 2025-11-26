# ============================================================================
# KAMBRIQ - Shared Infrastructure
# ============================================================================
#
# This stack creates shared resources used by all environments (dev, prod):
# - VPC with public/private subnets + NAT Gateway
# - Route53 hosted zone for kambriq.com
# - SES domain identity
# - ACM certificates (API Gateway)
# - S3 buckets for logs and artifacts
#
# This stack must be deployed BEFORE dev and prod.
#
# ============================================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  project_name = "kambriq"
  env          = "shared"
}

# Shared Infrastructure Module
module "shared" {
  source = "../../modules/shared"

  project_name = local.project_name
  aws_region   = var.aws_region
  vpc_cidr     = var.vpc_cidr

  domain_name = var.domain_name

  # SES Configuration (created manually in AWS Console)
  ses_domain              = var.ses_domain
  ses_domain_identity_arn = var.ses_domain_identity_arn
  ses_from_email          = var.ses_from_email
  ses_email_identity_arn  = var.ses_email_identity_arn

  # ACM Certificates (created manually in AWS Console)
  api_acm_certificate_arn        = var.api_acm_certificate_arn
  cloudfront_acm_certificate_arn = var.cloudfront_acm_certificate_arn

  enable_s3_logs      = var.enable_s3_logs
  enable_s3_artifacts = var.enable_s3_artifacts
}

