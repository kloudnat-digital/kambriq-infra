# ============================================================================
# ECS Service Module - KAMBRIQ v2.0
# ============================================================================
# Creates ECS Task Definition and Service for a single application
# ============================================================================

locals {
  name_prefix = "${var.project_name}-${var.env}-${var.service_name}"
}

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

  container_definitions = jsonencode([
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

      environment = var.environment_variables

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
    }
  ])

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

  deployment_configuration {
    maximum_percent         = 200
    minimum_healthy_percent = 100
  }

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

