variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "env" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for ALB"
  type        = list(string)
}

variable "certificate_arn" {
  description = "ACM Certificate ARN for HTTPS listener"
  type        = string
}

variable "api_port" {
  description = "Port for FastAPI target group"
  type        = number
  default     = 8000
}

variable "web_port" {
  description = "Port for Next.js target group"
  type        = number
  default     = 3000
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for ALB"
  type        = bool
  default     = false
}

