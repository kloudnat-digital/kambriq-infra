aws_region = "eu-central-1"
env        = "prd"
github_repo = "kloudnat-digital/kambriq-api"

shared_state_bucket = "kloudnat-infra-shared-store"
shared_state_key    = "kambriq/envs/shared/terraform.tfstate"
shared_state_region = "eu-central-1"

api_acm_certificate_arn = "arn:aws:acm:eu-central-1:ACCOUNT:certificate/XXXXXXXX"

ses_from_email = "noreply@kambriq.com"

db_password = "CHANGE_ME"

cors_origins = "https://kambriq.com"
frontend_url = "https://kambriq.com"

node_env = "production"

api_cpu           = 512
api_memory        = 1024
api_desired_count = 2

web_cpu           = 512
web_memory        = 1024
web_desired_count = 2

throttle_ttl   = 60000
throttle_limit = 100

ecr_api_repo_name = "kambriq-api"
ecr_web_repo_name = "kambriq-web"
