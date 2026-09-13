# ============================================================================
# The bastion role, cut down from account administrator to what a bastion does.
# ============================================================================
#
# THE STANDING FACT THIS ADDRESSES
#
# `role/bastion` carries `AdministratorAccess` - `*` on `*`, the whole account -
# through an instance profile. It is latent only because no instance runs it
# today; it was created 2025-12-13 and last used the same day. There is no EC2
# instance, launch template or bastion module anywhere in this repository, and
# the role is in no Terraform state - it was made by hand and left. A bastion is
# by construction the most network-exposed host there is, and this profile would
# hand whoever reaches it total account administration, including the state
# bucket that holds secrets in clear. The day an instance is launched with it can
# arrive without anyone deciding it.
#
# WHAT A BASTION HERE ACTUALLY DOES, established rather than guessed
#
# Its job is to reach the database and the cache from inside the VPC. That reach
# is a NETWORK fact - a security-group rule on 5432 / 6379 - not an IAM one, so
# the role needs nothing for it. What the role legitimately needs is:
#   1. to be reachable at all, via SSM Session Manager (no inbound SSH, no public
#      port) - AmazonSSMManagedInstanceCore; and
#   2. to hand the operator the database password, which lives in SSM as a
#      SecureString - a tightly scoped GetParameter on the db path, plus Decrypt
#      on the one key that encrypts it.
# Everything else in AdministratorAccess - IAM (privilege escalation), every
# bucket, every service, the state - is removed.
#
# There is presently no bastion security group and RDS admits only the ECS task
# SG, so nothing here grants network reach on its own; this is the role a bastion
# would assume, scoped so that assuming it is no longer a path to the whole
# account.
#
# PLAN-TIME IMPORT, ON PURPOSE
#
# The role and its instance profile already exist and are unmanaged. The `import`
# blocks let `terraform plan` read the real objects and show the exact change -
# detach AdministratorAccess, attach Session Manager, add one scoped inline
# policy - while writing nothing to state until an apply that this change does
# not perform. Read the plan before it lands.

import {
  to = aws_iam_role.bastion
  id = "bastion"
}

import {
  to = aws_iam_instance_profile.bastion
  id = "bastion"
}

data "aws_iam_policy_document" "bastion_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "bastion" {
  name               = "bastion"
  assume_role_policy = data.aws_iam_policy_document.bastion_assume.json

  tags = {
    Name        = "bastion"
    Environment = "shared"
  }
}

resource "aws_iam_instance_profile" "bastion" {
  name = "bastion"
  role = aws_iam_role.bastion.name

  tags = {
    Name        = "bastion"
    Environment = "shared"
  }
}

# The one thing that makes a bastion reachable without opening a port. This is
# the AWS-managed policy for Session Manager: ssmmessages, ec2messages and
# ssm:UpdateInstanceInformation, and nothing that touches data or IAM.
#
# Declaring the managed-policy set EXCLUSIVELY is what removes AdministratorAccess:
# the plan shows it detached because it is not in this list.
resource "aws_iam_role_policy_attachments_exclusive" "bastion" {
  role_name   = aws_iam_role.bastion.name
  policy_arns = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"]
}

# The single discretionary grant: read the database password from SSM so an
# operator on the bastion can connect. Scoped to the db path only - not the
# DATABASE_URL parameters, not app config, not other environments' secrets - and
# Decrypt only on the key that encrypts SSM SecureStrings. Remove this block if
# operators should fetch the credential with their own identity instead; the
# reachability above does not depend on it.
data "aws_kms_alias" "ssm" {
  name = "alias/aws/ssm"
}

data "aws_iam_policy_document" "bastion_db_secret" {
  statement {
    sid     = "ReadDbPasswordOnly"
    effect  = "Allow"
    actions = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = [
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/kambriq/*/db/*",
    ]
  }
  statement {
    sid       = "DecryptSsmSecureString"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [data.aws_kms_alias.ssm.target_key_arn]
  }
}

resource "aws_iam_role_policy" "bastion_db_secret" {
  name   = "bastion-read-db-password"
  role   = aws_iam_role.bastion.id
  policy = data.aws_iam_policy_document.bastion_db_secret.json
}
