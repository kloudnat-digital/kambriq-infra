# ============================================================================
# KAMBRIQ v2.0 - Infrastructure Terraform - Environnement DEV
# ============================================================================
# Architecture V2: ECS Fargate + ALB + CloudFront + FastAPI + Next.js
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
  env         = "dev"
  project_name = "kambriq"
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
# ECR Repositories
# ============================================================================

module "ecr_api" {
  source = "../../modules/ecr-repository"

  repository_name      = "kambriq-api"  # Repository partagé dev/prod
  env                  = local.env
  aws_region           = var.aws_region
  image_tag_mutability = "MUTABLE"
  scan_on_push         = true
  image_retention_count = 10
}

module "ecr_web" {
  source = "../../modules/ecr-repository"

  repository_name      = "kambriq-web"  # Repository partagé dev/prod
  env                  = local.env
  aws_region           = var.aws_region
  image_tag_mutability = "MUTABLE"
  scan_on_push         = true
  image_retention_count = 10
}

# ============================================================================
# ECS Cluster
# ============================================================================

module "ecs_cluster" {
  source = "../../modules/ecs-cluster"

  project_name             = local.project_name
  env                      = local.env
  aws_region               = var.aws_region
  enable_container_insights = true
  log_retention_days       = 7
}

# ============================================================================
# Security Groups
# ============================================================================

# Security Group for ECS Tasks (API + Web)
resource "aws_security_group" "ecs" {
  name        = "${local.project_name}-ecs-${local.env}"
  description = "Security group for ECS tasks"
  vpc_id      = data.terraform_remote_state.shared.outputs.vpc_id

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks  = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.project_name}-ecs-${local.env}"
    Env  = local.env
    Type = "ecs-security-group"
  }
}

# Security Group Rule: ALB → ECS
resource "aws_security_group_rule" "alb_to_ecs" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = module.alb.alb_security_group_id
  security_group_id         = aws_security_group.ecs.id
  description               = "Allow traffic from ALB to ECS"
}

# Security Group for RDS (reuse existing or create new)
resource "aws_security_group" "rds" {
  name        = "${local.project_name}-rds-${local.env}"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = data.terraform_remote_state.shared.outputs.vpc_id

  ingress {
    description     = "PostgreSQL from ECS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  tags = {
    Name = "${local.project_name}-rds-${local.env}"
    Env  = local.env
    Type = "rds-security-group"
  }
}

# ============================================================================
# IAM Roles for ECS Tasks
# ============================================================================

module "iam_roles_ecs" {
  source = "../../modules/iam-roles-ecs"

  project_name = local.project_name
  env          = local.env
  aws_region   = var.aws_region
}

# ============================================================================
# ALB
# ============================================================================

module "alb" {
  source = "../../modules/alb"

  project_name      = local.project_name
  env               = local.env
  vpc_id            = data.terraform_remote_state.shared.outputs.vpc_id
  public_subnet_ids = data.terraform_remote_state.shared.outputs.public_subnet_ids
  certificate_arn   = try(data.terraform_remote_state.shared.outputs.api_certificate_arn, null)

  api_port = 8000
  web_port = 3000
}

# ============================================================================
# CloudFront V2
# ============================================================================

# CloudFront certificate (must be in us-east-1)
variable "cloudfront_certificate_arn" {
  description = "ACM Certificate ARN for CloudFront (us-east-1)"
  type        = string
  default     = "arn:aws:acm:us-east-1:051551940370:certificate/061b780e-6b44-4535-96e3-e36c537d802f"
}

module "cloudfront_v2" {
  source = "../../modules/cloudfront-v2"

  project_name    = local.project_name
  env             = local.env
  alb_dns_name    = module.alb.alb_dns_name
  domain_name     = "dev.kambriq.com"
  certificate_arn = var.cloudfront_certificate_arn
}

# ============================================================================
# Route53 Record for CloudFront
# ============================================================================

