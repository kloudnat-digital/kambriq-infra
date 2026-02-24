variable "env" {
  description = "Environment name (dev, prd)"
  type        = string
}

variable "bucket_name" {
  description = "S3 bucket name for media (will be prefixed with env if not provided)"
  type        = string
  default     = ""
}

