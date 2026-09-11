# ---------------------------------------------------------------------------
# D14 (a) - Block Public Access at the ACCOUNT level.
#
# PROPOSED, NOT APPLIED. Plan only.
#
# kambriq-media-dev already carries all four flags on the bucket itself, which
# is what makes the KYC documents unreachable today. The account does not, so a
# bucket created tomorrow inherits nothing and a single careless `--acl
# public-read` is enough to publish it.
#
# Verified before proposing: all four buckets in 051551940370 already have all
# four flags set, none has a bucket policy at all, none has website hosting
# enabled, and there are no CloudFront distributions. So nothing in this account
# relies on public access and this setting breaks nothing today.
#
#   kambriq-artifacts-b9321a78    BPA all true, no policy, no website
#   kambriq-logs-b9321a78         BPA all true, no policy, no website
#   kambriq-media-dev             BPA all true, no policy, no website
#   kloudnat-infra-shared-store   BPA all true, no policy, no website
#
# What it costs: nothing. There is no charge for this setting.
#
# What it changes for the future: a public bucket in this account becomes
# impossible without first removing this resource, which is a reviewed
# Terraform change rather than a console click.
# ---------------------------------------------------------------------------

resource "aws_s3_account_public_access_block" "account" {
  account_id = data.aws_caller_identity.current.account_id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}
