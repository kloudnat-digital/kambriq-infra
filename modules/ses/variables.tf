variable "env" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "domain" {
  description = "Domain name for SES (e.g., kambriq.com)"
  type        = string
  default     = "kambriq.com"
}

variable "from_email" {
  description = "Default sender email address"
  type        = string
  default     = "noreply@kambriq.com"
}

