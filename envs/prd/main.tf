terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  name_prefix        = "${var.project_name}-${var.env}"
  alb_ingress_ports  = distinct([var.api_port, var.web_port])
}

data "terraform_remote_state" "shared" {
  backend = "s3"
  config = {
    bucket = var.shared_state_bucket
    key    = var.shared_state_key
    region = var.shared_state_region
  }
}

module "ecr_api" {
  source          = "../../modules/ecr-repository"
  repository_name = var.ecr_api_repo_name
  env             = var.env
  aws_region      = var.aws_region
}

module "ecr_web" {
  source          = "../../modules/ecr-repository"
  repository_name = var.ecr_web_repo_name
  env             = var.env
  aws_region      = var.aws_region
}

module "ecs_cluster" {
  source      = "../../modules/ecs-cluster"
  project_name = var.project_name
  env         = var.env
  aws_region  = var.aws_region
}

module "alb" {
  source            = "../../modules/alb"
  project_name      = var.project_name
  env               = var.env
  vpc_id            = data.terraform_remote_state.shared.outputs.vpc_id
  public_subnet_ids = data.terraform_remote_state.shared.outputs.public_subnet_ids
  certificate_arn   = var.api_acm_certificate_arn
  api_port          = var.api_port
  web_port          = var.web_port
}

resource "aws_security_group" "ecs" {
  name        = "${local.name_prefix}-ecs-sg"
  description = "Security group for ECS tasks"
  vpc_id      = data.terraform_remote_state.shared.outputs.vpc_id

  dynamic "ingress" {
    for_each = toset(local.alb_ingress_ports)
    content {
      description     = "ALB to ECS on ${ingress.value}"
      from_port       = ingress.value
      to_port         = ingress.value
      protocol        = "tcp"
      security_groups = [module.alb.alb_security_group_id]
    }
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-ecs-sg"
    Env  = var.env
  }
}

resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds-sg"
  description = "Security group for RDS"
  vpc_id      = data.terraform_remote_state.shared.outputs.vpc_id

  ingress {
    description     = "Postgres from ECS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-rds-sg"
    Env  = var.env
  }
}

resource "aws_security_group" "redis" {
  name        = "${local.name_prefix}-redis-sg"
  description = "Security group for Redis"
  vpc_id      = data.terraform_remote_state.shared.outputs.vpc_id

  ingress {
    description     = "Redis from ECS"
    from_port       = var.redis_port
    to_port         = var.redis_port
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-redis-sg"
    Env  = var.env
  }
}

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.terraform_remote_state.shared.outputs.github_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:environment:${var.env}"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "${local.name_prefix}-github-actions"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json

  tags = {
    Name = "${local.name_prefix}-github-actions"
    Env  = var.env
  }
}

data "aws_iam_policy_document" "github_actions_permissions" {
  statement {
    sid = "EcrAuth"
    actions = [
      "ecr:GetAuthorizationToken",
    ]
    resources = ["*"]
  }

  statement {
    sid = "EcrPushPull"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [module.ecr_api.repository_arn]
  }

  statement {
    sid = "EcsDeploy"
    actions = [
      "ecs:DescribeServices",
      "ecs:DescribeTaskDefinition",
      "ecs:DescribeTasks",
      "ecs:ListTasks",
      "ecs:RegisterTaskDefinition",
      "ecs:RunTask",
      "ecs:StopTask",
      "ecs:UpdateService",
      "ecs:Wait",
    ]
    resources = ["*"]
  }

  statement {
    sid = "IamPassRole"
    actions = [
      "iam:PassRole",
    ]
    resources = [
      module.ecs_cluster.task_execution_role_arn,
      module.iam_roles_ecs.task_api_role_arn,
    ]
  }
}

resource "aws_iam_role_policy" "github_actions" {
  name   = "${local.name_prefix}-github-actions"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_permissions.json
}

module "rds" {
  source                  = "../../modules/rds-postgres"
  env                     = var.env
  db_name                 = var.db_core_name
  db_username             = var.db_username
  db_password             = var.db_password
  instance_class          = var.rds_instance_class
  allocated_storage       = var.rds_allocated_storage
  storage_type            = var.rds_storage_type
  backup_retention_period = var.rds_backup_retention_period
  skip_final_snapshot     = var.rds_skip_final_snapshot
  vpc_id                  = data.terraform_remote_state.shared.outputs.vpc_id
  subnet_ids              = data.terraform_remote_state.shared.outputs.private_subnet_ids
  security_group_id       = aws_security_group.rds.id
}

module "redis" {
  source                     = "../../modules/elasticache-redis"
  project_name               = var.project_name
  env                        = var.env
  subnet_ids                 = data.terraform_remote_state.shared.outputs.private_subnet_ids
  security_group_ids         = [aws_security_group.redis.id]
  node_type                  = var.redis_node_type
  engine_version             = var.redis_engine_version
  port                       = var.redis_port
  auth_token                 = var.redis_auth_token
  transit_encryption_enabled = var.redis_transit_encryption_enabled
}

