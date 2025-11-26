terraform {
  backend "s3" {
    bucket = "kloudnat-infra-shared-store"
    key    = "kambriq/shared/terraform.tfstate"
    region = "eu-central-1"
    # Optionnel: activer le versioning et le chiffrement
    # dynamodb_table = "terraform-state-lock"
    # encrypt        = true
  }
}

