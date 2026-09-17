# ---------------------------------------------------------------------------
# D13 - dev.kambriq.com stops serving an unfinished site to anyone with the URL.
#
# THE FACT. The `noindex` header asks search engines not to index; it asks
# nobody not to look. The UX audit of 9 September was carried out exactly that
# way, by somebody who simply had the URL.
#
# WHY COGNITO AND NOT HTTP BASIC AT THE ALB. Visquis's decision, and the reason
# it is the only ALB-native one that can work: an ALB fixed-response carries
# ONLY StatusCode, ContentType and MessageBody (`FixedResponseActionConfig`, API
# reference). It cannot emit `WWW-Authenticate`, so no listener rule can issue a
# Basic challenge and no browser will ever prompt. `authenticate-cognito` is an
# ALB action type, so the load balancer does the authenticating and the web
# container is untouched.
#
# WHAT IS EXEMPT, AND WHY THAT IS THE WHOLE DESIGN. `/api/v1/*` and `/health`
# are forwarded without authentication, because every machine caller reaches dev
# through one of those two:
#
#   delivery journeys      KAMBRIQ_API_URL unset -> https://dev.kambriq.com/api/v1
#   api-e2e global setup   same default
#   deploy-dev smoke test  SMOKE_TEST_URL = https://dev.kambriq.com/api/v1/health/ready
#   API version gate       VERSION_CHECK_URL unset -> .../api/v1/health/version
#   web version gate       WEB_HEALTH_URL unset -> NEXT_PUBLIC_APP_URL + /health
#
# The API is not left open by this: it carries its own bearer-token guard on
# every route except the deliberate public surface (auth, contact, newsletter,
# kbs-public, the three health routes), which is public in production by design.
# Target group health checks are unaffected in any case - they are performed by
# the load balancer directly against the task (`HealthCheckPath`
# /api/v1/health/ready and /health, `traffic-port`), never through a listener
# rule.
#
# NO USERS ARE CREATED HERE. Identities are Visquis's to decide. The pool is
# created empty, and an empty pool means nobody can log in - including, and this
# is the point of the report attached to this change, the web E2E suite.
#
# COST: USD 0 at this scale. Cognito's Essentials tier is free for the first
# 10 000 monthly active users, then USD 0.015 per MAU. A handful of people is
# nowhere near it. The ALB action itself is free; the listener rules are free.
# ---------------------------------------------------------------------------

locals {
  # The host, derived from the URL the application is already configured with,
  # so the callback the pool allows and the address people actually visit
  # cannot drift apart. `frontend_url` is https://dev.kambriq.com in tfvars.
  d13_web_host = replace(replace(var.frontend_url, "https://", ""), "http://", "")
}

resource "aws_cognito_user_pool" "dev_access" {
  name = "${local.name_prefix}-dev-access"

  # No self-registration: this gate exists to keep strangers out, so a stranger
  # must not be able to create their own way in.
  admin_create_user_config {
    allow_admin_create_user_only = true
  }

  # A person, not a service: email is the sign-in identity and the recovery
  # channel, and it is what the ALB receives as a claim.
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length                   = 14
    require_lowercase                = true
    require_uppercase                = true
    require_numbers                  = true
    require_symbols                  = true
    temporary_password_validity_days = 7
  }

  # Cognito's own email sender is enough for a handful of invitations, and it
  # avoids giving this pool a path into the platform's SES identity.
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  tags = {
    Name = "${local.name_prefix}-dev-access"
    Env  = var.env
  }
}

# The hosted domain the ALB redirects to. A prefix domain (not a custom one)
# needs no certificate of its own; the prefix must be unique across the region,
# which is why it carries the project and environment rather than "login".
resource "aws_cognito_user_pool_domain" "dev_access" {
  domain       = "${local.name_prefix}-access"
  user_pool_id = aws_cognito_user_pool.dev_access.id
}

# AWS's requirements for an ALB-authenticating client, verbatim from the ELB
# documentation: "You must configure the client to generate a client secret, use
# code grant flow, and support the same OAuth scopes that the load balancer
# uses", and the callback must be `https://<DNS>/oauth2/idpresponse` in all
# lower case.
resource "aws_cognito_user_pool_client" "dev_access" {
  name         = "${local.name_prefix}-alb"
  user_pool_id = aws_cognito_user_pool.dev_access.id

  generate_secret                      = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_flows_user_pool_client = true
  # `openid` is required: the default scope is the one that returns an ID token,
  # which is what the ALB exchanges. `email` is what makes the claim useful to
  # the application if it ever reads it.
  allowed_oauth_scopes = ["openid", "email"]

  callback_urls = [
    "https://${local.d13_web_host}/oauth2/idpresponse",
  ]
  logout_urls = [
    "https://${local.d13_web_host}/",
  ]

  supported_identity_providers = ["COGNITO"]

  # A short-lived code, long-lived sessions handled by the ALB cookie instead.
  explicit_auth_flows = ["ALLOW_USER_SRP_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
}

output "d13_cognito_user_pool_id" {
  description = "D13: the user pool that gates the dev web paths. Created empty on purpose."
  value       = aws_cognito_user_pool.dev_access.id
}

output "d13_cognito_add_user_command" {
  description = "D13: the exact command to admit one person. Run by Visquis; no user is created by Terraform."
  value = join(" ", [
    "aws cognito-idp admin-create-user",
    "--region ${var.aws_region}",
    "--user-pool-id ${aws_cognito_user_pool.dev_access.id}",
    "--username <email>",
    "--user-attributes Name=email,Value=<email> Name=email_verified,Value=true",
    "--desired-delivery-mediums EMAIL",
  ])
}
