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

# D20. Enabling TLS on an EXISTING cluster is a two-step change, and AWS says so
# in as many words: "Enabling encryption in transit, is a two-step process, you
# must first set the transit encryption mode to `preferred`. This mode allows
# your clients to connect using both encrypted and unencrypted connections.
# After you migrate all your clients to use encrypted connections, you can then
# modify your cluster configuration to set the transit encryption mode to
# `required`."
#
# `preferred` is therefore the window in which the application is deployed with
# TLS, and `required` is the second apply that closes it. The provider carries
# the same rule: "When enabling encryption on an existing replication group,
# this must first be set to `preferred` before setting it to `required` in a
# subsequent apply."
variable "transit_encryption_mode" {
  description = "preferred (accepts both) or required (TLS only). Must be preferred before required on an existing cluster."
  type        = string
  default     = null

  validation {
    condition     = var.transit_encryption_mode == null || contains(["preferred", "required"], coalesce(var.transit_encryption_mode, "preferred"))
    error_message = "transit_encryption_mode must be preferred or required."
  }
}

# D20. Adding a token to a cluster that has none is also two steps: ROTATE makes
# the token optional (the cluster accepts authenticated AND unauthenticated
# connections), SET makes it required. AWS: "If no AUTH token was configured on
# the replication group before the AUTH token rotation, the cluster supports the
# AUTH token specified in the --auth-token parameter in addition to supporting
# connecting without authentication."
#
# So ROTATE with the cluster in `preferred` is the safe first apply, and
# SET with `required` is the one that actually closes the door.
variable "auth_token_update_strategy" {
  description = "ROTATE (token optional, both accepted) or SET (token required). ROTATE first on a cluster that had none."
  type        = string
  default     = "ROTATE"

  validation {
    condition     = contains(["ROTATE", "SET"], var.auth_token_update_strategy)
    error_message = "auth_token_update_strategy must be ROTATE or SET. DELETE is deliberately not offered: removing the token is a decision, not a default."
  }
}

variable "at_rest_encryption_enabled" {
  description = "Enable at-rest encryption"
  type        = bool
  default     = true
}
