terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # Every prod resource is born Environment=prod, by construction. The wired
  # convention check refuses a resource that is born wrong, so this default is
  # what keeps prod on the right side of that gate from its first apply.
  default_tags {
    tags = {
      Environment = "prod"
    }
  }
}
