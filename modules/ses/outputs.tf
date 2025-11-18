output "domain_identity_arn" {
  description = "SES domain identity ARN"
  value       = aws_ses_domain_identity.main.arn
}

output "domain_identity_verification_token" {
  description = "SES domain verification token (à ajouter dans DNS)"
  value       = aws_ses_domain_identity.main.verification_token
}

output "email_identity_arn" {
  description = "SES email identity ARN"
  value       = aws_ses_email_identity.main.arn
}

output "from_email" {
  description = "Default sender email address"
  value       = var.from_email
}

output "dkim_tokens" {
  description = "DKIM tokens for DNS configuration"
  value       = aws_ses_domain_dkim.main.dkim_tokens
}

