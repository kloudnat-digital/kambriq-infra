variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "env" {
  description = "Environment name (dev, prd)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for ALB"
  type        = list(string)
}

variable "certificate_arn" {
  description = "ACM Certificate ARN for HTTPS listener (optional, if null, HTTP only)"
  type        = string
  default     = null
}

variable "api_port" {
  description = "Port for NestJS API target group"
  type        = number
  default     = 3000
}

variable "web_port" {
  description = "Port for Next.js target group"
  type        = number
  default     = 3000
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for ALB"
  type        = bool
  default     = false
}

variable "access_logs_bucket" {
  description = "S3 bucket name for ALB access logs. Leave empty to disable."
  type        = string
  default     = ""
}

variable "redirect_www_to_apex_host" {
  description = "Apex host (e.g. dev.kambriq.com). When non-empty and certificate_arn is set, www.<host> is 301-redirected to <host> on both HTTP and HTTPS listeners. Leave empty to disable."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# D13 - authenticate the WEB paths at the load balancer.
#
# All three must be non-empty for the gate to be created; any one empty leaves
# the listener exactly as it is today. That is deliberate: a half-configured
# gate must not half-apply, and `envs/prd` must be able to take this module
# without inheriting a gate nobody decided on.
#
# `authenticate-cognito` is supported only on an HTTPS listener (AWS), so the
# gate is created only when `certificate_arn` is also set.
# ---------------------------------------------------------------------------
# The switch is a plain bool, and it has to be: `count` cannot depend on a value
# that is unknown until apply, and the pool ARN below is exactly that when it is
# sourced from the Cognito resources rather than written as a literal. Testing
# the ARN for emptiness failed with "Invalid count argument" for that reason.
variable "web_auth_enabled" {
  description = "D13: create the Cognito gate on the web paths. Requires certificate_arn and the three user pool values."
  type        = bool
  default     = false
}

variable "web_auth_user_pool_arn" {
  description = "D13: Cognito user pool ARN for authenticating the web paths."
  type        = string
  default     = ""
}

variable "web_auth_user_pool_client_id" {
  description = "D13: Cognito app client id (must generate a secret and use the code grant flow)."
  type        = string
  default     = ""
}

variable "web_auth_user_pool_domain" {
  description = "D13: Cognito hosted domain prefix the ALB redirects to."
  type        = string
  default     = ""
}

variable "web_auth_exempt_paths" {
  description = "D13: paths forwarded WITHOUT authentication. Every machine caller of dev reaches it through one of these."
  type        = list(string)
  default     = ["/health"]
}

variable "web_auth_session_timeout" {
  description = "D13: how long an authenticated session lasts, in seconds. 12 hours - a working day, then log in again."
  type        = number
  default     = 43200
}

