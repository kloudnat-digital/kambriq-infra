variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "env" {
  description = "Environment name (dev, prd)"
  type        = string
}

variable "alb_dns_name" {
  description = "ALB DNS name (origin for CloudFront)"
  type        = string
}

variable "domain_name" {
  description = "Custom domain name (e.g., dev.kambriq.com)"
  type        = string
  default     = ""
}

variable "certificate_arn" {
  description = "ACM Certificate ARN for CloudFront (must be in us-east-1)"
  type        = string
  default     = ""
}

