# Configuration manuelle ACM et SES – KAMBRIQ

Ce guide explique comment créer et configurer manuellement les certificats ACM et les identités SES dans la console AWS, puis comment fournir les ARNs à Terraform via les fichiers `terraform.tfvars`.

**⚠️ IMPORTANT** : Les certificats ACM et les identités SES ne sont **plus créés automatiquement** par Terraform. Ils doivent être créés et validés manuellement dans la console AWS avant de déployer l'infrastructure.

## 1. Pourquoi une configuration manuelle ?

- **ACM** : Les certificats nécessitent une validation DNS qui peut être complexe à automatiser
- **SES** : Les identités (domaine/email) nécessitent une vérification manuelle dans certains cas
- **Flexibilité** : Permet de gérer les certificats et identités indépendamment de Terraform
- **Sécurité** : Évite les problèmes de validation automatique qui peuvent échouer

## 2. Créer un certificat ACM pour API Gateway

### Prérequis

- Route53 hosted zone déjà créée (via Terraform `shared` stack)
- Domaine `kambriq.com` configuré avec les nameservers Route53

### Étapes

1. **Accéder à AWS Certificate Manager (ACM)**
   - Console AWS → **Certificate Manager**
   - Région : **eu-central-1** (obligatoire pour API Gateway)

2. **Demander un certificat**
   - Cliquez sur **"Request a certificate"**
   - Sélectionnez **"Request a public certificate"**
   - Domain names :
     - **FQDN** : `*.kambriq.com` (wildcard)
     - **Subject alternative names (SANs)** : `kambriq.com`
   - Validation method : **DNS validation**
   - Cliquez sur **"Request"**

3. **Valider le certificat via DNS**
   - ACM affiche les enregistrements DNS à créer
   - **Option 1 (Recommandé)** : Si Route53 est configuré, ACM peut créer automatiquement les enregistrements
     - Cliquez sur **"Create record in Route53"** pour chaque domaine
   - **Option 2** : Créer manuellement les enregistrements CNAME dans Route53
     - Copiez le nom et la valeur de chaque enregistrement
     - Créez les enregistrements CNAME dans la zone Route53

4. **Attendre la validation**
   - Le statut passe de **"Pending validation"** à **"Issued"**
   - Cela peut prendre quelques minutes à quelques heures

5. **Récupérer l'ARN du certificat**
   - Une fois validé, copiez l'**ARN** du certificat
   - Format : `arn:aws:acm:eu-central-1:123456789012:certificate/12345678-1234-1234-1234-123456789012`

### Configuration dans Terraform

Ajoutez l'ARN dans `envs/shared/terraform.tfvars` :

```terraform
api_acm_certificate_arn = "arn:aws:acm:eu-central-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"
```

## 3. Créer un certificat ACM pour CloudFront

### Prérequis

- Route53 hosted zone déjà créée
- Domaine configuré avec les nameservers Route53

### Étapes

1. **Accéder à AWS Certificate Manager (ACM)**
   - Console AWS → **Certificate Manager**
   - **⚠️ IMPORTANT** : Région **us-east-1** (obligatoire pour CloudFront)

2. **Demander un certificat**
   - Cliquez sur **"Request a certificate"**
   - Sélectionnez **"Request a public certificate"**
   - Domain names :
     - **FQDN** : `*.kambriq.com` (wildcard) ou `app.kambriq.com` (domaine spécifique)
     - **Subject alternative names (SANs)** : `kambriq.com` (si nécessaire)
   - Validation method : **DNS validation**
   - Cliquez sur **"Request"**

3. **Valider le certificat via DNS**
   - Même processus que pour API Gateway
   - Créez les enregistrements CNAME dans Route53 (même zone, même compte)

4. **Attendre la validation**
   - Le statut passe à **"Issued"**

5. **Récupérer l'ARN du certificat**
   - Copiez l'**ARN** du certificat
   - Format : `arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012`

### Configuration dans Terraform

Ajoutez l'ARN dans `envs/shared/terraform.tfvars` :

```terraform
cloudfront_acm_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"
```

**Note** : CloudFront nécessite un certificat dans **us-east-1**, même si votre infrastructure est dans **eu-central-1**.

## 4. Créer une identité SES (domaine)

### Prérequis

- Route53 hosted zone déjà créée
- Domaine `kambriq.com` configuré avec les nameservers Route53

### Étapes

1. **Accéder à Amazon SES**
   - Console AWS → **Simple Email Service (SES)**
   - Région : **eu-central-1**

2. **Créer une identité de domaine**
   - Onglet **"Verified identities"**
   - Cliquez sur **"Create identity"**
   - Type : **Domain**
   - Domain : `kambriq.com`
   - Configuration :
     - **DKIM signing** : Activé (recommandé)
     - **Easy DKIM** : Activé (recommandé)
   - Cliquez sur **"Create identity"**

3. **Valider le domaine via DNS**
   - SES affiche les enregistrements DNS à créer
   - **Option 1 (Recommandé)** : Si Route53 est configuré, SES peut créer automatiquement les enregistrements
     - Cliquez sur **"Use Route 53"** pour chaque enregistrement
   - **Option 2** : Créer manuellement les enregistrements dans Route53
     - **TXT** : `_amazonses.kambriq.com` → Token de vérification
     - **CNAME** (DKIM) : 3 enregistrements CNAME pour DKIM

4. **Attendre la validation**
   - Le statut passe de **"Pending verification"** à **"Verified"**
   - Cela peut prendre quelques minutes

5. **Récupérer l'ARN de l'identité**
   - Une fois vérifié, copiez l'**ARN** de l'identité
   - Format : `arn:aws:ses:eu-central-1:123456789012:identity/kambriq.com`

