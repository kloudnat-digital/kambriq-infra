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

  domain_name     = var.domain_name
  route53_zone_id = var.route53_zone_id

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

# ============================================================================
# Remote State - Dev and Prod (for RDS Security Groups)
# ============================================================================
# Note: These remote states are used to get RDS Security Groups for bastion access
# The bastion is shared between dev and prod environments

# Remote states for dev and prod (to get RDS Security Group IDs)
# Note: These may not exist yet if dev/prod haven't been deployed
# We use try() in the module to handle missing remote states gracefully
data "terraform_remote_state" "dev" {
  count   = var.enable_bastion ? 1 : 0
  backend = "s3"

  config = {
    bucket = "kloudnat-infra-shared-store"
    key    = "kambriq/dev/terraform.tfstate"
    region = var.aws_region
  }
}

# Prod remote state - COMMENTED OUT until prod is deployed
# Uncomment this block after deploying prod environment
# data "terraform_remote_state" "prod" {
#   count   = var.enable_bastion ? 1 : 0
#   backend = "s3"
#
#   config = {
#     bucket = "kloudnat-infra-shared-store"
#     key    = "kambriq/prod/terraform.tfstate"
#     region = var.aws_region
#   }
# }

# ============================================================================
# Bastion Host (shared between dev and prod)
# ============================================================================
# The bastion allows SSH access to execute database migrations manually
# for both dev and prod RDS instances.

# Data source to get RDS Security Group from dev (if it exists)
# This allows the bastion to be created even if dev-v2 is not yet deployed
# We use try() to handle the case where the security group doesn't exist yet
data "aws_security_group" "rds_dev" {
  count  = var.enable_bastion ? 1 : 0
  name   = "kambriq-rds-dev"
  vpc_id = module.shared.vpc_id
}

module "bastion" {
  count  = var.enable_bastion ? 1 : 0
  source = "../../modules/bastion"

  env              = "shared"
  project_name     = local.project_name
  vpc_id           = module.shared.vpc_id
  public_subnet_id = module.shared.public_subnet_ids[0] # Use first public subnet

  # Get RDS Security Groups from dev and prod
  # Try to get from data source first (more reliable), then fallback to remote state
  # This ensures the egress rule is created even if remote state doesn't exist yet
  rds_security_group_ids = var.enable_bastion ? compact([
    try(data.aws_security_group.rds_dev[0].id, ""),
    try(data.terraform_remote_state.dev[0].outputs.rds_security_group_id, ""),
    # Uncomment after prod is deployed:
    # try(data.terraform_remote_state.prod[0].outputs.rds_security_group_id, ""),
  ]) : []

  bastion_key_pair_name = var.bastion_key_pair_name
  allowed_ssh_cidr      = var.allowed_ssh_cidr
  instance_type         = "t3.micro"
  aws_region            = var.aws_region
}
