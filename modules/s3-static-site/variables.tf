variable "env" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "bucket_name" {
  description = "S3 bucket name for static site (will be prefixed with env if not provided)"
  type        = string
  default     = ""
}