### Configuration dans Terraform

Ajoutez l'ARN et le domaine dans `envs/shared/terraform.tfvars` :

```terraform
ses_domain             = "kambriq.com"
ses_domain_identity_arn = "arn:aws:ses:eu-central-1:123456789012:identity/kambriq.com"
```

## 5. Créer une identité SES (email)

### Prérequis

- Identité de domaine SES créée (optionnel, mais recommandé)
- Email à vérifier : `noreply@kambriq.com`

### Étapes

1. **Accéder à Amazon SES**
   - Console AWS → **Simple Email Service (SES)**
   - Région : **eu-central-1**

2. **Créer une identité d'email**
   - Onglet **"Verified identities"**
   - Cliquez sur **"Create identity"**
   - Type : **Email address**
   - Email address : `noreply@kambriq.com`
   - Cliquez sur **"Create identity"**

3. **Valider l'email**
   - Un email de vérification est envoyé à `noreply@kambriq.com`
   - Ouvrez l'email et cliquez sur le lien de vérification
   - **Note** : Si le domaine est déjà vérifié, l'email peut être automatiquement vérifié

4. **Attendre la validation**
   - Le statut passe à **"Verified"**

5. **Récupérer l'ARN de l'identité**
   - Une fois vérifié, copiez l'**ARN** de l'identité
   - Format : `arn:aws:ses:eu-central-1:123456789012:identity/noreply@kambriq.com`

### Configuration dans Terraform

Ajoutez l'ARN et l'email dans `envs/shared/terraform.tfvars` :

```terraform
ses_from_email         = "noreply@kambriq.com"
ses_email_identity_arn = "arn:aws:ses:eu-central-1:123456789012:identity/noreply@kambriq.com"
```

## 6. Configuration complète dans terraform.tfvars

Exemple de configuration complète dans `envs/shared/terraform.tfvars` :

```terraform
# ============================================================================
# ACM Certificates (created manually in AWS Console)
# ============================================================================

# Certificate for API Gateway (must be in eu-central-1)
api_acm_certificate_arn = "arn:aws:acm:eu-central-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"

# Certificate for CloudFront (must be in us-east-1)
cloudfront_acm_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"

# ============================================================================
# SES Identities (created manually in AWS Console)
# ============================================================================

# SES domain (e.g., kambriq.com)
ses_domain = "kambriq.com"

# SES domain identity ARN
ses_domain_identity_arn = "arn:aws:ses:eu-central-1:123456789012:identity/kambriq.com"

# SES sender email address
ses_from_email = "noreply@kambriq.com"

# SES email identity ARN
ses_email_identity_arn = "arn:aws:ses:eu-central-1:123456789012:identity/noreply@kambriq.com"
```

## 7. Vérification

Après avoir configuré les ARNs dans `terraform.tfvars`, vérifiez que Terraform peut les utiliser :

```bash
cd envs/shared
terraform init
terraform plan
```

Les outputs suivants devraient afficher les ARNs configurés :

```bash
terraform output api_certificate_arn
terraform output cloudfront_certificate_arn
terraform output ses_domain_identity_arn
terraform output ses_email_identity_arn
```

## 8. Dépannage

### Erreur : "Certificate not found"

- Vérifiez que l'ARN est correct et que le certificat existe dans la bonne région
- Pour API Gateway : certificat doit être dans **eu-central-1**
- Pour CloudFront : certificat doit être dans **us-east-1**

### Erreur : "SES identity not found"

- Vérifiez que l'ARN est correct et que l'identité est **vérifiée** (status = "Verified")
- Vérifiez que vous êtes dans la bonne région (**eu-central-1**)

### Erreur : "Certificate not validated"

- Le certificat doit être dans l'état **"Issued"** (pas "Pending validation")
- Vérifiez que les enregistrements DNS de validation sont correctement configurés dans Route53

### Erreur : "SES domain not verified"

- Le domaine doit être dans l'état **"Verified"** (pas "Pending verification")
- Vérifiez que les enregistrements DNS (TXT, CNAME DKIM) sont correctement configurés dans Route53

## 9. Commandes utiles

### Récupérer les ARNs depuis AWS CLI

```bash
# Liste des certificats ACM (eu-central-1)
aws acm list-certificates --region eu-central-1

# Détails d'un certificat
aws acm describe-certificate \
  --certificate-arn "arn:aws:acm:eu-central-1:123456789012:certificate/..." \
  --region eu-central-1

# Liste des identités SES (eu-central-1)
aws ses list-identities --region eu-central-1

# Détails d'une identité SES
aws ses get-identity-verification-attributes \
  --identities "kambriq.com" "noreply@kambriq.com" \
  --region eu-central-1
```

### Vérifier le statut de validation

```bash
# Statut d'un certificat ACM
aws acm describe-certificate \
  --certificate-arn "arn:aws:acm:eu-central-1:123456789012:certificate/..." \
  --region eu-central-1 \
  --query 'Certificate.Status'

# Statut d'une identité SES
aws ses get-identity-verification-attributes \
  --identities "kambriq.com" \
  --region eu-central-1 \
  --query 'VerificationAttributes.kambriq.com.VerificationStatus'
```

## 10. Notes importantes

- ⚠️ **Ne modifiez pas les certificats ou identités SES créés manuellement** via Terraform
- ✅ **Les ARNs sont fournis via variables** dans `terraform.tfvars`
- ✅ **Terraform utilise ces ARNs** pour configurer API Gateway, CloudFront et les permissions IAM
- ⏱️ **La validation DNS peut prendre du temps** - soyez patient
- 🔒 **Les certificats et identités doivent être validés** avant de pouvoir être utilisés par Terraform

