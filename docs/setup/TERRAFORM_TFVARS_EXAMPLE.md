# Guide des Variables Terraform (terraform.tfvars) - KAMBRIQ

Ce document liste toutes les variables à configurer dans les fichiers `terraform.tfvars` pour chaque environnement (shared, dev, prod).

**⚠️ IMPORTANT** : Les fichiers `terraform.tfvars` ne sont **jamais** commités dans Git (déjà dans `.gitignore`). Utilisez les fichiers `.tfvars.example` comme référence.

---

## Structure des tfvars

Chaque environnement a son propre fichier `terraform.tfvars` :
- `envs/shared/terraform.tfvars` - Infrastructure partagée
- `envs/dev/terraform.tfvars` - Environnement de développement
- `envs/prod/terraform.tfvars` - Environnement de production

---

## 1. Variables pour `envs/shared/terraform.tfvars`

### Variables obligatoires

```hcl
# ============================================================================
# Configuration de base
# ============================================================================

# Région AWS où déployer l'infrastructure
aws_region = "eu-central-1"

# CIDR block pour la VPC (par défaut 10.0.0.0/16)
vpc_cidr = "10.0.0.0/16"

# Domaine principal (kambriq.com)
domain_name = "kambriq.com"

# ============================================================================
# SES Configuration (créé manuellement dans AWS Console)
# ============================================================================
# SES identities sont créées et vérifiées manuellement dans la console AWS.
# Après la création manuelle, fournissez les ARNs ici.
# Voir docs/setup/SES_AND_ACM_MANUAL_SETUP.md pour les instructions.

# Domaine SES vérifié (ex: kambriq.com)
ses_domain = "kambriq.com"

# Région AWS où SES est configuré (ex: eu-central-1)
ses_region = "eu-central-1"

# ARN de l'identité de domaine SES (créé manuellement)
# Format: arn:aws:ses:eu-central-1:ACCOUNT_ID:identity/kambriq.com
ses_domain_identity_arn = "arn:aws:ses:eu-central-1:123456789012:identity/kambriq.com"

# Adresse email expéditeur SES vérifiée (ex: noreply@kambriq.com)
ses_from_email = "noreply@kambriq.com"

# ARN de l'identité email SES (créé manuellement)
# Format: arn:aws:ses:eu-central-1:ACCOUNT_ID:identity/noreply@kambriq.com
ses_email_identity_arn = "arn:aws:ses:eu-central-1:123456789012:identity/noreply@kambriq.com"

# ============================================================================
# ACM Certificates (créés manuellement dans AWS Console)
# ============================================================================
# Les certificats ACM sont créés et validés manuellement dans la console AWS.
# Après la création manuelle, fournissez les ARNs ici.
# Voir docs/setup/SES_AND_ACM_MANUAL_SETUP.md pour les instructions.

# Certificat ACM pour API Gateway (OBLIGATOIREMENT en eu-central-1)
# Format: arn:aws:acm:eu-central-1:ACCOUNT_ID:certificate/CERTIFICATE_ID
api_acm_certificate_arn = "arn:aws:acm:eu-central-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"

# Certificat ACM pour CloudFront (OBLIGATOIREMENT en us-east-1)
# Format: arn:aws:acm:us-east-1:ACCOUNT_ID:certificate/CERTIFICATE_ID
cloudfront_acm_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"

# ============================================================================
# S3 Buckets (optionnel)
# ============================================================================

# Activer le bucket S3 pour les logs
enable_s3_logs = true

# Activer le bucket S3 pour les artifacts
enable_s3_artifacts = true
```

### Comment obtenir les ARNs

#### ARN SES Domain Identity

```bash
# Via AWS CLI
aws ses get-identity-verification-attributes \
  --identities "kambriq.com" \
  --region eu-central-1 \
  --query 'VerificationAttributes.kambriq.com.VerificationStatus'

# L'ARN est au format: arn:aws:ses:eu-central-1:ACCOUNT_ID:identity/kambriq.com
# Récupérez-le depuis la console AWS → SES → Verified identities → kambriq.com
```

#### ARN SES Email Identity

