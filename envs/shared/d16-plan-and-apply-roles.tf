# ---------------------------------------------------------------------------
# D16 - the plan role and the apply role are not the same role.
#
# WHAT WAS ESTABLISHED, on the real configuration and the real claim.
#
#   1. terraform-apply.yml is a workflow_dispatch. It can be launched from ANY
#      ref, and neither the dev nor the shared nor the prd environment carries a
#      protection rule or a deployment branch policy (`gh api
#      repos/.../environments` -> "protection_rules": [] for all three).
#      Branch protection on develop guards what enters develop - required check
#      "CI Gate", strict=false, reviews=0, enforce_admins=false - and guards
#      nothing about what changes AWS.
#
#   2. Plan and apply share ONE role and THE SAME `sub` claim. Both workflows
#      declare `environment: <env>` and read `secrets.AWS_ROLE_ARN`, which is an
#      environment secret present in dev, shared and prd. The role's trust
#      policy accepts exactly two subs:
#        repo:kloudnat-digital/kambriq-infra:environment:shared
#        repo:kloudnat-digital/kambriq-infra:environment:dev
#      so a pull-request plan and a dispatched apply present the same claim and
#      receive the same credentials.
#
#   3. No claim on this token can carry a branch restriction to AWS. The repo
#      uses the DEFAULT subject format (`use_default: true`, verified through
#      the API), and as soon as a job declares an environment the `sub` loses
#      the ref. IAM cannot read the `ref` claim.
#
# VISQUIS'S DECISION, 14 September: separate plan from apply first. This file is
# that separation. The choice of enforcement afterwards - an OIDC subject format
# including ref, or a deployment branch policy on the apply environments - is
# his, and both become possible only once the two roles are distinct.
#
# HOW THE SPLIT IS ENFORCED, and why not by a second secret name.
# A second secret (AWS_PLAN_ROLE_ARN) in the same environments would give the
# plan job a different ARN, but the TRUST POLICY could not tell the two apart:
# any job declaring `environment: dev` would satisfy both roles' conditions. So
# the plan workflow declares its own environments, `dev-plan` and `shared-plan`,
# and this role trusts only those subs. The apply role keeps `dev`/`shared`.
# Those two environments and their AWS_ROLE_ARN secret are a GitHub settings
# change, listed in the pull request; this file is the AWS half.
#
# WHAT A PLAN ACTUALLY NEEDS - read from the two states, not assumed.
#   - Describe/List/Get on the resource types in state: ec2, ecs, ecr, elbv2,
#     rds, elasticache, s3, ssm, iam, logs, cloudwatch, sns, cloudtrail,
#     route53, acm, sesv2, kms (134 addresses in dev, 33 in shared).
#   - s3:GetObject on its own state object AND on kambriq/envs/shared (envs/dev
#     reads it through data.terraform_remote_state.shared), plus kms:Decrypt
#     once D21's key encrypts them.
#   - NO lock permission. The brief expects a lock table; there is none. Neither
#     backend block sets `dynamodb_table` or `use_lockfile`, the account has no
#     DynamoDB table at all, and terraform-plan.yml says so in its own comment:
#     "Safe to cancel BECAUSE it is terraform plan: it acquires no state lock".
#     Nothing locks these states today - not the plan, and not the apply either,
#     which is a separate defect worth its own entry. If `use_lockfile` is ever
#     turned on, the plan role needs s3:PutObject and s3:DeleteObject on
#     `<key>.tflock` and this policy must gain them.
#
# READ POWER IS NOT REDUCED, and saying otherwise would be false. A plan
# refreshes 57 aws_ssm_parameter resources, which reads their values: the plan
# role can read every /kambriq/dev/* SecureString, including JWT_SECRET and the
# four DATABASE_URLs. The split removes the power to CHANGE the estate. It does
# not make the credential harmless, and a leaked plan credential is still a
# leaked set of application secrets.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "github_actions_infra_plan_assume_role" {
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

    # The plan environments, and only those. The apply role's own trust policy
    # keeps `:environment:shared` and `:environment:dev`, so the two roles are
    # distinguished by the claim itself rather than by which secret a workflow
    # happens to read.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_repo_infra}:environment:shared-plan",
        "repo:${var.github_repo_infra}:environment:dev-plan",
      ]
    }
  }
}

