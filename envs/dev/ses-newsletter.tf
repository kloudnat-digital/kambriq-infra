# ============================================================================
# SES contact list for the newsletter — dev environment
# ============================================================================
# NewsletterService.subscribe() calls ses:CreateContact against this list. Until
# now the list did not exist and the API had no SES permission at all, so the
# endpoint resolved successfully while storing nothing. Terraform owns the list
# so the application never has to provision it: the runtime adds contacts, it
# does not create infrastructure.
#
# The name must match AWS_SES_CONTACT_LIST_NAME, which is not set in SSM, so the
# application falls back to the default in libs/common/src/config/env.validation.ts
# ('kambriq-newsletter'). The two are coupled by convention only; changing either
# without the other silently breaks subscriptions.
#
# CONSTRAINT worth knowing before prd: SES allows only ONE contact list per AWS
# account per region. This resource therefore cannot be duplicated into an
# envs/prd stack in the same account and region — prd would either share this
# list or need its own account/region. Left here rather than in envs/shared
# because dev is the only deployed environment today; see
# docs/adr/ADR-005-production-automation-prerequisites.md when that changes.
# ============================================================================

resource "aws_sesv2_contact_list" "newsletter" {
  contact_list_name = "kambriq-newsletter"
  description       = "KAMBRIQ marketing newsletter subscribers"

  tags = {
    Name        = "kambriq-newsletter"
    Project     = "kambriq"
    Environment = var.env
    Service     = "newsletter"
    ManagedBy   = "terraform"
  }
}
