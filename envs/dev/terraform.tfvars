project_name = "kambriq"
env          = "dev"
aws_region   = "eu-central-1"
github_repo  = "kloudnat-digital/kambriq-webapp"

shared_state_bucket = "kloudnat-infra-shared-store"
shared_state_key    = "kambriq/envs/shared/terraform.tfstate"
shared_state_region = "eu-central-1"

ses_from_email          = "noreply@kambriq.com"
api_acm_certificate_arn = "arn:aws:acm:eu-central-1:051551940370:certificate/6f8bbf35-3058-4083-a8dd-f393d5012300"

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

rds_instance_class          = "db.t4g.micro"
rds_allocated_storage       = 20
rds_storage_type            = "gp3"
rds_backup_retention_period = 0
rds_skip_final_snapshot     = true
rds_enable_cloudwatch_logs  = false

redis_node_type                  = "cache.t4g.micro"
redis_engine_version             = "7.1"
redis_port                       = 6379
redis_auth_token                 = ""
redis_transit_encryption_enabled = false

s3_media_bucket_name = ""
cors_origins         = "https://dev.kambriq.com"
frontend_url         = "https://dev.kambriq.com"
node_env             = "development"

jwt_access_expiration   = "15m"
jwt_refresh_expiration  = "15d"
throttle_ttl            = 60000
throttle_limit          = 100
email_from_name         = "KAMBRIQ"
salt_rounds             = 12
jwt_secret              = ""
use_existing_jwt_secret = false

api_image_tag = "latest"
web_image_tag = "latest"

ecr_api_repo_name  = "kambriq-api"
ecr_web_repo_name  = "kambriq-web"
enable_web_service = true

enable_container_insights = false
enable_ecs_exec           = true
