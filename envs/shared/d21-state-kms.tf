# ---------------------------------------------------------------------------
# D21 (a) - the key barrier the Terraform state does not have yet.
#
# THE FACT THIS ANSWERS. The state carries secrets in cleartext (established by
# A29 and A30), so the only question that matters is who can read the object.
# Measured with simulate-principal-policy against
# arn:aws:s3:::kloudnat-infra-shared-store/kambriq/envs/dev/terraform.tfstate,
# over every one of the account's 5 users and 32 roles on 16 September 2026:
#
#   user/vmiaff                                            allowed
#   user/uekeum                                            allowed
#   user/gitops.admin                                      allowed
#   role/kambriq-infra-github-actions                      allowed
#   role/AWSReservedSSO_AdministratorAccess_c1b30cb73dd006be  allowed
#
# FIVE, not the four the D wave brief states. The fifth is the IAM Identity
# Center permission-set role (SAML, AdministratorAccess, 12-hour sessions, last
# used 2025-04-25). It is named below on purpose rather than quietly excluded:
# excluding it from the key policy would not lock it out - it holds kms:* in IAM
# and could grant itself - and would only make the barrier read stronger than it
# is. Removing it is an Identity Center assignment decision, not a key policy.
#
# The bucket itself is already closed: public access blocked at bucket and
# account level, ACLs disabled (BucketOwnerEnforced), and no bucket policy at
# all - so access is decided entirely by IAM. What is missing is the SECOND
# barrier: the state is encrypted with SSE-S3, so every principal allowed
# GetObject decrypts transparently, with no key policy in the way.
#
# WHAT THIS KEY CHANGES. With the state encrypted under this CMK, reading it
# requires BOTH s3:GetObject AND kms:Decrypt on this key. A principal whose IAM
# policy allows GetObject but which this key policy does not name is refused -
# that is the barrier, and d21-prove-kms-barrier.sh measures it with a throwaway
# role rather than asserting it.
#
# WHY THE KEY AND NOT THE BUCKET. kloudnat-infra-shared-store is not ours alone:
# besides kambriq/envs/{dev,shared}, it holds three legacy kambriq states
# (kambriq/dev, kambriq/dev-v2, kambriq/shared) and a top-level shared/ prefix,
# in an account that also runs fotomena's EKS clusters and argocd. Setting a
# bucket default encryption key would re-encrypt every future write by every
# writer of that bucket, including writers we do not own, and break their
# applies the moment their principals are not in this key policy. So the key is
# selected by the BACKEND (kms_key_id), which scopes it to the two state objects
# Terraform writes. That change is a separate PR, deliberately - see below.
#
# WHEN THE BARRIER STARTS HOLDING. S3 encrypts per object, at write time. The
# two existing state objects stay SSE-S3 until they are rewritten:
#   - kambriq/envs/shared/terraform.tfstate, last written 2026-09-14T22:45:02Z,
#     is rewritten by the next SHARED apply after the backend PR;
#   - kambriq/envs/dev/terraform.tfstate, last written 2026-09-15T17:06:15Z,
#     is rewritten by the next DEV apply after the backend PR.
# Until each of those, that object is still readable with GetObject alone.
#
# ORDER, and it is not cosmetic. terraform-apply.yml plans and applies with no
# pause, so the key must EXIST before any backend references it: this PR creates
# the key and nothing else. The backend change ships separately, after this is
# applied to shared. Reversed, a dev apply would create resources and then fail
# writing state to a key that does not exist.
#
# COST: USD 1.00 per month for the key, plus USD 0.03 per 10,000 requests. State
# writes are a handful per day, so the request charge rounds to zero - but it is
# not free, and USD 1/month is the figure.
#
# WHAT IT DOES NOT COVER. All five readers are administrators. A key policy
# stops a principal that was never meant to read the state; it does not stop
# somebody who is supposed to be an administrator, and four of these five can
# call kms:PutKeyPolicy and write themselves back in. It also does nothing about
# the state being cleartext at rest inside the object, nor about the bucket
# having no versioning (a bad write is unrecoverable, D21's own finding).
# ---------------------------------------------------------------------------

locals {
  # The four principals we chose, plus the Identity Center administrator role
  # that measurement found. Name-only here; the policy below is what grants.
  d21_state_key_readers = [
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/vmiaff",
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/uekeum",
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/gitops.admin",
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/kambriq-infra-github-actions",
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-reserved/sso.amazonaws.com/eu-west-1/AWSReservedSSO_AdministratorAccess_c1b30cb73dd006be",
  ]
}

