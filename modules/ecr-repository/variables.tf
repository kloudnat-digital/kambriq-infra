variable "repository_name" {
  description = "Name of the ECR repository"
  type        = string
}

variable "env" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "image_tag_mutability" {
  description = "Image tag mutability (MUTABLE or IMMUTABLE)"
  type        = string
  default     = "MUTABLE"
}

variable "scan_on_push" {
  description = "Enable image scanning on push"
  type        = bool
  default     = true
}

variable "encryption_type" {
  description = "Encryption type (AES256 or KMS)"
  type        = string
  default     = "AES256"
}

variable "kms_key_id" {
  description = "KMS key ID for encryption (optional, only if encryption_type = KMS)"
  type        = string
  default     = ""
}

variable "image_retention_count" {
  description = "Number of images to retain (oldest will be deleted)"
  type        = number
  default     = 10
}

variable "aws_region" {
  description = "AWS region for ECR repository"
  type        = string
}
