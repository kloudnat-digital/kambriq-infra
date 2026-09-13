# ============================================================================
# The CloudTrail write policy on the account's shared log bucket.
# ============================================================================
#
# `kambriq-logs-b9321a78` is one bucket for the whole account - there is no
# per-environment copy of it, and AWS allows exactly one policy per bucket. A
# resource whose scope AWS fixes at one-per-account belongs to the state whose
# lifecycle it shares, which is this one; it lived in `envs/dev` only because
# that is where the KYC trail that writes to it lives.
#
# The trail itself stays in `envs/dev`: it watches dev's KYC media prefix and is
# genuinely per-environment. Only the bucket policy, which grants the CloudTrail
# service principal write for `AWSLogs/<account>/*` and names no environment,
# moves here.
#
# WHAT HELD THE DEPENDENCY BEFORE, AND WHAT HOLDS IT NOW
#
# dev's trail carried `depends_on = [aws_s3_bucket_policy.d14_trail_bucket]` so
# the policy was in place before the trail first tried to write. That ordering
# cannot cross a state boundary, and it no longer needs to: the policy already
# exists, and by convention `envs/shared` is applied before `envs/dev`. A brand
# new bootstrap must apply shared first for exactly this reason - recorded in the
# move's pull request, not left to a comment nobody reads at 2am.
data "aws_s3_bucket" "d14_logs" {
  bucket = "kambriq-logs-b9321a78"
}

data "aws_iam_policy_document" "d14_trail_bucket" {
  statement {
    sid     = "AWSCloudTrailAclCheck"
    effect  = "Allow"
    actions = ["s3:GetBucketAcl"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    resources = [data.aws_s3_bucket.d14_logs.arn]
  }

  statement {
    sid     = "AWSCloudTrailWrite"
    effect  = "Allow"
    actions = ["s3:PutObject"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    resources = ["${data.aws_s3_bucket.d14_logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

resource "aws_s3_bucket_policy" "d14_trail_bucket" {
  bucket = data.aws_s3_bucket.d14_logs.id
  policy = data.aws_iam_policy_document.d14_trail_bucket.json
}
