variable "project_name" {
  description = "Project name prefix"
  type        = string
  default     = "kambriq"
}

variable "env" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "github_repo" {
  description = "GitHub org/repo for Actions OIDC (e.g. org/repo)"
  type        = string
}

variable "shared_state_bucket" {
  description = "S3 bucket for shared remote state"
  type        = string
  default     = "kloudnat-infra-shared-store"
}

variable "shared_state_key" {
  description = "S3 key for shared remote state"
  type        = string
  default     = "kambriq/envs/shared/terraform.tfstate"
}

variable "shared_state_region" {
  description = "S3 region for shared remote state"
  type        = string
  default     = "eu-central-1"
}

variable "ses_from_email" {
  description = "SES from email"
  type        = string
  default     = "noreply@kambriq.com"
}

variable "api_acm_certificate_arn" {
  description = "ACM cert ARN for ALB (eu-central-1)"
  type        = string
  default     = ""
}



variable "api_port" {
  description = "API container port"
  type        = number
  default     = 3000
}

variable "api_prefix" {
  description = "API global prefix"
  type        = string
  default     = "api/v1"
}

variable "api_health_check_path" {
  description = "API health check path"
  type        = string
  default     = "/api/v1/health/ready"
}

variable "api_cpu" {
  description = "API task CPU"
  type        = number
  default     = 512
}

variable "api_memory" {
  description = "API task memory"
  type        = number
  default     = 1024
}

variable "api_desired_count" {
  description = "API desired task count"
  type        = number
  default     = 1
}

variable "web_port" {
  description = "Web container port"
  type        = number
  default     = 3000
}

variable "web_health_check_path" {
  description = "Web health check path"
  type        = string
  default     = "/health"
}

variable "web_cpu" {
  description = "Web task CPU"
  type        = number
  default     = 512
}

variable "web_memory" {
  description = "Web task memory"
  type        = number
  default     = 1024
}

variable "web_desired_count" {
  description = "Web desired task count"
  type        = number
  default     = 1
}

variable "db_core_name" {
  description = "Core database name"
  type        = string
  default     = "kambriq_core"
}

variable "db_kbs_name" {
  description = "KBS database name"
  type        = string
  default     = "kambriq_kbs"
}

variable "db_kamnet_name" {
  description = "Kamnet database name"
  type        = string
  default     = "kambriq_kamnet"
}

variable "db_lands_name" {
  description = "Lands database name"
  type        = string
  default     = "kambriq_lands"
}

variable "db_extra" {
  description = "Additional DBs: map of suffix -> database name"
  type        = map(string)
  default     = {}
}

variable "db_username" {
  description = "DB master username"
  type        = string
  default     = "kambriq_admin"
}

variable "db_password" {
  description = "DB master password"
  type        = string
  sensitive   = true
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "rds_allocated_storage" {
  description = "RDS storage (GB)"
  type        = number
  default     = 20
}

variable "rds_storage_type" {
  description = "RDS storage type"
  type        = string
  default     = "gp3"
}

variable "rds_backup_retention_period" {
  description = "RDS backup retention (days)"
  type        = number
  default     = 7
}

variable "rds_skip_final_snapshot" {
  description = "Skip final snapshot on destroy"
  type        = bool
  default     = true
}

variable "redis_node_type" {
  description = "Redis node type"
  type        = string
  default     = "cache.t4g.micro"
}

variable "redis_engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.1"
}

variable "redis_port" {
  description = "Redis port"
  type        = number
  default     = 6379
}

variable "redis_auth_token" {
  description = "Redis AUTH token (optional)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "redis_transit_encryption_enabled" {
  description = "Enable Redis in-transit encryption"
  type        = bool
  default     = false
}

