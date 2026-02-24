terraform {
  backend "s3" {
    bucket = "kloudnat-infra-shared-store"
    key    = "kambriq/envs/shared/terraform.tfstate"
    region = "eu-central-1"
  }
}
