terraform {
  required_version = ">= 1.5.0"
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

module "shared" {
  source = "../../modules/shared"

  project_name                  = var.project_name
  aws_region                    = var.aws_region
  vpc_cidr                      = var.vpc_cidr
  availability_zones            = var.availability_zones
  nat_per_az                    = var.nat_per_az
  domain_name                   = var.domain_name
  route53_zone_id               = var.route53_zone_id
  enable_route53_lookup         = var.enable_route53_lookup
  ses_domain                    = var.ses_domain
  ses_from_email                = var.ses_from_email
  ses_domain_identity_arn        = var.ses_domain_identity_arn
  ses_email_identity_arn         = var.ses_email_identity_arn
  api_acm_certificate_arn        = var.api_acm_certificate_arn
  cloudfront_acm_certificate_arn = var.cloudfront_acm_certificate_arn
  enable_s3_logs                 = var.enable_s3_logs
  enable_s3_artifacts            = var.enable_s3_artifacts
}
