terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # Every resource this provider creates carries its environment, so the
  # convention holds by construction rather than by remembering to add a tag
  # on each new resource. A resource that sets Environment itself still wins;
  # this only fills the gap. `assert-environment-convention.sh` is the check
  # that this default is actually reaching everything.
  default_tags {
    tags = {
      Environment = "shared"
    }
  }
}

module "shared" {
  source = "../../modules/shared"

  project_name                   = var.project_name
  aws_region                     = var.aws_region
  vpc_cidr                       = var.vpc_cidr
  availability_zones             = var.availability_zones
  nat_per_az                     = var.nat_per_az
  enable_nat_gateway             = var.enable_nat_gateway
  domain_name                    = var.domain_name
  route53_zone_id                = var.route53_zone_id
  enable_route53_lookup          = var.enable_route53_lookup
  ses_domain                     = var.ses_domain
  ses_from_email                 = var.ses_from_email
  ses_domain_identity_arn        = var.ses_domain_identity_arn
  api_acm_certificate_arn        = var.api_acm_certificate_arn
  cloudfront_acm_certificate_arn = var.cloudfront_acm_certificate_arn
  enable_s3_logs                 = var.enable_s3_logs
  enable_s3_artifacts            = var.enable_s3_artifacts
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = {
    Name = "${var.project_name}-github-oidc"
    Type = "shared"
  }
}

data "aws_iam_policy_document" "github_actions_infra_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_repo_infra}:environment:shared",
        "repo:${var.github_repo_infra}:environment:dev",
        # D2. Without this a Plan (prd) job (it runs under the prd GitHub Environment) is
        # refused at sts:AssumeRoleWithWebIdentity, so the production plan the chain now
        # schedules cannot authenticate. The detector making the job appear and this
        # making it able to run are the two halves of teaching the pipeline about prd.
        "repo:${var.github_repo_infra}:environment:prd",
      ]
    }
  }
}

resource "aws_iam_role" "github_actions_infra" {
  name               = "${var.project_name}-infra-github-actions"
  assume_role_policy = data.aws_iam_policy_document.github_actions_infra_assume_role.json

  tags = {
    Name = "${var.project_name}-infra-github-actions"
    Type = "shared"
  }
}

data "aws_iam_policy_document" "github_actions_infra_permissions" {
  statement {
    sid       = "TerraformAdmin"
    actions   = ["*"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "github_actions_infra" {
  name   = "${var.project_name}-infra-github-actions"
  role   = aws_iam_role.github_actions_infra.id
  policy = data.aws_iam_policy_document.github_actions_infra_permissions.json
}
