variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "env" {
  description = "Environment name (dev, prd)"
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
  description = "ACM Certificate ARN for HTTPS listener (optional, if null, HTTP only)"
  type        = string
  default     = null
}

variable "api_port" {
  description = "Port for NestJS API target group"
  type        = number
  default     = 3000
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

variable "access_logs_bucket" {
  description = "S3 bucket name for ALB access logs. Leave empty to disable."
  type        = string
  default     = ""
}

variable "redirect_www_to_apex_host" {
  description = "Apex host (e.g. dev.kambriq.com). When non-empty and certificate_arn is set, www.<host> is 301-redirected to <host> on both HTTP and HTTPS listeners. Leave empty to disable."
  type        = string
  default     = ""
}