# `data.aws_caller_identity.current` is declared once for this environment, in
# d14a-account-public-access-block.tf. Declaring it again here would be a
# duplicate data source, so this file reads that one.

# ---------------------------------------------------------------------------
# The key policy
#
# Deliberately NOT the usual "Principal: account root, Action: kms:*" blanket,
# because that statement delegates the decision straight back to IAM and this
# key exists to stop exactly that. Two statements instead:
#
#   1. KeyAdministration - the two human administrators, gitops.admin, AND the
#      role that manages this key, may manage it. No data-plane action.
#   2. StateEncryptionAndDecryption - the five readers above, and only they, may
#      Decrypt / GenerateDataKey / DescribeKey, and only for S3 in this region:
#      the kms:ViaService condition means a stolen credential cannot use this key
#      through any other service.
#
# THE CI ROLE IS IN THE ADMINISTRATION STATEMENT, AND IT HAS TO BE. The first
# version of this file named only the three humans, and the apply was refused:
#
#   MalformedPolicyDocumentException: The new key policy will not allow you to
#   update the key policy in the future.
#   (terraform-apply.yml run 35134521387, 2026-09-16 18:30 UTC)
#
# That is KMS's policy lockout safety check, and the rule behind it is written
# into the service: "Unlike other AWS resource policies, an AWS KMS key policy
# does not automatically give permission to the account or any of its
# principals. To give permission to any principal, including the account
# principal, you must use a key policy statement that provides the permission
# explicitly." A policy that lets nobody who can actually call PutKeyPolicy do
# so is a key that cannot be administered, and CreateKey refuses it up front.
#
# Terraform manages this key, so the principal Terraform runs as must be able to
# administer it - otherwise the very next change to this policy would fail, and
# the key would be maintainable only by a human with console access. The
# alternative, `bypass_policy_lockout_safety_check = true`, is deliberately NOT
# used: it silences the check rather than satisfying it, and it is exactly how a
# key ends up unmanageable and reachable only through AWS Support.
#
# What that costs, said plainly: the apply role can rewrite this key policy, so
# it can grant itself the data-plane permissions the second statement withholds.
# It could already do that before D16 (Action:* Resource:*) and still can after
# it (iam:* over kambriq-* principals). The barrier this key adds is against a
# principal that was never meant to read the state, not against the pipeline.
#
# There is no Deny statement. A Deny would also hit the key administrators and
# make the key unmanageable; the barrier here is the ABSENCE of an allow for
# everybody else, which is how KMS key policies work.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "d21_state_key" {
  statement {
    sid    = "KeyAdministration"
    effect = "Allow"

    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/vmiaff",
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/uekeum",
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/gitops.admin",
        # The principal that creates and maintains this key. Without it, KMS
        # refuses the policy outright - see the block above.
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/kambriq-infra-github-actions",
      ]
    }

    actions = [
      "kms:Create*",
      "kms:Describe*",
      "kms:Enable*",
      "kms:List*",
      "kms:Put*",
      "kms:Update*",
      "kms:Revoke*",
      "kms:Disable*",
      "kms:Get*",
      "kms:Delete*",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:ScheduleKeyDeletion",
      "kms:CancelKeyDeletion",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "StateEncryptionAndDecryption"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = local.d21_state_key_readers
    }

    # What an S3 SSE-KMS read and write actually need, and nothing else.
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey",
    ]

    resources = ["*"]

    # The key is usable only through S3, in this region. A credential that can
    # decrypt the state object cannot use the key for anything else.
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["s3.${var.aws_region}.amazonaws.com"]
    }
  }
}

resource "aws_kms_key" "state" {
  description = "kambriq shared - Terraform state encryption (D21)"
  policy      = data.aws_iam_policy_document.d21_state_key.json

  # Rotation is free and changes nothing about who can read: the key ARN and its
  # policy are what the backend and the barrier depend on.
  enable_key_rotation = true

  # A week is long enough to notice a mistaken deletion and short enough not to
  # keep paying for a key nobody wants. Deleting this key makes both state
  # objects unreadable, which is the point and also the risk.
  deletion_window_in_days = 7

  tags = {
    Name = "${var.project_name}-shared-tfstate"
    Type = "shared"
  }
}

resource "aws_kms_alias" "state" {
  name          = "alias/${var.project_name}-shared-tfstate"
  target_key_id = aws_kms_key.state.key_id
}
