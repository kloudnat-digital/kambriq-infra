project_name = "kambriq"
env          = "prd"
aws_region   = "eu-central-1"
github_repo  = "kloudnat-digital/kambriq-webapp"

shared_state_bucket = "kloudnat-infra-shared-store"
shared_state_key    = "kambriq/envs/shared/terraform.tfstate"
shared_state_region = "eu-central-1"

ses_from_email          = "noreply@kambriq.com"
api_acm_certificate_arn = "arn:aws:acm:eu-central-1:ACCOUNT:certificate/XXXXXXXX"

api_port              = 3000
api_prefix            = "api/v1"
api_health_check_path = "/api/v1/health/ready"
api_cpu               = 512
api_memory            = 1024
api_desired_count     = 2

web_port              = 3000
web_health_check_path = "/health"
web_cpu               = 512
web_memory            = 1024
web_desired_count     = 2

db_core_name   = "kambriq_core"
db_kbs_name    = "kambriq_kbs"
db_kamnet_name = "kambriq_kamnet"
db_lands_name  = "kambriq_lands"
db_extra       = {}
db_username    = "kambriq_admin"
db_password    = "CHANGE_ME"

rds_instance_class          = "db.t4g.small"
rds_allocated_storage       = 50
rds_storage_type            = "gp3"
rds_backup_retention_period = 5
rds_skip_final_snapshot     = false

redis_node_type                  = "cache.t4g.small"
redis_engine_version             = "7.1"
redis_port                       = 6379
redis_auth_token                 = ""
redis_transit_encryption_enabled = true

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

api_image_tag = "latest"
web_image_tag = "latest"

ecr_api_repo_name  = "kambriq-api"
ecr_web_repo_name  = "kambriq-web"
enable_web_service = true

bastion_key_name          = "bastion_key_pair"
bastion_allowed_ssh_cidrs = ["90.25.230.44/32"]
bastion_instance_type     = "t3.micro"