resource "aws_iam_role" "github_actions_infra_plan" {
  name               = "${var.project_name}-infra-github-actions-plan"
  description        = "terraform plan only: reads the estate and the state, changes nothing (D16)"
  assume_role_policy = data.aws_iam_policy_document.github_actions_infra_plan_assume_role.json

  tags = {
    Name = "${var.project_name}-infra-github-actions-plan"
    Type = "shared"
  }
}

data "aws_iam_policy_document" "github_actions_infra_plan_permissions" {
  # The refresh surface, by service, as read verbs only. Curated rather than the
  # AWS managed ReadOnlyAccess policy: ReadOnlyAccess would also grant reads
  # across every other workload in this shared account - fotomena's EKS
  # clusters, argocd, other people's buckets - which is not what a kambriq plan
  # needs and not what a leaked plan credential should reach.
  statement {
    sid = "DescribeTheEstate"
    actions = [
      "acm:Describe*",
      "acm:List*",
      "cloudtrail:Describe*",
      "cloudtrail:Get*",
      "cloudtrail:List*",
      "cloudwatch:Describe*",
      "cloudwatch:Get*",
      "cloudwatch:List*",
      "ec2:Describe*",
      "ecr:Describe*",
      "ecr:Get*",
      "ecr:List*",
      "ecs:Describe*",
      "ecs:List*",
      "elasticache:Describe*",
      "elasticache:List*",
      "elasticloadbalancing:Describe*",
      "iam:Get*",
      "iam:List*",
      "kms:Describe*",
      "kms:GetKeyPolicy",
      "kms:GetKeyRotationStatus",
      "kms:List*",
      "logs:Describe*",
      "logs:List*",
      "rds:Describe*",
      "rds:List*",
      "route53:Get*",
      "route53:List*",
      # Account-scoped, so it cannot be granted against a bucket ARN - and
      # D14a's aws_s3_account_public_access_block is refreshed by every shared
      # plan. Its absence refused the plan role a read it cannot do without.
      "s3:GetAccountPublicAccessBlock",
      "s3:GetBucket*",
      "s3:GetEncryptionConfiguration",
      "s3:GetLifecycleConfiguration",
      "s3:GetReplicationConfiguration",
      "s3:List*",
      # `ses`, not `sesv2` - the same correction as the apply policy in
      # envs/shared/main.tf, and for the same reason: `sesv2:` is not a service
      # IAM knows, so it granted nothing at all.
      "ses:Get*",
      "ses:List*",
      "sns:Get*",
      "sns:List*",
      # Takes no resource, so it cannot live in the scoped SSM statement below -
      # it was listed there and granted nothing.
      "ssm:DescribeParameters",
      "sts:GetCallerIdentity",
      "tag:Get*",
    ]
    resources = ["*"]
  }

  # A plan refreshes every SSM parameter it manages, and that reads the value.
  # Scoped to the project's own prefix, which is the difference between "can
  # read our secrets" and "can read the account's".
  #
  # ssm:DescribeParameters is deliberately NOT here. It supports no
  # resource-level permission, so a scoped statement grants it nothing - it sat
  # in this list looking granted and was refused every time. It is in
  # DescribeTheEstate above, on "*", which is the only way it can be granted.
  statement {
    sid = "ReadTheProjectParameters"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
      "ssm:ListTagsForResource",
    ]
    resources = [
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/kambriq/*",
    ]
  }

  # The state: read both objects, write neither. envs/dev reads the shared state
  # through data.terraform_remote_state.shared, so both keys are listed.
  statement {
    sid     = "ReadTheStateNeverWriteIt"
    actions = ["s3:GetObject", "s3:GetObjectVersion"]
    resources = [
      "arn:aws:s3:::kloudnat-infra-shared-store/kambriq/envs/dev/terraform.tfstate",
      "arn:aws:s3:::kloudnat-infra-shared-store/kambriq/envs/shared/terraform.tfstate",
    ]
  }

  statement {
    sid       = "ListTheStateBucket"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::kloudnat-infra-shared-store"]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["kambriq/*"]
    }
  }

  # D21's key, once the state is encrypted under it. Decrypt only - a plan never
  # writes the state, so it never needs GenerateDataKey.
  statement {
    sid       = "DecryptTheStateKeyD21"
    actions   = ["kms:Decrypt", "kms:DescribeKey"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["s3.${var.aws_region}.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "github_actions_infra_plan" {
  name   = "${var.project_name}-infra-github-actions-plan"
  role   = aws_iam_role.github_actions_infra_plan.id
  policy = data.aws_iam_policy_document.github_actions_infra_plan_permissions.json
}