```bash
# Via AWS CLI
aws ses get-identity-verification-attributes \
  --identities "noreply@kambriq.com" \
  --region eu-central-1

# L'ARN est au format: arn:aws:ses:eu-central-1:ACCOUNT_ID:identity/noreply@kambriq.com
# Récupérez-le depuis la console AWS → SES → Verified identities → noreply@kambriq.com
```

#### ARN Certificat ACM pour API Gateway

```bash
# Via AWS CLI (région eu-central-1)
aws acm list-certificates --region eu-central-1

# Détails d'un certificat
aws acm describe-certificate \
  --certificate-arn "arn:aws:acm:eu-central-1:123456789012:certificate/..." \
  --region eu-central-1 \
  --query 'Certificate.CertificateArn'
```

#### ARN Certificat ACM pour CloudFront

```bash
# Via AWS CLI (région us-east-1 - OBLIGATOIRE)
aws acm list-certificates --region us-east-1

# Détails d'un certificat
aws acm describe-certificate \
  --certificate-arn "arn:aws:acm:us-east-1:123456789012:certificate/..." \
  --region us-east-1 \
  --query 'Certificate.CertificateArn'
```

---

## 2. Variables pour `envs/dev/terraform.tfvars`

### Variables obligatoires

```hcl
# ============================================================================
# Configuration de base
# ============================================================================

# Région AWS
aws_region = "eu-central-1"

# ============================================================================
# Domaines personnalisés (optionnel pour DEV)
# ============================================================================
# Par défaut, CloudFront et API Gateway utilisent leurs URLs par défaut.
# Pour activer des domaines personnalisés, décommenter et remplir :

# Domaine CloudFront (ex: app-dev.kambriq.com)
# cloudfront_domain = "app-dev.kambriq.com"

# Certificat ACM pour CloudFront (OBLIGATOIREMENT en us-east-1)
# Doit correspondre au domaine cloudfront_domain
# Format: arn:aws:acm:us-east-1:ACCOUNT_ID:certificate/CERTIFICATE_ID
# cloudfront_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"

# Domaine API Gateway (ex: api-dev.kambriq.com)
# api_domain = "api-dev.kambriq.com"

# Certificat ACM pour API Gateway (OBLIGATOIREMENT en eu-central-1)
# Doit correspondre au domaine api_domain
# Format: arn:aws:acm:eu-central-1:ACCOUNT_ID:certificate/CERTIFICATE_ID
# api_certificate_arn = "arn:aws:acm:eu-central-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"
```

### Variables dépréciées (ne plus utiliser)

```hcl
# ⚠️ DEPRECATED: Ces variables ne sont plus utilisées.
# Les secrets sont maintenant récupérés depuis SSM Parameter Store.
# Voir envs/dev/main.tf pour les data sources SSM.

# db_password = ""  # Ne plus utiliser
# jwt_secret = ""   # Ne plus utiliser
```

---

## 3. Variables pour `envs/prod/terraform.tfvars`

### Variables obligatoires

```hcl
# ============================================================================
# Configuration de base
# ============================================================================

# Région AWS
aws_region = "eu-central-1"

# ============================================================================
# Domaines personnalisés (recommandé pour PROD)
# ============================================================================
# Pour activer des domaines personnalisés en production :

# Domaine CloudFront (ex: app.kambriq.com)
cloudfront_domain = "app.kambriq.com"

# Certificat ACM pour CloudFront (OBLIGATOIREMENT en us-east-1)
# Doit correspondre au domaine cloudfront_domain
# Format: arn:aws:acm:us-east-1:ACCOUNT_ID:certificate/CERTIFICATE_ID
cloudfront_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"

# Domaine API Gateway (ex: api.kambriq.com)
api_domain = "api.kambriq.com"

# Certificat ACM pour API Gateway (OBLIGATOIREMENT en eu-central-1)
# Doit correspondre au domaine api_domain
# Format: arn:aws:acm:eu-central-1:ACCOUNT_ID:certificate/CERTIFICATE_ID
api_certificate_arn = "arn:aws:acm:eu-central-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"
```

### Variables dépréciées (ne plus utiliser)

```hcl
# ⚠️ DEPRECATED: Ces variables ne sont plus utilisées.
# Les secrets sont maintenant récupérés depuis SSM Parameter Store.
# Voir envs/prod/main.tf pour les data sources SSM.

# db_password = ""  # Ne plus utiliser
# jwt_secret = ""   # Ne plus utiliser
```

