terraform {
  backend "s3" {
    bucket = "kloudnat-infra-shared-store"
    key    = "kambriq/envs/dev/terraform.tfstate"
    region = "eu-central-1"
  }
}