resource "aws_route53_record" "dev" {
  zone_id = data.terraform_remote_state.shared.outputs.route53_zone_id
  name    = "dev.kambriq.com"
  type    = "A"

  alias {
    name                   = module.cloudfront_v2.distribution_domain_name
    zone_id                = module.cloudfront_v2.distribution_hosted_zone_id
    evaluate_target_health = false
  }
}

# ============================================================================
# Route53 Record for API Subdomain (bypass CloudFront)
# ============================================================================
# api.dev.kambriq.com points directly to ALB to bypass CloudFront for auth endpoints
# This ensures stable cookie behavior and avoids CloudFront caching issues

resource "aws_route53_record" "api_dev" {
  zone_id = data.terraform_remote_state.shared.outputs.route53_zone_id
  name    = "api.dev.kambriq.com"
  type    = "A"

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
}

# ============================================================================
# SSM Parameter Store - Secrets
# ============================================================================
# IMPORTANT: SSM Parameter Store est la source unique de vérité pour tous les secrets
# Les secrets doivent être créés AVANT le déploiement Terraform via:
#   ./scripts/generate-and-store-secrets.sh dev

# Database password from SSM Parameter Store
data "aws_ssm_parameter" "db_password" {
  name = "/kambriq/${local.env}/db/password"
}

# Database username (can be hardcoded or from SSM, using default for now)
# If needed, can be moved to SSM: data.aws_ssm_parameter.db_username
locals {
  db_username = "kambriq_admin" # Default username, can be moved to SSM if needed
}

# ============================================================================
# RDS PostgreSQL (reuse existing module)
# ============================================================================

module "rds_postgres" {
  source = "../../modules/rds-postgres"

  env                = local.env
  vpc_id             = data.terraform_remote_state.shared.outputs.vpc_id
  subnet_ids         = data.terraform_remote_state.shared.outputs.private_subnet_ids
  security_group_id  = aws_security_group.rds.id
  instance_class     = "db.t4g.micro"
  allocated_storage  = 20
  storage_type       = "gp3"
  db_name            = "kambriq"
  db_username        = local.db_username
  db_password        = data.aws_ssm_parameter.db_password.value
  backup_retention_period = 7
  skip_final_snapshot     = true
}

# ============================================================================
# ECS Services
# ============================================================================

# ECS Service: FastAPI
module "ecs_service_api" {
  source = "../../modules/ecs-service"

  project_name            = local.project_name
  env                     = local.env
  service_name            = "api"
  cluster_id              = module.ecs_cluster.cluster_id
  task_execution_role_arn = module.ecs_cluster.task_execution_role_arn
  task_role_arn           = module.iam_roles_ecs.task_api_role_arn
  container_image         = "${module.ecr_api.repository_url}:latest"
  container_port          = 8000
  cpu                     = 256
  memory                  = 512
  desired_count           = 2  # OPTIMIZATION: Increased from 1 to 2 for better availability and performance
  min_capacity            = 2  # OPTIMIZATION: Minimum 2 tasks to avoid cold starts
  max_capacity            = 10 # OPTIMIZATION: Allow scaling up to 10 tasks
  cpu_target_value        = 60.0 # OPTIMIZATION: Scale when CPU > 60%
  subnet_ids              = data.terraform_remote_state.shared.outputs.private_subnet_ids
  security_group_ids      = [aws_security_group.ecs.id]
  target_group_arn        = module.alb.api_target_group_arn
  assign_public_ip         = false

  # Enable init container for database migrations
  enable_init_container   = true
  init_container_image    = "${module.ecr_api.repository_url}:latest"

  environment_variables = {
    ENV           = local.env
    AWS_REGION    = var.aws_region
    FRONTEND_URL  = "https://dev.kambriq.com"
    CORS_ORIGINS  = "https://dev.kambriq.com,https://api.dev.kambriq.com"
  }