module "s3_media" {
  source      = "../../modules/s3-media"
  env         = var.env
  bucket_name = var.s3_media_bucket_name
}

module "ssm_app_parameters" {
  source        = "../../modules/ssm-app-parameters"
  env           = var.env
  db_host       = module.rds.db_host
  db_port       = module.rds.db_port
  db_core_name  = var.db_core_name
  db_kbs_name   = var.db_kbs_name
  db_username   = var.db_username
  db_password   = var.db_password
  jwt_secret    = var.jwt_secret
  use_existing_jwt_secret = var.use_existing_jwt_secret
  frontend_url  = var.frontend_url
  ses_from_email = var.ses_from_email

  node_env            = var.node_env
  port                = var.api_port
  api_prefix          = var.api_prefix
  cors_origins        = var.cors_origins
  throttle_ttl        = var.throttle_ttl
  throttle_limit      = var.throttle_limit
  redis_host          = module.redis.primary_endpoint_address
  redis_port          = module.redis.port
  aws_s3_bucket       = module.s3_media.bucket_id
  aws_region          = var.aws_region
  email_from          = var.ses_from_email
  email_from_name     = var.email_from_name
  salt_rounds         = var.salt_rounds
  jwt_access_expiration  = var.jwt_access_expiration
  jwt_refresh_expiration = var.jwt_refresh_expiration
}

module "iam_roles_ecs" {
  source      = "../../modules/iam-roles-ecs"
  project_name = var.project_name
  env         = var.env
  aws_region  = var.aws_region
}

module "ecs_service_api" {
  source                 = "../../modules/ecs-service"
  project_name           = var.project_name
  env                    = var.env
  service_name           = "api"
  cluster_id             = module.ecs_cluster.cluster_id
  task_execution_role_arn = module.ecs_cluster.task_execution_role_arn
  task_role_arn          = module.iam_roles_ecs.task_api_role_arn
  container_image        = "${module.ecr_api.repository_url}:${var.api_image_tag}"
  container_port         = var.api_port
  cpu                    = var.api_cpu
  memory                 = var.api_memory
  desired_count          = var.api_desired_count
  subnet_ids             = data.terraform_remote_state.shared.outputs.private_subnet_ids
  security_group_ids     = [aws_security_group.ecs.id]
  target_group_arn       = module.alb.api_target_group_arn
  assign_public_ip       = false
  aws_region             = var.aws_region
  health_check_path      = var.api_health_check_path
  enable_init_container  = false

  environment_variables = {
    NODE_ENV               = var.node_env
    PORT                   = tostring(var.api_port)
    API_PREFIX             = var.api_prefix
    CORS_ORIGINS           = var.cors_origins
    THROTTLE_TTL           = tostring(var.throttle_ttl)
    THROTTLE_LIMIT         = tostring(var.throttle_limit)
    REDIS_HOST             = module.redis.primary_endpoint_address
    REDIS_PORT             = tostring(module.redis.port)
    AWS_S3_BUCKET          = module.s3_media.bucket_id
    AWS_REGION             = var.aws_region
    EMAIL_FROM             = var.ses_from_email
    EMAIL_FROM_NAME        = var.email_from_name
    FRONTEND_URL           = var.frontend_url
    SALT_ROUNDS            = tostring(var.salt_rounds)
    JWT_ACCESS_EXPIRATION  = var.jwt_access_expiration
    JWT_REFRESH_EXPIRATION = var.jwt_refresh_expiration
  }

  secrets = {
    DATABASE_URL_CORE = module.ssm_app_parameters.database_url_core_parameter_arn
    DATABASE_URL_KBS  = module.ssm_app_parameters.database_url_kbs_parameter_arn
    JWT_SECRET        = module.ssm_app_parameters.jwt_secret_parameter_arn
  }
}

module "ecs_service_web" {
  count                  = var.enable_web_service ? 1 : 0
  source                 = "../../modules/ecs-service"
  project_name           = var.project_name
  env                    = var.env
  service_name           = "web"
  cluster_id             = module.ecs_cluster.cluster_id
  task_execution_role_arn = module.ecs_cluster.task_execution_role_arn
  task_role_arn          = module.iam_roles_ecs.task_web_role_arn
  container_image        = "${module.ecr_web.repository_url}:${var.web_image_tag}"
  container_port         = var.web_port
  cpu                    = var.web_cpu
  memory                 = var.web_memory
  desired_count          = var.web_desired_count
  subnet_ids             = data.terraform_remote_state.shared.outputs.private_subnet_ids
  security_group_ids     = [aws_security_group.ecs.id]
  target_group_arn       = module.alb.web_target_group_arn
  assign_public_ip       = false
  aws_region             = var.aws_region
  health_check_path      = var.web_health_check_path
  enable_init_container  = false
}
