# ============================================================================
# SES contact list for the newsletter — dev environment
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
    Environment = var.env
    Service     = "newsletter"
    ManagedBy   = "terraform"
  }
}
