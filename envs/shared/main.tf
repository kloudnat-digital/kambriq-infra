# ============================================================================
# KAMBRIQ - Shared Infrastructure
# ============================================================================
#
# This stack creates shared resources used by all environments (dev, prod):
# - VPC with public/private subnets + NAT Gateway
# - Route53 hosted zone reference (created manually in AWS Console)
# - SES domain identity (created manually in AWS Console)
# - ACM certificates (created manually in AWS Console)
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

  domain_name      = var.domain_name
  route53_zone_id  = var.route53_zone_id

  # SES Configuration (created manually in AWS Console)
  # SES identities are managed manually - Terraform only consumes ARNs passed via tfvars.
  # See docs/setup/SES_AND_ACM_MANUAL_SETUP.md for manual setup instructions.
  ses_domain              = var.ses_domain
  ses_region              = var.ses_region
  ses_domain_identity_arn = var.ses_domain_identity_arn
  ses_from_email          = var.ses_from_email
  ses_email_identity_arn  = var.ses_email_identity_arn

  # ACM Certificates (created manually in AWS Console)
  # ACM certificates are managed manually - Terraform only consumes ARNs passed via tfvars.
  # CloudFront certificates must be in us-east-1, API Gateway certificates in eu-central-1.
  # See docs/setup/SES_AND_ACM_MANUAL_SETUP.md for manual setup instructions.
  api_acm_certificate_arn        = var.api_acm_certificate_arn
  cloudfront_acm_certificate_arn = var.cloudfront_acm_certificate_arn

  enable_s3_logs      = var.enable_s3_logs
  enable_s3_artifacts = var.enable_s3_artifacts
}
