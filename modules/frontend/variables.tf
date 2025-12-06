variable "env" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "kambriq"
}

variable "artifact_bucket_name" {
  description = "S3 bucket name where OpenNext artifacts are stored (e.g., kambriq-artifacts-dev). Note: OpenNext bundle must be extracted before use."
  type        = string
  default     = ""
}

variable "ssr_bundle_s3_key" {
  description = "S3 key of the OpenNext SSR bundle ZIP (e.g., web/web-abc123.zip). Note: This bundle contains .open-next/ and must be extracted. Lambda functions are in .open-next/server/."
  type        = string
  default     = ""
}

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