---

## 4. Ordre de configuration

### Étape 1 : Configurer `shared/terraform.tfvars`

1. Créer les identités SES dans la console AWS (voir `docs/setup/SES_AND_ACM_MANUAL_SETUP.md`)
2. Créer les certificats ACM dans la console AWS
3. Récupérer les ARNs
4. Remplir `envs/shared/terraform.tfvars` avec les ARNs
5. Déployer le stack shared : `cd envs/shared && terraform apply`

### Étape 2 : Configurer `dev/terraform.tfvars` ou `prod/terraform.tfvars`

1. Si vous voulez des domaines personnalisés :
   - Créer les certificats ACM supplémentaires (si différents de shared)
   - Récupérer les ARNs
   - Remplir les variables `cloudfront_certificate_arn` et `api_certificate_arn`
2. Déployer le stack dev/prod : `cd envs/dev && terraform apply`

---

## 5. Vérification

Après avoir configuré les tfvars, vérifiez que Terraform peut les utiliser :

```bash
# Pour shared
cd envs/shared
terraform init
terraform plan

# Vérifier les outputs
terraform output ses_domain_identity_arn
terraform output cloudfront_certificate_arn
terraform output api_certificate_arn

# Pour dev/prod
cd envs/dev  # ou envs/prod
terraform init
terraform plan
```

---

## 6. Exemples complets

### Exemple `shared/terraform.tfvars`

```hcl
aws_region = "eu-central-1"
vpc_cidr = "10.0.0.0/16"
domain_name = "kambriq.com"

# SES (créé manuellement)
ses_domain = "kambriq.com"
ses_region = "eu-central-1"
ses_domain_identity_arn = "arn:aws:ses:eu-central-1:123456789012:identity/kambriq.com"
ses_from_email = "noreply@kambriq.com"
ses_email_identity_arn = "arn:aws:ses:eu-central-1:123456789012:identity/noreply@kambriq.com"

# ACM (créés manuellement)
api_acm_certificate_arn = "arn:aws:acm:eu-central-1:123456789012:certificate/abc123"
cloudfront_acm_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/def456"

enable_s3_logs = true
enable_s3_artifacts = true
```

### Exemple `prod/terraform.tfvars`

```hcl
aws_region = "eu-central-1"

# Domaines personnalisés
cloudfront_domain = "app.kambriq.com"
cloudfront_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/ghi789"

api_domain = "api.kambriq.com"
api_certificate_arn = "arn:aws:acm:eu-central-1:123456789012:certificate/jkl012"
```

---

## 7. Notes importantes

- ⚠️ **Ne jamais commiter les fichiers `terraform.tfvars`** dans Git (déjà dans `.gitignore`)
- ✅ **Utiliser les fichiers `.tfvars.example`** comme référence
- 🔒 **Les ARNs sont sensibles** - stockez-les dans un gestionnaire de secrets
- 📝 **Documenter les ARNs** dans un gestionnaire de secrets (Vault, LastPass, etc.)
- ⏱️ **Les certificats doivent être validés** avant de pouvoir être utilisés
- 🌍 **CloudFront nécessite us-east-1**, API Gateway nécessite eu-central-1

---

## 8. Dépannage

### Erreur : "Certificate not found"

- Vérifiez que l'ARN est correct
- Vérifiez que le certificat existe dans la bonne région :
  - CloudFront : **us-east-1**
  - API Gateway : **eu-central-1**

### Erreur : "Certificate not validated"

- Le certificat doit être dans l'état **"Issued"** (pas "Pending validation")
- Vérifiez que les enregistrements DNS de validation sont correctement configurés dans Route53

### Erreur : "SES identity not found"

- Vérifiez que l'ARN est correct
- Vérifiez que l'identité est **vérifiée** (status = "Verified")
- Vérifiez que vous êtes dans la bonne région (**eu-central-1**)

---

## 9. Références

- [Guide de configuration manuelle SES/ACM](./SES_AND_ACM_MANUAL_SETUP.md)
- [Guide d'usage Terraform](./TERRAFORM_USAGE.md)
- [Documentation Route53 DNS](./ROUTE53_DNS_SETUP.md)

