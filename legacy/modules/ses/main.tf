# ============================================================================
# LEGACY: This module is no longer used in the active KAMBRIQ infrastructure.
# It has been replaced by modules/shared which includes SES functionality.
# This module is kept for historical reference only.
# ============================================================================
#
# SES Domain Identity
resource "aws_ses_domain_identity" "main" {
  domain = var.domain
}

# DNS verification record (à ajouter manuellement dans le DNS ou via Route53)
# Pour l'instant, on le crée mais il faudra le valider manuellement
resource "aws_ses_domain_identity_verification" "main" {
  domain = aws_ses_domain_identity.main.id

  timeouts {
    create = "5m"
  }
}

# Email Identity (pour l'adresse d'envoi)
resource "aws_ses_email_identity" "main" {
  email = var.from_email
}

# Configuration DKIM (optionnel, mais recommandé)
resource "aws_ses_domain_dkim" "main" {
  domain = aws_ses_domain_identity.main.domain
}

# Note: Pour sortir du sandbox SES (envoyer à n'importe quelle adresse),
# faire une demande via AWS Support Console

