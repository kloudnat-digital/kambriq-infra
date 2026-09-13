# ---------------------------------------------------------------------------
# Moved here from envs/dev on 2026-09-13, by state move, without touching AWS.
#
# It is an ACCOUNT-level control: `account_id` is the whole account, so it
# already governs buckets that prod has not created yet. Living in dev's state
# meant the environment whose purpose is experimentation owned a protection
# covering production - and a destroy or a careless apply there would have
# removed it for everything.
#
# The rule this follows: a resource belongs to the state whose lifecycle it
# shares, and AWS decides its scope, not us. If AWS makes it unique per account,
# it cannot be per-environment.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# D14 (a) - Block Public Access at the ACCOUNT level.
#
# Applied 11 September 2026. (This line read "PROPOSED, NOT APPLIED" until the
# move on 13 September - a comment that had been false for two days.)
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

# The dev state declared this; the shared root did not, so it comes with the
# resource it feeds.
data "aws_caller_identity" "current" {}

resource "aws_s3_account_public_access_block" "account" {
  account_id = data.aws_caller_identity.current.account_id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}
