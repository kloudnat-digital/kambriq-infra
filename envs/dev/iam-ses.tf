# ============================================================================
# IAM: SES send permission for the API ECS task role — dev environment
# ============================================================================
# The API sends transactional mail (email verification, password reset) through
# SESv2 from the ECS task role. Until this policy existed the role had no ses:
# action at all, so every send would have failed with AccessDenied — had the
# application ever attempted one. It did not: it silently fell back to a console
# transport whenever static credentials were absent, which on Fargate is always.
#
# Placed in the env layer rather than in modules/iam-roles-ecs, following the
# same convention as iam-media.tf: the policy joins the task role from
# module.iam_roles_ecs to a resource the module does not own, so neither module
# is the right home for it.
#
# ses:CreateContact is granted, scoped to the newsletter contact list that
# Terraform now owns (see ses-newsletter.tf). ses:CreateContactList is NOT
# granted: the runtime adds contacts, it never provisions infrastructure.
# ============================================================================

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  # Derived from the sender address so the resource and the ses:FromAddress
  # condition below cannot drift apart: both come from var.ses_from_email.
  ses_identity_domain = split("@", var.ses_from_email)[1]

  ses_identity_arn = format(
    "arn:aws:ses:%s:%s:identity/%s",
    data.aws_region.current.name,
    data.aws_caller_identity.current.account_id,
    local.ses_identity_domain,
  )
}

resource "aws_iam_role_policy" "api_ses_send" {
  name = "kambriq-ses-${var.env}-send"
  role = module.iam_roles_ecs.task_api_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SendEmailFromVerifiedDomainIdentity"
        Effect = "Allow"
        # ses:SendEmail covers the SESv2 SendEmail API used by EmailProcessor.
        Action = ["ses:SendEmail"]
        # Scoped to the verified domain identity, not "*".
        Resource = local.ses_identity_arn
        Condition = {
          # Narrows the grant to a single From address, so the role cannot send
          # as any other address under the domain.
          StringEquals = {
            "ses:FromAddress" = var.ses_from_email
          }
        }
      },
      {
        Sid    = "AddNewsletterContacts"
        Effect = "Allow"
        # CreateContact only. CreateContactList is deliberately withheld: the
        # list is a Terraform resource, not something the API may create.
        Action   = ["ses:CreateContact"]
        Resource = aws_sesv2_contact_list.newsletter.arn
      }
    ]
  })
}
