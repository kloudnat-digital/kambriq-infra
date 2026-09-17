# ============================================================================
# D22 - the account's management events are kept somewhere.
# ============================================================================
#
# CloudTrail's event history keeps 90 days and nothing more. This account is
# shared by several projects and carries several administrator identities, and
# until this trail nothing kept CreateRole, AttachRolePolicy, PutBucketPolicy,
# CreateUser - everything that changes who can do what - past those 90 days.
#
# It does not bring anything back. A trail records from the moment it starts
# logging; December 2025 stays unattributable.
#
# WHY A SECOND TRAIL, NOT A FLAG ON D14's
#
# Read from the live configuration on 14 September 2026, not from the source:
#
#   kambriq-dev-kyc-data-events   IsMultiRegionTrail         = false
#                                 IncludeGlobalServiceEvents = false
#                                 advanced selectors         = eventCategory Data only
#
# and it is the only trail in the account, in any region (describe-trails
# --include-shadow-trails, every region). Switching management events on there
# would record eu-central-1's management events and miss the ones this exists
# for: IAM is a global service and its events are delivered in us-east-1, which
# a single-region trail anywhere else never receives. Making D14's trail
# multi-region instead would turn a dev, KYC-scoped resource into the account's
# audit trail under a dev name. So it is its own trail, account-wide, here.
#
# COST
#
# The first copy of management events in each region is free, and this is the
# first: no trail in the account records management events today. A SECOND
# trail recording them would be billed at USD 2.00 per 100 000 events - so
# nothing else may switch management events on without reading this, D14's
# trail included.
#
# What remains is S3. Measured on 14 September, 10:00-11:00 UTC: about 1 140
# management events an hour (eu-central-1: 1 063 read, 67 write; us-east-1: 9),
# roughly 0.8 million a month. Compressed, that is low hundreds of MB and some
# tens of thousands of PUTs a month: under USD 0.25. The bucket has no lifecycle
# rule, so the storage accumulates - which is the point of an audit log, and is
# recorded in the register rather than decided here.
#
# READ AND WRITE, NOT WRITE-ONLY
#
# AssumeRole and AssumeRoleWithWebIdentity are recorded with readOnly=true, and
# they are how an action taken through a role is traced back to whoever assumed
# it. A write-only trail would keep the PutBucketPolicy and lose who held the
# role that made it. At these volumes the difference is cents.
#
# THE BUCKET POLICY NEEDS NO CHANGE
#
# d14b-trail-bucket-policy.tf already grants the CloudTrail service PutObject on
# AWSLogs/<account>/*, which is where every trail writes when it has no key
# prefix. A prefix here would move delivery outside that grant and the trail
# would log nothing, so it deliberately has none.
resource "aws_cloudtrail" "d22_management" {
  name           = "${var.project_name}-shared-management-events"
  s3_bucket_name = data.aws_s3_bucket.d14_logs.id

  is_multi_region_trail         = true
  include_global_service_events = true
  enable_log_file_validation    = true
  enable_logging                = true

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  tags = {
    Name      = "${var.project_name}-shared-management-events"
    Project   = var.project_name
    Service   = "cloudtrail"
    ManagedBy = "terraform"
  }

  # An audit trail is the first thing somebody covering their tracks deletes.
  # This refuses only through terraform; the account-level answer is an SCP,
  # which is not in scope here.
  lifecycle {
    prevent_destroy = true
  }

  depends_on = [aws_s3_bucket_policy.d14_trail_bucket]
}
