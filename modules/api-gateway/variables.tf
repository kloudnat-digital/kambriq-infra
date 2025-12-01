variable "env" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "lambda_function_arn" {
  description = "Lambda function ARN"
  type        = string
}

variable "lambda_function_name" {
  description = "Lambda function name"
  type        = string
}

variable "domain_name" {
  description = "Custom domain name (optional)"
  type        = string
  default     = ""
}

variable "certificate_arn" {
  description = "ACM certificate ARN for custom domain (optional). Certificate must be created manually in eu-central-1. See docs/setup/SES_AND_ACM_MANUAL_SETUP.md"
  type        = string
  default     = ""
}

