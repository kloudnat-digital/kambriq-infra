# ============================================================================
# ECS Service Module - KAMBRIQ v2.0
# ============================================================================
# Creates ECS Task Definition and Service for a single application
# ============================================================================

locals {
  name_prefix = "${var.project_name}-${var.env}-${var.service_name}"
}

# Data sources for ARN construction
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# CloudWatch Log Group for service
resource "aws_cloudwatch_log_group" "service" {
  name              = "/ecs/${local.name_prefix}"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${local.name_prefix}-logs"
    Env  = var.env
    Type = "ecs-service-logs"
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "main" {
  family                   = local.name_prefix
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode(concat(
    # Init container for database migrations (only if enabled and for API service)
    var.enable_init_container && var.service_name == "api" ? [
      {
        name             = "${var.service_name}-migrations"
        image            = var.init_container_image != "" ? var.init_container_image : var.container_image
        essential        = false
        workingDirectory = "/app"

        environment = [
          for key, value in var.environment_variables : {
            name  = key
            value = tostring(value)
          }
        ]

        secrets = var.secrets != null ? [
          for key, secret_arn in var.secrets : {
            name      = key
            valueFrom = secret_arn
          }
        ] : []

          command = [
            "sh",
            "-c",
            "cd /app && python -m alembic upgrade head && python /app/scripts/seed_database.py && (python /app/scripts/fix_test_users_roles.py || echo 'Warning: fix_test_users_roles.py failed, continuing...')"
          ]

        logConfiguration = {
          logDriver = "awslogs"
          options = {
            "awslogs-group"         = aws_cloudwatch_log_group.service.name
            "awslogs-region"        = var.aws_region
            "awslogs-stream-prefix" = "${var.service_name}-migrations"
          }
        }
      }
    ] : [],
    # Main application container
    [
      {
        name      = var.service_name
        image     = var.container_image
        essential = true

        portMappings = [
          {
            containerPort = var.container_port
            protocol      = "tcp"
          }
        ]

        environment = [
          for key, value in var.environment_variables : {
            name  = key
            value = tostring(value)
          }
        ]

        secrets = var.secrets != null ? [
          for key, secret_arn in var.secrets : {
            name      = key
            valueFrom = secret_arn
          }
        ] : []

        logConfiguration = {
          logDriver = "awslogs"
          options = {
            "awslogs-group"         = aws_cloudwatch_log_group.service.name
            "awslogs-region"        = var.aws_region
            "awslogs-stream-prefix" = var.service_name
          }
        }

        healthCheck = var.health_check_path != "" ? {
          command     = ["CMD-SHELL", "curl -f http://localhost:${var.container_port}${var.health_check_path} || exit 1"]
          interval    = 30
          timeout     = 5
          retries     = 3
          startPeriod = 60
        } : null

        dependsOn = var.enable_init_container && var.service_name == "api" ? [
          {
            containerName = "${var.service_name}-migrations"
            condition     = "SUCCESS"
          }
        ] : []
      }
    ]
  ))

  tags = {
    Name = local.name_prefix
    Env  = var.env
    Type = "ecs-task-definition"
  }
}

# ECS Service
resource "aws_ecs_service" "main" {
  name            = local.name_prefix
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = var.security_group_ids
    assign_public_ip = var.assign_public_ip
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = var.service_name
    container_port   = var.container_port
  }

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  tags = {
    Name = local.name_prefix
    Env  = var.env
    Type = "ecs-service"
  }

  depends_on = [aws_ecs_task_definition.main]
}

# ECS Auto Scaling Target
resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${var.cluster_id}/${aws_ecs_service.main.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# ECS Auto Scaling Policy (CPU-based)
resource "aws_appautoscaling_policy" "ecs_cpu_policy" {
  name               = "${local.name_prefix}-cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = var.cpu_target_value
    scale_in_cooldown  = var.scale_in_cooldown
    scale_out_cooldown = var.scale_out_cooldown
  }
}

