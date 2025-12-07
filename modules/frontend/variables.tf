variable "env" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "kambriq"
}

# ============================================================================
# Artifact Configuration - REMOVED
# ============================================================================
# Variables artifact_bucket_name and ssr_bundle_s3_key have been removed.
# Terraform only creates the Lambda SSR function structure with dummy placeholder code.
# Application code is deployed via workflows deploy-app-dev.yml and deploy-app-prod.yml
# in the kambriq repository using aws lambda update-function-code.

variable "vpc_id" {
  description = "VPC ID for Lambda functions"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for Lambda functions"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for Lambda functions"
  type        = string
}

variable "domain_name" {
  description = "Custom domain name for CloudFront (optional, e.g., app-dev.kambriq.com)"
  type        = string
  default     = ""
}

variable "certificate_arn" {
  description = "ACM certificate ARN for CloudFront custom domain (must be in us-east-1)"
  type        = string
  default     = ""
}

variable "api_gateway_url" {
  description = "API Gateway URL for frontend to call (for environment variables)"
  type        = string
}

variable "price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_100" # Use only North America and Europe
}
