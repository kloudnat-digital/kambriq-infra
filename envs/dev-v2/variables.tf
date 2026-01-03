variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "db_username" {
  description = "RDS master username"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "RDS master password"
  type        = string
  sensitive   = true
}

# Note: cloudfront_certificate_arn est déclaré dans main.tf (ligne 167)
# pour éviter la duplication, elle n'est pas redéclarée ici
