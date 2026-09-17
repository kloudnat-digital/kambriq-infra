# ---------------------------------------------------------------------------
# Moved here from envs/dev on 2026-09-13, by state move, without touching AWS.
#
# The comment below already said it: SES permits ONE contact list per account
# per region. So prod cannot have its own, which makes this shared by an AWS
# constraint rather than by convention - and it was tagged Environment = dev,
# which a per-state default_tags would have kept saying.
#
# It is also the one resource here nobody can recreate if it is lost, which is
# why the move is a state operation and the verification afterwards reads AWS
# rather than the state file.
# ---------------------------------------------------------------------------

# ============================================================================
# SES contact list for the newsletter — SHARED, by an AWS constraint
# ============================================================================
# NewsletterService.subscribe() calls ses:CreateContact against this list. Until
# now the list did not exist and the API had no SES permission at all, so the
# endpoint resolved successfully while storing nothing. Terraform owns the list
# so the application never has to provision it: the runtime adds contacts, it
# does not create infrastructure.
#
# The name is injected into the API task as AWS_SES_CONTACT_LIST_NAME, sourced
# from this resource rather than from a literal (see envs/dev/main.tf), so
# Terraform is the single source of it. The application's default in
# libs/common/src/config/env.validation.ts is a fallback that never applies in a
# deployed environment.
#
# SES allows only ONE contact list per AWS account per region, which has real
# consequences for prd. Recorded in
# docs/adr/ADR-005-production-automation-prerequisites.md section 1.1 rather
# than only here.
# ============================================================================

resource "aws_sesv2_contact_list" "newsletter" {
  contact_list_name = "kambriq-newsletter"
  description       = "KAMBRIQ marketing newsletter subscribers"

  tags = {
    Name        = "kambriq-newsletter"
    Project     = "kambriq"
    Environment = "shared"
    Service     = "newsletter"
    ManagedBy   = "terraform"
  }
}
