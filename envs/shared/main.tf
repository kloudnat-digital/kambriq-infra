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

# D16. This was one statement, `Action: *` on `Resource: *` - an administrator
# in fact, not something limited to Terraform and this estate. The enumeration
# below is derived from the two states, not invented: 134 addresses in dev and
# 33 in shared, across ec2, ecs, ecr, elbv2, rds, elasticache, s3, ssm, iam,
# kms, logs, cloudwatch, sns, cloudtrail, sesv2 and route53.
#
# Enumerated BY SERVICE rather than by action. An action-level list would be
# longer, look stricter, and break the first apply that needed the one verb
# nobody thought of - and an apply that fails half way is worse than an apply
# role that is wider than the minimum. What this removes is everything else in
# the account: no organizations, no sso/identitystore, no eks, no lambda, no
# cloudfront, no dynamodb, no iam on principals outside this project. This
# account also runs fotomena's EKS clusters and argocd; the apply role could
# delete them this morning and cannot after this lands.
#
# WHAT IT STILL ALLOWS, said plainly: iam on kambriq-* principals means this
# role can write its own policies and those of the ECS task roles, so a person
# who can reach it can still escalate within the project. Narrowing that needs a
# permissions boundary, which is a separate decision.
data "aws_iam_policy_document" "github_actions_infra_permissions" {
  statement {
    sid = "TheEstateByService"
    actions = [
      "acm:*",
      "cloudtrail:*",
      "cloudwatch:*",
      "ec2:*",
      "ecr:*",
      "ecs:*",
      "elasticache:*",
      "elasticloadbalancing:*",
      "logs:*",
      "rds:*",
      "route53:*",
      # `ses`, not `sesv2`. The SESv2 API authorises against the `ses` prefix;
      # `sesv2:` is not a service IAM knows, and an unknown prefix is not an
      # error - it is a silent deny that grants nothing. Access Analyzer calls
      # it INVALID_SERVICE_IN_ACTION (severity ERROR). This estate manages
      # aws_sesv2_contact_list in envs/shared/ses-newsletter.tf, so the refresh
      # of a shared plan needs it.
      "ses:*",
      "sns:*",
      "tag:*",
    ]
    resources = ["*"]
  }

  statement {
    sid = "ReadAnyPrincipalPlansAndPolicyDocumentsNeed"
    actions = [
      "iam:Get*",
      "iam:List*",
      "iam:SimulatePrincipalPolicy",
      "sts:GetCallerIdentity",
    ]
    resources = ["*"]
  }

  # The project's own principals: five task and CI roles, their policies, the
  # OIDC provider, and the kambriq-app-dev user the media policy attaches to.
  statement {
    sid = "ManageThisProjectsPrincipals"
    actions = [
      "iam:*",
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/kambriq-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/kambriq-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/kambriq-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:instance-profile/kambriq-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com",
    ]
  }

  # ECS cannot register a task definition without passing the task roles.
  statement {
    sid       = "PassTheTaskRoles"
    actions   = ["iam:PassRole"]
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/kambriq-*"]
  }

  # Every parameter this project owns, and none of anybody else's.
  statement {
    sid       = "TheProjectParameters"
    actions   = ["ssm:*"]
    resources = ["arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/kambriq/*"]
  }

  # Some actions take no resource AT ALL: IAM evaluates them only against "*",
  # so naming them inside a resource-scoped statement grants nothing, however
  # plainly the statement lists them. `ssm:*` above therefore does not carry
  # ssm:DescribeParameters, and the provider calls it on every
  # aws_ssm_parameter refresh - 3442 CloudTrail events from this role over 90
  # days include it, 50 of them in the last apply alone. Which actions are in
  # this class is a fact of the Service Authorization Reference, not a judgement:
  # DescribeParameters' resource-type column is empty.
  statement {
    sid = "TheSsmReadThatTakesNoResource"
    actions = [
      "ssm:DescribeParameters",
    ]
    resources = ["*"]
  }

  # The project's buckets, plus the state bucket's kambriq/ prefix. Not the
  # bucket's other tenants: the three legacy states and the shared/ prefix are
  # deliberately outside this.
  statement {
    sid     = "TheProjectBuckets"
    actions = ["s3:*"]
    resources = [
      "arn:aws:s3:::kambriq-*",
      "arn:aws:s3:::kambriq-*/*",
      "arn:aws:s3:::kloudnat-infra-shared-store",
      "arn:aws:s3:::kloudnat-infra-shared-store/kambriq/*",
    ]
  }

  # D14a's account-level public access block is account-scoped, so it cannot be
  # written against a bucket ARN.
  statement {
    sid = "AccountPublicAccessBlock"
    actions = [
      "s3:GetAccountPublicAccessBlock",
      "s3:PutAccountPublicAccessBlock",
    ]
    resources = ["*"]
  }

  # D21's state key: creating it, managing it, and using it through S3.
  statement {
    sid = "TheStateKey"
    actions = [
      "kms:CancelKeyDeletion",
      "kms:CreateAlias",
      "kms:CreateKey",
      "kms:Decrypt",
      "kms:DeleteAlias",
      "kms:Describe*",
      "kms:DisableKeyRotation",
      "kms:EnableKeyRotation",
      "kms:GenerateDataKey",
      "kms:Get*",
      "kms:List*",
      "kms:PutKeyPolicy",
      "kms:ScheduleKeyDeletion",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:UpdateAlias",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "github_actions_infra" {
  name   = "${var.project_name}-infra-github-actions"
  role   = aws_iam_role.github_actions_infra.id
  policy = data.aws_iam_policy_document.github_actions_infra_permissions.json
}
