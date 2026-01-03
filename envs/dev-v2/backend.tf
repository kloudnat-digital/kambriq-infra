terraform {
  backend "s3" {
    bucket = "kloudnat-infra-shared-store"
    key    = "kambriq/dev-v2/terraform.tfstate"
    region = "eu-central-1"
  }
}