variable "s3_media_bucket_name" {
  description = "S3 bucket name for uploads (optional)"
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# S3 media bucket — lifecycle, versioning, CORS
# ---------------------------------------------------------------------------
variable "s3_media_versioning_enabled" {
  description = "Enable versioning on the media bucket. Dev defaults to false (Suspended)."
  type        = bool
  default     = false
}

variable "s3_media_tmp_prefix" {
  description = "Object key prefix for temporary uploads (auto-expire)"
  type        = string
  default     = "uploads/tmp/"
}

variable "s3_media_tmp_expiration_days" {
  description = "Days after which uploads/tmp/* objects are deleted"
  type        = number
  default     = 1
}

variable "s3_media_lands_prefix" {
  description = "Object key prefix for land assets (transition to STANDARD_IA)"
  type        = string
  default     = "lands/"
}

variable "s3_media_lands_ia_transition_days" {
  description = "Days after which lands/* objects move to STANDARD_IA"
  type        = number
  default     = 90
}

variable "s3_media_cors_allowed_methods" {
  description = "HTTP methods allowed by S3 CORS"
  type        = list(string)
  default     = ["GET", "PUT", "POST", "HEAD"]
}

variable "s3_media_cors_allowed_origins" {
  description = "Origins allowed by S3 CORS"
  type        = list(string)
  default = [
    "https://dev.kambriq.com",
    "http://localhost:3000",
    "http://localhost:3001",
  ]
}

# ---------------------------------------------------------------------------
# S3 runtime config injected into the API ECS task
# ---------------------------------------------------------------------------
variable "s3_presigned_url_ttl_seconds" {
  description = "TTL (seconds) for presigned upload/download URLs"
  type        = number
  default     = 900
}

variable "s3_max_upload_size_mb" {
  description = "Max single-object upload size, MB (validated at API layer)"
  type        = number
  default     = 100
}

# ---------------------------------------------------------------------------
# Pre-existing IAM user receiving developer access to the media bucket
# ---------------------------------------------------------------------------
variable "media_developer_user_name" {
  description = "Existing IAM user name to grant developer access to the media bucket"
  type        = string
  default     = "kambriq-app-dev"
}

variable "cors_origins" {
  description = "CORS origins"
  type        = string
  default     = ""
}

variable "frontend_url" {
  description = "Frontend URL for email links"
  type        = string
  default     = ""
}

variable "node_env" {
  description = "Runtime NODE_ENV"
  type        = string
  default     = "dev"
}

variable "jwt_access_expiration" {
  description = "JWT access token lifetime"
  type        = string
  default     = "15m"
}

variable "jwt_refresh_expiration" {
  description = "JWT refresh token lifetime"
  type        = string
  default     = "15d"
}

variable "throttle_ttl" {
  description = "Rate limit window in ms"
  type        = number
  default     = 60000
}

variable "throttle_limit" {
  description = "Max requests per window"
  type        = number
  default     = 100
}

variable "email_from_name" {
  description = "Sender display name"
  type        = string
  default     = "KAMBRIQ"
}

variable "salt_rounds" {
  description = "bcrypt salt rounds"
  type        = number
  default     = 12
}

variable "jwt_secret" {
  description = "JWT secret (optional; placeholder if not set)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "use_existing_jwt_secret" {
  description = "Read existing legacy jwt_secret parameter when jwt_secret is empty"
  type        = bool
  default     = false
}

variable "api_image_tag" {
  description = "API image tag"
  type        = string
  default     = "latest"
}

variable "web_image_tag" {
  description = "Web image tag"
  type        = string
  default     = "latest"
}

variable "ecr_api_repo_name" {
  description = "ECR repo name for API"
  type        = string
  default     = "kambriq-api"
}

variable "ecr_web_repo_name" {
  description = "ECR repo name for Web"
  type        = string
  default     = "kambriq-web"
}

variable "enable_web_service" {
  description = "Enable ECS service for web"
  type        = bool
  default     = false
}

variable "rds_enable_cloudwatch_logs" {
  description = "Export RDS logs to CloudWatch"
  type        = bool
  default     = false
}

variable "enable_container_insights" {
  description = "Enable ECS Container Insights. Off in dev: it bills per task continuously and troubleshooting goes through CloudWatch Logs and ALB target health."
  type        = bool
  default     = false
}

variable "enable_ecs_exec" {
  description = "Enable ECS Exec on the services and grant the task roles the ssmmessages permissions it requires. Replaces the bastion as the way into the private subnets."
  type        = bool
  default     = false
}

variable "payment_validity_days" {
  description = "How long a payment stays valid once created, in days (G9). A business choice, not a specification - see docs/ops/registre-chantiers.md."
  type        = number
  default     = 30
}
