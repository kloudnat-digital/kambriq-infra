variable "env" {
  description = "Environment name (dev, prd)"
  type        = string
}

variable "project_name" {
  description = "Project name (used in tags)"
  type        = string
  default     = "kambriq"
}

variable "bucket_name" {
  description = "S3 bucket name. If empty, defaults to kambriq-media-{env}"
  type        = string
  default     = ""
}

variable "versioning_enabled" {
  description = "Enable S3 versioning. dev=false, prd=true. Note: S3 cannot return to Disabled once Enabled — off state is Suspended."
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
variable "tmp_prefix" {
  description = "Object key prefix for temporary uploads (auto-expire)"
  type        = string
  default     = "uploads/tmp/"
}

variable "tmp_expiration_days" {
  description = "Days after which objects under tmp_prefix are deleted"
  type        = number
  default     = 1
}

variable "lands_prefix" {
  description = "Object key prefix for land assets (transition to IA)"
  type        = string
  default     = "lands/"
}

variable "lands_ia_transition_days" {
  description = "Days after which lands/* objects move to STANDARD_IA"
  type        = number
  default     = 90
}

# ---------------------------------------------------------------------------
# CORS
# ---------------------------------------------------------------------------
variable "cors_allowed_methods" {
  description = "Allowed HTTP methods for CORS"
  type        = list(string)
  default     = ["GET", "PUT", "POST", "HEAD"]
}

variable "cors_allowed_origins" {
  description = "Allowed origins for CORS (full scheme + host)"
  type        = list(string)
  default = [
    "https://dev.kambriq.com",
    "http://localhost:3000",
    "http://localhost:3001",
  ]
}

variable "cors_allowed_headers" {
  description = "Allowed headers for CORS"
  type        = list(string)
  default     = ["*"]
}

variable "cors_expose_headers" {
  description = "Headers exposed to the browser"
  type        = list(string)
  default     = ["ETag"]
}

variable "cors_max_age_seconds" {
  description = "Browser preflight cache TTL"
  type        = number
  default     = 3000
}

# ---------------------------------------------------------------------------
# Tags
# ---------------------------------------------------------------------------
variable "extra_tags" {
  description = "Extra tags merged onto the bucket"
  type        = map(string)
  default     = {}
}
