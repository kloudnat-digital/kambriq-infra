variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "env" {
  description = "Environment name (dev, prd)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "enable_ecs_exec" {
  description = "Grant both task roles the ssmmessages channel permissions ECS Exec requires"
  type        = bool
  default     = false
}
