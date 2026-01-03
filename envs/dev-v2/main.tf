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
  image_tag_mutability = "MUTABLE"
  scan_on_push         = true
  image_retention_count = 10
}

module "ecr_web" {
  source = "../../modules/ecr-repository"

  repository_name      = "kambriq-web"  # Repository partagé dev/prod
  env                  = local.env
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
  certificate_arn   = data.terraform_remote_state.shared.outputs.api_certificate_arn

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
# RDS PostgreSQL (reuse existing module)
# ============================================================================

module "rds_postgres" {
  source = "../../modules/rds-postgres"

  env                = local.env
  subnet_ids         = data.terraform_remote_state.shared.outputs.private_subnet_ids
  security_group_id  = aws_security_group.rds.id
  instance_class     = "db.t4g.micro"
  allocated_storage  = 20
  storage_type       = "gp3"
  db_name            = "kambriq"
  db_username        = var.db_username
  db_password        = var.db_password
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
  desired_count           = 1
  subnet_ids              = data.terraform_remote_state.shared.outputs.private_subnet_ids
  security_group_ids      = [aws_security_group.ecs.id]
  target_group_arn        = module.alb.api_target_group_arn
  assign_public_ip        = false

  environment_variables = {
    ENV         = local.env
    AWS_REGION  = var.aws_region
  }

  secrets = {
    DATABASE_URL = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/kambriq/${local.env}/db/url"
    JWT_SECRET   = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/kambriq/${local.env}/api/JWT_SECRET"
  }

  health_check_path = "/api/health"
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
  desired_count           = 1
  subnet_ids              = data.terraform_remote_state.shared.outputs.private_subnet_ids
  security_group_ids      = [aws_security_group.ecs.id]
  target_group_arn        = module.alb.web_target_group_arn
  assign_public_ip        = false

  environment_variables = {
    ENV                    = local.env
    NEXT_PUBLIC_SITE_URL    = "https://dev.kambriq.com"
    NEXT_PUBLIC_API_URL     = "https://dev.kambriq.com/api"
  }

  health_check_path = "/health"
  aws_region        = var.aws_region
}

# Data source for account ID
data "aws_caller_identity" "current" {}

