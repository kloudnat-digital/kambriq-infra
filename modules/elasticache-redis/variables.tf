variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "env" {
  description = "Environment name (dev, prd)"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for ElastiCache subnet group"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group IDs for Redis"
  type        = list(string)
}

variable "node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t4g.micro"
}

variable "engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.1"
}

variable "port" {
  description = "Redis port"
  type        = number
  default     = 6379
}

variable "auth_token" {
  description = "Optional AUTH token for Redis (required when transit encryption is enabled)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "transit_encryption_enabled" {
  description = "Enable in-transit encryption"
  type        = bool
  default     = false
}

variable "at_rest_encryption_enabled" {
  description = "Enable at-rest encryption"
  type        = bool
  default     = true
}
