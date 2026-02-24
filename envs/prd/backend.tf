terraform {
  backend "s3" {
    bucket = "kloudnat-infra-shared-store"
    key    = "kambriq/envs/prd/terraform.tfstate"
    region = "eu-central-1"
  }
}
