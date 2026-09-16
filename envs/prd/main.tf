locals {
  name_prefix = "${var.project_name}-${var.env}"
  # Include port 3001 explicitly: web container listens on 3001 even though
  # web_port (TG port) is 3000 to avoid target-group recreation.
  alb_ingress_ports = distinct([var.api_port, var.web_port, 3001])
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
  source                    = "../../modules/ecs-cluster"
  project_name              = var.project_name
  env                       = var.env
  aws_region                = var.aws_region
  enable_container_insights = var.enable_container_insights
}

module "alb" {
  source                    = "../../modules/alb"
  project_name              = var.project_name
  env                       = var.env
  vpc_id                    = data.terraform_remote_state.shared.outputs.vpc_id
  public_subnet_ids         = aws_subnet.public[*].id
  certificate_arn           = var.api_acm_certificate_arn
  api_port                  = var.api_port
  web_port                  = var.web_port
  redirect_www_to_apex_host = "kambriq.com"
}

resource "aws_route53_record" "prod_apex" {
  zone_id = data.terraform_remote_state.shared.outputs.route53_zone_id
  name    = "kambriq.com"
  type    = "A"

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
}

# www.dev.kambriq.com → ALB (ALB listener rule then 301-redirects to dev.kambriq.com)
resource "aws_route53_record" "prod_www" {
  zone_id = data.terraform_remote_state.shared.outputs.route53_zone_id
  name    = "www.kambriq.com"
  type    = "A"

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
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
    resources = [
      module.ecr_api.repository_arn,
      module.ecr_web.repository_arn,
    ]
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
    sid = "ElbDescribe"
    actions = [
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeTargetGroups",
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
      module.iam_roles_ecs.task_web_role_arn,
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
  db_password             = random_password.db_master.result
  instance_class          = var.rds_instance_class
  allocated_storage       = var.rds_allocated_storage
  storage_type            = var.rds_storage_type
  backup_retention_period = var.rds_backup_retention_period
  skip_final_snapshot     = var.rds_skip_final_snapshot
  enable_cloudwatch_logs  = var.rds_enable_cloudwatch_logs
  vpc_id                  = data.terraform_remote_state.shared.outputs.vpc_id
  subnet_ids              = aws_subnet.private[*].id
  security_group_id       = aws_security_group.rds.id
  multi_az                = var.rds_multi_az
  deletion_protection     = var.rds_deletion_protection
}

module "redis" {
  source                     = "../../modules/elasticache-redis"
  project_name               = var.project_name
  env                        = var.env
  subnet_ids                 = aws_subnet.private[*].id
  security_group_ids         = [aws_security_group.redis.id]
  node_type                  = var.redis_node_type
  engine_version             = var.redis_engine_version
  port                       = var.redis_port
  auth_token                 = var.redis_auth_token
  transit_encryption_enabled = var.redis_transit_encryption_enabled
}

module "s3_media" {
  source       = "../../modules/s3-media"
  env          = var.env
  project_name = var.project_name
  bucket_name  = var.s3_media_bucket_name

  versioning_enabled       = var.s3_media_versioning_enabled
  tmp_prefix               = var.s3_media_tmp_prefix
  tmp_expiration_days      = var.s3_media_tmp_expiration_days
  lands_prefix             = var.s3_media_lands_prefix
  lands_ia_transition_days = var.s3_media_lands_ia_transition_days

  cors_allowed_methods = var.s3_media_cors_allowed_methods
  cors_allowed_origins = var.s3_media_cors_allowed_origins
}

module "ssm_app_parameters" {
  source                  = "../../modules/ssm-app-parameters"
  env                     = var.env
  db_host                 = module.rds.db_host
  db_port                 = module.rds.db_port
  db_core_name            = var.db_core_name
  db_kbs_name             = var.db_kbs_name
  db_kamnet_name          = var.db_kamnet_name
  db_lands_name           = var.db_lands_name
  db_extra                = var.db_extra
  db_username             = var.db_username
  db_password             = random_password.db_master.result
  jwt_secret              = var.jwt_secret
  use_existing_jwt_secret = var.use_existing_jwt_secret
  frontend_url            = var.frontend_url

  node_env                     = var.node_env
  port                         = var.api_port
  api_prefix                   = var.api_prefix
  cors_origins                 = var.cors_origins
  throttle_ttl                 = var.throttle_ttl
  throttle_limit               = var.throttle_limit
  redis_host                   = module.redis.primary_endpoint_address
  redis_port                   = module.redis.port
  aws_s3_bucket                = module.s3_media.bucket_id
  aws_region                   = var.aws_region
  aws_s3_region                = var.aws_region
  s3_presigned_url_ttl_seconds = var.s3_presigned_url_ttl_seconds
  s3_max_upload_size_mb        = var.s3_max_upload_size_mb
  email_from                   = var.ses_from_email
  email_from_name              = var.email_from_name
  salt_rounds                  = var.salt_rounds
  jwt_access_expiration        = var.jwt_access_expiration
  jwt_refresh_expiration       = var.jwt_refresh_expiration
}

module "iam_roles_ecs" {
  source          = "../../modules/iam-roles-ecs"
  project_name    = var.project_name
  env             = var.env
  aws_region      = var.aws_region
  enable_ecs_exec = var.enable_ecs_exec
}

module "ecs_service_api" {
  source                  = "../../modules/ecs-service"
  project_name            = var.project_name
  env                     = var.env
  service_name            = "api"
  cluster_id              = module.ecs_cluster.cluster_id
  task_execution_role_arn = module.ecs_cluster.task_execution_role_arn
  task_role_arn           = module.iam_roles_ecs.task_api_role_arn
  container_image         = "${module.ecr_api.repository_url}:${var.api_image_tag}"
  container_port          = var.api_port
  cpu                     = var.api_cpu
  memory                  = var.api_memory
  desired_count           = var.api_desired_count
  subnet_ids              = aws_subnet.private[*].id
  security_group_ids      = [aws_security_group.ecs.id]
  target_group_arn        = module.alb.api_target_group_arn
  assign_public_ip        = false
  aws_region              = var.aws_region
  health_check_path       = var.api_health_check_path
  enable_init_container   = false
  enable_execute_command  = var.enable_ecs_exec

  environment_variables = {
    NODE_ENV                     = var.node_env
    PORT                         = tostring(var.api_port)
    API_PREFIX                   = var.api_prefix
    CORS_ORIGINS                 = var.cors_origins
    THROTTLE_TTL                 = tostring(var.throttle_ttl)
    THROTTLE_LIMIT               = tostring(var.throttle_limit)
    REDIS_HOST                   = module.redis.primary_endpoint_address
    REDIS_PORT                   = tostring(module.redis.port)
    AWS_S3_BUCKET                = module.s3_media.bucket_id
    AWS_S3_REGION                = var.aws_region
    AWS_REGION                   = var.aws_region
    S3_PRESIGNED_URL_TTL_SECONDS = tostring(var.s3_presigned_url_ttl_seconds)
    S3_MAX_UPLOAD_SIZE_MB        = tostring(var.s3_max_upload_size_mb)
    EMAIL_FROM                   = var.ses_from_email
    EMAIL_FROM_NAME              = var.email_from_name
    # Sourced from the resource, never a literal: Terraform is the single source
    # of the contact list name. The app's default in env.validation.ts is then a
    # fallback that never applies in a deployed environment.
    AWS_SES_CONTACT_LIST_NAME = data.terraform_remote_state.shared.outputs.newsletter_contact_list_name
    FRONTEND_URL              = var.frontend_url
    SALT_ROUNDS               = tostring(var.salt_rounds)
    JWT_ACCESS_EXPIRATION     = var.jwt_access_expiration
    JWT_REFRESH_EXPIRATION    = var.jwt_refresh_expiration

    # G10 - payment channel details.
    #
    # **The prefix, not the values.** The twelve bank / mobile money / notary
    # parameters are deliberately neither `environment_variables` (which
    # terraform renders at apply time) nor ECS `secrets` (which the agent
    # resolves at task start). Either would mean a wrong account number is
    # corrected by a deployment. G3 chose a runtime SDK reader with a 60-second
    # cache so that `aws ssm put-parameter --overwrite` takes effect on the
    # running task within a minute, and this is where that choice is kept.
    #
    # Sourced from the module rather than written as a literal, so the path the
    # API reads and the path the parameters live under cannot drift apart.
    PAYMENT_CHANNELS_SSM_PREFIX = module.ssm_app_parameters.payment_channels_prefix

    # 'ssm' is the schema default; naming it here is the difference between an
    # environment that is configured and one that merely has not said otherwise.
    # With 'ssm' and no prefix the API refuses to start - which is what G10 fixed
    # in the application, and what this line makes sure never has to fire.
    PAYMENT_CHANNELS_TRANSPORT = "ssm"

    # G9 - how long a payment stays valid. Reaches the client as the deadline in
    # the instruction email. See the register: the number is a choice, not a
    # specification, and it is a variable so that settling it is one edit.
    PAYMENT_VALIDITY_DAYS = tostring(var.payment_validity_days)
  }

  secrets = merge({
    DATABASE_URL_CORE   = module.ssm_app_parameters.database_url_core_parameter_arn
    DATABASE_URL_KBS    = module.ssm_app_parameters.database_url_kbs_parameter_arn
    DATABASE_URL_KAMNET = module.ssm_app_parameters.database_url_kamnet_parameter_arn
    DATABASE_URL_LANDS  = module.ssm_app_parameters.database_url_lands_parameter_arn
    JWT_SECRET          = module.ssm_app_parameters.jwt_secret_parameter_arn
  }, module.ssm_app_parameters.database_url_extra_parameter_arns)
}

module "ecs_service_web" {
  count                   = var.enable_web_service ? 1 : 0
  source                  = "../../modules/ecs-service"
  project_name            = var.project_name
  env                     = var.env
  service_name            = "web"
  cluster_id              = module.ecs_cluster.cluster_id
  task_execution_role_arn = module.ecs_cluster.task_execution_role_arn
  task_role_arn           = module.iam_roles_ecs.task_web_role_arn
  container_image         = "${module.ecr_web.repository_url}:${var.web_image_tag}"
  container_port          = 3001
  cpu                     = var.web_cpu
  memory                  = var.web_memory
  desired_count           = var.web_desired_count
  subnet_ids              = aws_subnet.private[*].id
  security_group_ids      = [aws_security_group.ecs.id]
  target_group_arn        = module.alb.web_target_group_arn
  assign_public_ip        = false
  aws_region              = var.aws_region
  health_check_path       = var.web_health_check_path
  enable_init_container   = false
  enable_execute_command  = var.enable_ecs_exec

  environment_variables = {
    PORT         = "3001"
    NODE_ENV     = var.node_env
    NEXTAUTH_URL = var.frontend_url
  }

  secrets = {
    AUTH_SECRET    = module.ssm_app_parameters.web_nextauth_secret_parameter_arn
    JWT_EXPIRES_IN = module.ssm_app_parameters.web_jwt_expires_in_parameter_arn
  }
}
