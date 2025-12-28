variable "env" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "function_name" {
  description = "Lambda function name"
  type        = string
  default     = ""
}

variable "ecr_repository_url" {
  description = "ECR repository URL for container image (e.g., 123456789012.dkr.ecr.eu-central-1.amazonaws.com/kambriq-api-dev)"
  type        = string
}

variable "image_uri" {
  description = "Container image URI (optional, defaults to ecr_repository_url:latest). CI/CD will update this."
  type        = string
  default     = ""
}

variable "ecr_placeholder_ready" {
  description = "Reference to ECR placeholder image resource (ensures placeholder is created before Lambda)"
  type        = any
  default     = null
}

variable "timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 30
}

variable "memory_size" {
  description = "Lambda memory size in MB"
  type        = number
  default     = 512
}

variable "role_arn" {
  description = "IAM role ARN for Lambda"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for Lambda"
  type        = string
}

variable "db_host" {
  description = "Database host"
  type        = string
}

variable "db_port" {
  description = "Database port"
  type        = number
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "db_username" {
  description = "Database username"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "s3_media_bucket" {
  description = "S3 media bucket name"
  type        = string
}

variable "ses_from_email" {
  description = "SES sender email address"
  type        = string
}

variable "jwt_secret" {
  description = "JWT secret key"
  type        = string
  sensitive   = true
}

variable "frontend_url" {
  description = "Frontend URL for CORS configuration (e.g., https://dev.kambriq.com or CloudFront URL)"
  type        = string
}

# ============================================================================
# Artifact Configuration - REMOVED
# ============================================================================
# Variables artifact_bucket_name and api_bundle_s3_key have been removed.
# Terraform only creates the Lambda function structure with dummy placeholder code.
# Application code is deployed via workflows deploy-app-dev.yml and deploy-app-prod.yml
# in the kambriq repository using aws lambda update-function-code.