  secrets = {
    DATABASE_URL = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/kambriq/${local.env}/api/DATABASE_URL"
    JWT_SECRET   = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/kambriq/${local.env}/api/JWT_SECRET"
  }

  health_check_path = "/health"
  aws_region        = var.aws_region
}

# ECS Service: Next.js
module "ecs_service_web" {
  source = "../../modules/ecs-service"

  project_name            = local.project_name
  env                     = local.env
  service_name            = "web"
  cluster_id              = module.ecs_cluster.cluster_id
  task_execution_role_arn = module.ecs_cluster.task_execution_role_arn
  task_role_arn           = module.iam_roles_ecs.task_web_role_arn
  container_image         = "${module.ecr_web.repository_url}:latest"
  container_port          = 3000
  cpu                     = 256
  memory                  = 512
  desired_count           = 2  # OPTIMIZATION: Increased from 1 to 2 for better availability and performance
  min_capacity            = 2  # OPTIMIZATION: Minimum 2 tasks to avoid cold starts
  max_capacity            = 10 # OPTIMIZATION: Allow scaling up to 10 tasks
  cpu_target_value        = 60.0 # OPTIMIZATION: Scale when CPU > 60%
  subnet_ids              = data.terraform_remote_state.shared.outputs.private_subnet_ids
  security_group_ids      = [aws_security_group.ecs.id]
  target_group_arn        = module.alb.web_target_group_arn
  assign_public_ip        = false

  environment_variables = {
    ENV                     = local.env
    NEXT_PUBLIC_SITE_URL    = "https://dev.kambriq.com"
    NEXT_PUBLIC_API_BASE_URL = "https://api.dev.kambriq.com"
  }

  # No NextAuth secrets needed - using JWT with HttpOnly cookies
  secrets = {}

  health_check_path = "/health"
  aws_region        = var.aws_region
}

# Data source for account ID
data "aws_caller_identity" "current" {}

# ============================================================================
# SSM Application Parameters
# ============================================================================
# Create SSM parameters for application runtime configuration
# These parameters are read by the application at runtime from SSM

# JWT secret from SSM (legacy lowercase path)
data "aws_ssm_parameter" "jwt_secret" {
  name = "/kambriq/${local.env}/api/jwt_secret"
}

module "ssm_app_parameters" {
  source = "../../modules/ssm-app-parameters"

  env = local.env

  # Database connection details
  db_host     = module.rds_postgres.db_host
  db_port     = module.rds_postgres.db_port
  db_name     = module.rds_postgres.db_name
  db_username = local.db_username
  db_password = data.aws_ssm_parameter.db_password.value

  # JWT secret (read from existing SSM - will create /kambriq/{env}/api/JWT_SECRET from /kambriq/{env}/api/jwt_secret)
  jwt_secret = data.aws_ssm_parameter.jwt_secret.value

  # Frontend URL from CloudFront
  frontend_url = "https://dev.kambriq.com"

  # SES sender email
  ses_from_email = "noreply@kambriq.com"

  # Additional API KV (String) - Default values for dev
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
  paypal_environment                         = "sandbox"

  # Web KV (public) - stored under /kambriq/dev/web/*
  api_gateway_base_url                   = "https://api.dev.kambriq.com"
  frontend_cloudfront_domain             = module.cloudfront_v2.distribution_domain_name
  next_public_jwt_expires_in             = 900
  next_public_jwt_refresh_buffer_seconds = 180
  next_public_stale_time                 = 300
  next_public_refetch_interval           = 300
  next_public_paypal_client_id           = "" # Keep empty by default (set manually in SSM later)

  # Web runtime parameters (SSR) - Not used in new architecture (no NextAuth)
  # nextauth_url and nextauth_secret variables removed - not used in new architecture
  api_base_url = "https://api.dev.kambriq.com"
  # jwt_expires_in is already defined above in Additional API KV section
}

