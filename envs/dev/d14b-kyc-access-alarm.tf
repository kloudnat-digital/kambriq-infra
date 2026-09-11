# ---------------------------------------------------------------------------
# D14 (b) - alarm on a SERIES of denied anonymous reads of KYC keys.
#
# PROPOSED, NOT APPLIED. Plan only.
#
# One 403 is noise: a stale presigned URL, a crawler, a typo. A run of them on
# users/*/id-documents/ is somebody trying keys, and today nobody would see it -
# the account has no CloudTrail trail at all, and kambriq-media-dev has no
# server access logging. Neither mechanism is on, which is why the request
# volume below is an estimate rather than a measurement.
#
# ---------------------------------------------------------------------------
# Why CloudTrail data events rather than S3 server access logging
# ---------------------------------------------------------------------------
# The two cost effectively the same here, so cost does not decide it. Both are
# dominated by the $0.10/month CloudWatch alarm.
#
#   CloudTrail data events, scoped to the one prefix
#     data events   5 000 req/mo / 100 000 x $0.10  = $0.005
#     CW Logs in    5 000 x ~1.5 KB = 7.5 MB x $0.63/GB = $0.005
#     alarm                                         = $0.10
#     TOTAL                                         ~ $0.11 / month
#     delay: CloudTrail to CloudWatch Logs, about 5 minutes, 15 at worst.
#
#   S3 server access logs + metric filter
#     log generation                                = free
#     log storage   5 000 x ~300 B = 1.5 MB         ~ $0.00
#     alarm                                         = $0.10
#     TOTAL                                         ~ $0.10 / month
#     delay: best effort, "within a few hours", sometimes longer.
#
# TWO THINGS THE CHEAP OPTION DOES NOT SEE, and they are why it is not chosen:
#
#   1. Server access logging is documented by AWS as BEST EFFORT. Some requests
#      are simply never logged. For a security control that is the wrong
#      guarantee: the run of 403s you most want is the one that might not be
#      recorded.
#   2. Server access logs are delivered to S3, NOT to CloudWatch Logs, so a
#      metric filter cannot read them. Making the cheap option alert at all
#      needs a Lambda shipping lines into CloudWatch Logs, or scheduled Athena
#      queries - a component to write, deploy and monitor, for a saving of one
#      cent a month.
#
# What CloudTrail data events still do not see: a request that never reaches
# S3. A block at the edge, a DNS-level interception, or a copy of the object
# taken from somewhere other than this bucket leave no trace here.
#
# ---------------------------------------------------------------------------
# Scoped to the prefix on purpose
# ---------------------------------------------------------------------------
# The advanced event selector matches only objects under users/ with
# id-documents/ in the key. Logging every object in the bucket would multiply
# the event count by the lands media and the payment proofs, for keys whose
# exposure is a different question.
# ---------------------------------------------------------------------------

locals {
  d14_kyc_prefix    = "users/"
  d14_trail_name    = "${var.project_name}-${var.env}-kyc-data-events"
  d14_log_group     = "/aws/cloudtrail/${var.project_name}-${var.env}-kyc"
  d14_logs_bucket   = "kambriq-logs-b9321a78"
  d14_alarm_threshold = 5   # denied reads
  d14_alarm_period    = 300 # within 5 minutes
}

# The trail's S3 destination. The bucket already exists and is empty; only its
# policy is managed here, so this adds no storage resource.
data "aws_s3_bucket" "d14_logs" {
  bucket = local.d14_logs_bucket
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

# Short retention: this log group exists to raise an alarm within minutes, not
# to be an archive. The trail's own S3 copy is the record that keeps.
resource "aws_cloudwatch_log_group" "d14_kyc" {
  name              = local.d14_log_group
  retention_in_days = 14
}

data "aws_iam_policy_document" "d14_trail_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "d14_trail_to_logs" {
  name               = "${var.project_name}-${var.env}-kyc-trail-to-logs"
  assume_role_policy = data.aws_iam_policy_document.d14_trail_assume.json
}

resource "aws_iam_role_policy" "d14_trail_to_logs" {
  name = "write-kyc-trail-events"
  role = aws_iam_role.d14_trail_to_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "${aws_cloudwatch_log_group.d14_kyc.arn}:*"
    }]
  })
}

resource "aws_cloudtrail" "d14_kyc" {
  name                          = local.d14_trail_name
  s3_bucket_name                = data.aws_s3_bucket.d14_logs.id
  include_global_service_events = false
  is_multi_region_trail         = false
  enable_log_file_validation    = true

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.d14_kyc.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.d14_trail_to_logs.arn

  # Data events only, read-only, and only for KYC object keys. Management
  # events are deliberately off: this trail answers one question.
  advanced_event_selector {
    name = "KYC object reads only"

    field_selector {
      field  = "eventCategory"
      equals = ["Data"]
    }
    field_selector {
      field  = "resources.type"
      equals = ["AWS::S3::Object"]
    }
    field_selector {
      field  = "readOnly"
      equals = ["true"]
    }
    field_selector {
      field       = "resources.ARN"
      starts_with = ["${module.s3_media.bucket_arn}/${local.d14_kyc_prefix}"]
    }
  }

  depends_on = [aws_s3_bucket_policy.d14_trail_bucket]
}

# AccessDenied on a KYC key. An anonymous caller has no userIdentity to name,
# which is precisely the shape being counted.
resource "aws_cloudwatch_log_metric_filter" "d14_denied" {
  name           = "${var.project_name}-${var.env}-kyc-access-denied"
  log_group_name = aws_cloudwatch_log_group.d14_kyc.name
  pattern        = "{ $.errorCode = \"AccessDenied\" && $.requestParameters.key = \"*id-documents*\" }"

  metric_transformation {
    name          = "KycAccessDenied"
    namespace     = "${var.project_name}/${var.env}/security"
    value         = "1"
    default_value = "0"
  }
}

# No email address in this repository. The topic is created empty and the
# subscription is added out of band, like every other identity in this project.
resource "aws_sns_topic" "d14_security" {
  name = "${var.project_name}-${var.env}-security-alerts"
}

resource "aws_cloudwatch_metric_alarm" "d14_kyc_denied_series" {
  alarm_name        = "${var.project_name}-${var.env}-kyc-denied-series"
  alarm_description = "A run of denied reads on identity-document keys. One 403 is noise; ${local.d14_alarm_threshold} in ${local.d14_alarm_period / 60} minutes is somebody trying keys."

  namespace           = aws_cloudwatch_log_metric_filter.d14_denied.metric_transformation[0].namespace
  metric_name         = aws_cloudwatch_log_metric_filter.d14_denied.metric_transformation[0].name
  statistic           = "Sum"
  period              = local.d14_alarm_period
  evaluation_periods  = 1
  threshold           = local.d14_alarm_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"

  # A quiet period is zero denied reads, not missing data.
  treat_missing_data = "notBreaching"

  alarm_actions = [aws_sns_topic.d14_security.arn]
}
