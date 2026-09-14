project_name = "kambriq"
env          = "prod"
aws_region   = "eu-central-1"
github_repo  = "kloudnat-digital/kambriq-webapp"

shared_state_bucket = "kloudnat-infra-shared-store"
shared_state_key    = "kambriq/envs/shared/terraform.tfstate"
shared_state_region = "eu-central-1"

ses_from_email = "noreply@kambriq.com"

# PREREQUISITE: a prod ACM certificate for kambriq.com (+ www) in eu-central-1.
# None exists yet (only dev.kambriq.com). Empty here makes the ALB serve HTTP
# only, which is a launch blocker, not a plan blocker - the plan is complete and
# the listener flips to HTTPS the moment this ARN is filled and applied.
api_acm_certificate_arn = ""

api_port              = 3000
api_prefix            = "api/v1"
api_health_check_path = "/api/v1/health/ready"
api_cpu               = 256
api_memory            = 512
api_desired_count     = 1

web_port              = 3000
web_health_check_path = "/health"
web_cpu               = 512
web_memory            = 1024
web_desired_count     = 1

db_core_name   = "kambriq_core"
db_kbs_name    = "kambriq_kbs"
db_kamnet_name = "kambriq_kamnet"
db_lands_name  = "kambriq_lands"
db_extra       = {}
db_username    = "kambriq_admin"

# Lean prod profile (chosen 13 Sep): micro, single-AZ, but with the production
# safeguards dev never had - 7-day backups, a final snapshot, deletion protection.
rds_instance_class          = "db.t4g.micro"
rds_allocated_storage       = 20
rds_storage_type            = "gp3"
rds_backup_retention_period = 7
rds_skip_final_snapshot     = false
rds_enable_cloudwatch_logs  = true
rds_multi_az                = false
rds_deletion_protection     = true

redis_node_type                  = "cache.t4g.micro"
redis_engine_version             = "7.1"
redis_port                       = 6379
redis_auth_token                 = ""
redis_transit_encryption_enabled = false

s3_media_bucket_name = ""
cors_origins         = "https://kambriq.com"
frontend_url         = "https://kambriq.com"
node_env             = "production"

jwt_access_expiration   = "15m"
jwt_refresh_expiration  = "15d"
throttle_ttl            = 60000
throttle_limit          = 100
email_from_name         = "KAMBRIQ"
salt_rounds             = 12
jwt_secret              = ""
use_existing_jwt_secret = false

# Shared ECR repos (chosen 13 Sep): prod pulls the promoted image by a prod tag.
api_image_tag = "prod-latest"
web_image_tag = "prod-latest"

ecr_api_repo_name  = "kambriq-api"
ecr_web_repo_name  = "kambriq-web"
enable_web_service = true

enable_container_insights = true
enable_ecs_exec           = false
