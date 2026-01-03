# ============================================================================
# IAM Roles for ECS Tasks - KAMBRIQ v2.0
# ============================================================================
# Creates IAM roles for ECS tasks (API and Web)
# ============================================================================

locals {
  name_prefix = "${var.project_name}-${var.env}"
}

# IAM Role for ECS Task (API - FastAPI)
resource "aws_iam_role" "task_api" {
  name = "${local.name_prefix}-ecs-task-api"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${local.name_prefix}-ecs-task-api"
    Env  = var.env
    Type = "ecs-iam"
  }
}

# IAM Role for ECS Task (Web - Next.js)
resource "aws_iam_role" "task_web" {
  name = "${local.name_prefix}-ecs-task-web"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${local.name_prefix}-ecs-task-web"
    Env  = var.env
    Type = "ecs-iam"
  }
}

# Policy for API Task: SSM Parameter Store access
resource "aws_iam_role_policy" "api_ssm" {
  name = "${local.name_prefix}-api-ssm"
  role = aws_iam_role.task_api.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = [
          "arn:aws:ssm:${var.aws_region}:*:parameter/kambriq/${var.env}/api/*",
          "arn:aws:ssm:${var.aws_region}:*:parameter/kambriq/${var.env}/db/*"
        ]
      }
    ]
  })
}

# Policy for API Task: RDS access (via security group, but allow describe)
resource "aws_iam_role_policy" "api_rds" {
  name = "${local.name_prefix}-api-rds"
  role = aws_iam_role.task_api.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances"
        ]
        Resource = "*"
      }
    ]
  })
}

# Policy for Web Task: SSM Parameter Store access (read-only, public vars)
resource "aws_iam_role_policy" "web_ssm" {
  name = "${local.name_prefix}-web-ssm"
  role = aws_iam_role.task_web.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = [
          "arn:aws:ssm:${var.aws_region}:*:parameter/kambriq/${var.env}/web/*"
        ]
      }
    ]
  })
}

