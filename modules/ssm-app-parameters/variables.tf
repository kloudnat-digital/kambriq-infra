variable "env" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "db_host" {
  description = "Database host (RDS endpoint)"
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
  description = "Database password (from SSM /kambriq/{env}/db/password)"
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "JWT secret key. If empty, will try to read from existing SSM parameter /kambriq/{env}/api/jwt_secret"
  type        = string
  sensitive   = true
  default     = ""
}

variable "frontend_url" {
  description = "Frontend URL (CloudFront URL or custom domain)"
  type        = string
}

variable "ses_from_email" {
  description = "SES sender email address"
  type        = string
}
