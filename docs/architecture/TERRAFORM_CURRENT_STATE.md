# État Actuel de l'Architecture Terraform - KAMBRIQ

Ce document compare l'architecture Terraform actuellement déployée avec l'architecture cible MVP et identifie les écarts.

**Date de vérification** : 2025-12-07  
**Objectif MVP** : Architecture serverless AWS avec CloudFront en frontal, API Gateway + Lambda, RDS, S3, Route53, SES (hors Terraform), ACM (créé manuellement).

---

## 1. Cartographie des Ressources Terraform

### 1.1 CloudFront Distribution

| Ressource | Module | Environnement | État |
|-----------|-------|---------------|------|
| `aws_cloudfront_distribution.main` | `modules/frontend/main.tf` | dev, prod | ✅ Déployé (via module frontend) |

**Configuration actuelle** :
- ✅ Origin S3 pour le frontend
- ✅ OAC (Origin Access Control) configuré
- ✅ Certificat ACM via variable `certificate_arn` (optionnel)
- ❌ **MANQUE** : Origin pour API Gateway
- ❌ **MANQUE** : Cache behavior pour router `/api/*` vers API Gateway

**Localisation** : `modules/frontend/main.tf` (CloudFront intégré dans le module frontend OpenNext)

---

### 1.2 S3 Buckets

#### Frontend (Static Site)

| Ressource | Module | Environnement | État |
|-----------|-------|---------------|------|
| `aws_s3_bucket.main` | `modules/frontend/main.tf` | dev, prod | ✅ Déployé (via module frontend OpenNext) |

**Localisation** : `modules/frontend/main.tf` (S3 intégré dans le module frontend OpenNext)

#### Media

| Ressource | Module | Environnement | État |
|-----------|-------|---------------|------|
| `aws_s3_bucket.main` | `modules/s3-media/main.tf` | dev, prod | ✅ Déployé |

**Localisation** : `modules/s3-media/main.tf`

#### Logs & Artifacts (Shared)

| Ressource | Module | Environnement | État |
|-----------|-------|---------------|------|
| `aws_s3_bucket.logs` | `modules/shared/main.tf` | shared | ✅ Déployé (optionnel) |
| `aws_s3_bucket.artifacts` | `modules/shared/main.tf` | shared | ✅ Déployé (optionnel) |

**Localisation** : `modules/shared/main.tf` (lignes 190-249)

---

### 1.3 API Gateway HTTP API

| Ressource | Module | Environnement | État |
|-----------|-------|---------------|------|
| `aws_apigatewayv2_api.main` | `modules/api-gateway/main.tf` | dev, prod | ✅ Déployé |
| `aws_apigatewayv2_integration.lambda` | `modules/api-gateway/main.tf` | dev, prod | ✅ Déployé |
| `aws_apigatewayv2_route.default` | `modules/api-gateway/main.tf` | dev, prod | ✅ Déployé |
| `aws_apigatewayv2_route.proxy` | `modules/api-gateway/main.tf` | dev, prod | ✅ Déployé |
| `aws_apigatewayv2_stage.default` | `modules/api-gateway/main.tf` | dev, prod | ✅ Déployé |
| `aws_apigatewayv2_domain_name.main` | `modules/api-gateway/main.tf` | dev, prod | ⚠️ Optionnel (si `domain_name` fourni) |
| `aws_apigatewayv2_api_mapping.main` | `modules/api-gateway/main.tf` | dev, prod | ⚠️ Optionnel (si `domain_name` fourni) |

**Configuration actuelle** :
- ✅ HTTP API créé
- ✅ Intégration Lambda configurée
- ✅ Routes catch-all (`$default` et `ANY /{proxy+}`)
- ✅ Custom domain support (optionnel, via variables)
- ❌ **MANQUE** : Pas d'origine CloudFront configurée pour pointer vers cet API Gateway

**Localisation** : `modules/api-gateway/main.tf`

---

### 1.4 Lambda Function

| Ressource | Module | Environnement | État |
|-----------|-------|---------------|------|
| `aws_lambda_function.main` | `modules/lambda-api/main.tf` | dev, prod | ✅ Déployé |

**Localisation** : `modules/lambda-api/main.tf` (ligne 16)

---

### 1.5 RDS PostgreSQL

| Ressource | Module | Environnement | État |
|-----------|-------|---------------|------|
| `aws_db_instance.main` | `modules/rds-postgres/main.tf` | dev, prod | ✅ Déployé |

**Localisation** : `modules/rds-postgres/main.tf` (ligne 24)

---

### 1.6 Route53

| Ressource | Module | Environnement | État |
|-----------|-------|---------------|------|
| `aws_route53_zone.main` | `modules/shared/main.tf` | shared | ✅ Déployé |
| `aws_route53_record.*` | - | - | ❌ **AUCUN** enregistrement DNS créé |

**Configuration actuelle** :
- ✅ Hosted zone créée pour `kambriq.com`
- ❌ **MANQUE** : Enregistrements DNS pour CloudFront (A/AAAA alias)
- ❌ **MANQUE** : Enregistrements DNS pour API Gateway (si custom domain activé)

**Localisation** : `modules/shared/main.tf` (ligne 160)

---

### 1.7 SES (Simple Email Service)

| Ressource | Module | Environnement | État |
|-----------|-------|---------------|------|
| `aws_ses_*` | - | - | ✅ **AUCUNE** ressource Terraform (conforme MVP) |

**Configuration actuelle** :
- ✅ **CONFORME MVP** : Aucune ressource SES créée par Terraform
- ✅ Variables pour ARN SES (passées en input) : `ses_domain_identity_arn`, `ses_email_identity_arn`
- ✅ Outputs basés sur variables (pas de création)

**Note** : Module legacy dans `legacy/modules/ses/` mais non utilisé.

**Localisation** : Variables dans `modules/shared/variables.tf` (lignes 37-59), outputs dans `modules/shared/outputs.tf` (lignes 65-93)

---

### 1.8 ACM Certificates

| Ressource | Module | Environnement | État |
|-----------|-------|---------------|------|
| `aws_acm_certificate.*` | - | - | ✅ **AUCUNE** ressource Terraform (conforme MVP) |

**Configuration actuelle** :
- ✅ **CONFORME MVP** : Aucune ressource ACM créée par Terraform
- ✅ Variables pour ARN certificats (passées en input) :
  - `cloudfront_acm_certificate_arn` (us-east-1)
  - `api_acm_certificate_arn` (eu-central-1)
- ✅ CloudFront utilise `certificate_arn` via variable (optionnel)
- ✅ API Gateway utilise `certificate_arn` via variable (optionnel)

**Localisation** : Variables dans `modules/shared/variables.tf` (lignes 65-75), `modules/frontend/variables.tf` (certificat CloudFront), `modules/api-gateway/variables.tf` (ligne 22)

---

## 2. Écarts avec l'Architecture Cible MVP

### 2.1 ❌ ÉCART CRITIQUE : CloudFront ne route PAS `/api/*` vers API Gateway

**Architecture cible** :
```
Navigateur → CloudFront → S3 (frontend)
           → CloudFront → /api/* → API Gateway → Lambda
```

**Architecture actuelle** :
```
Navigateur → CloudFront → S3 (frontend uniquement)
           → API Gateway (accès direct via URL API Gateway, pas via CloudFront)
```

**Problème** :
- CloudFront n'a qu'un seul origin (S3)
- Aucun cache behavior pour `/api/*`
- Aucun origin configuré pour API Gateway

**Impact** :
- Le frontend ne peut pas appeler l'API via le même domaine (CORS plus complexe)
- Pas de cache edge pour les réponses API
- Pas de point d'entrée unique

**Solution requise** :
1. Ajouter un origin API Gateway dans le module CloudFront
2. Ajouter un cache behavior pour `/api/*` qui pointe vers cet origin
3. Configurer le behavior pour ne pas cacher les réponses API (ou avec TTL très court)

---

### 2.2 ⚠️ ÉCART MOYEN : Pas d'enregistrements Route53 pour CloudFront/API Gateway

**Architecture cible** :
- Route53 records pour `kambriq.com` → CloudFront (A/AAAA alias)
- Route53 records pour `api.kambriq.com` → API Gateway (si custom domain activé)

**Architecture actuelle** :
- ✅ Hosted zone créée
- ❌ Aucun enregistrement DNS créé

**Impact** :
- Les domaines personnalisés ne fonctionnent pas automatiquement
- Configuration manuelle requise dans Route53 ou via Terraform

**Solution requise** :
- Ajouter des ressources `aws_route53_record` pour :
  - CloudFront (si `cloudfront_domain` fourni)
  - API Gateway (si `api_domain` fourni)

---

### 2.3 ✅ CONFORME : Gestion SES

**Architecture cible** : SES créé manuellement, ARN passé en input  
**Architecture actuelle** : ✅ Aucune ressource SES créée par Terraform, variables pour ARN

**Statut** : ✅ **CONFORME MVP**

---

### 2.4 ✅ CONFORME : Gestion ACM

**Architecture cible** : Certificats créés manuellement, ARN passés en input  
**Architecture actuelle** : ✅ Aucune ressource ACM créée par Terraform, variables pour ARN

**Statut** : ✅ **CONFORME MVP**

---

### 2.5 ⚠️ ÉCART MINEUR : Variables tfvars incomplètes

**Architecture cible** : Variables pour certificats ACM dans tfvars  
**Architecture actuelle** : Variables existent mais sont commentées dans les `.tfvars.example`

**Impact** : Configuration manuelle requise après création des certificats

**Solution requise** : Documenter clairement dans les tfvars.example comment remplir ces valeurs

---

## 3. Plan de Refactoring

### 3.1 Priorité HAUTE : Ajouter le routing `/api/*` dans CloudFront

**Fichier à modifier** : `modules/frontend/main.tf` (module frontend OpenNext)

**Actions** :
1. Ajouter une variable `api_gateway_endpoint` dans `modules/frontend/variables.tf`
2. Ajouter un origin API Gateway dans la distribution CloudFront du module frontend :
   ```hcl
   origin {
     domain_name = var.api_gateway_endpoint
     origin_id   = "API-Gateway-${var.env}"
     
     custom_origin_config {
       http_port              = 80
       https_port             = 443
       origin_protocol_policy = "https-only"
       origin_ssl_protocols   = ["TLSv1.2"]
     }
   }
   ```
3. Ajouter un cache behavior pour `/api/*` :
   ```hcl
   ordered_cache_behavior {
     path_pattern     = "/api/*"
     allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
     cached_methods   = ["GET", "HEAD"]
     target_origin_id = "API-Gateway-${var.env}"
     
     forwarded_values {
       query_string = true
       headers      = ["Authorization", "Content-Type"]
       cookies {
         forward = "all"
       }
     }
     
     viewer_protocol_policy = "redirect-to-https"
     min_ttl                = 0
     default_ttl             = 0  # Pas de cache pour l'API
     max_ttl                 = 0
     compress                = true
   }
   ```
4. Passer l'endpoint API Gateway depuis `envs/dev/main.tf` et `envs/prod/main.tf`

**Fichiers à modifier** :
- `modules/frontend/variables.tf` (ajouter variable)
- `modules/frontend/main.tf` (ajouter origin + behavior dans CloudFront)
- `envs/dev/main.tf` (passer `api_gateway_endpoint` au module frontend)
- `envs/prod/main.tf` (passer `api_gateway_endpoint` au module frontend)

---

### 3.2 Priorité MOYENNE : Ajouter les enregistrements Route53

**Fichiers à créer/modifier** :
- `modules/frontend/outputs.tf` (exposer `distribution_domain_name` si nécessaire)
- `envs/dev/main.tf` (ajouter `aws_route53_record` pour CloudFront si domaine fourni)
- `envs/prod/main.tf` (ajouter `aws_route53_record` pour CloudFront si domaine fourni)

**Actions** :
1. Ajouter des ressources `aws_route53_record` conditionnelles dans `envs/dev/main.tf` et `envs/prod/main.tf` :
   ```hcl
   # Route53 record for CloudFront (if custom domain provided)
   resource "aws_route53_record" "cloudfront" {
     count   = var.cloudfront_domain != "" ? 1 : 0
     zone_id = data.terraform_remote_state.shared.outputs.route53_zone_id
     name    = var.cloudfront_domain
     type    = "A"
     
     alias {
       name                   = module.frontend.cloudfront_distribution_domain_name
       zone_id                = module.frontend.cloudfront_distribution_hosted_zone_id
       evaluate_target_health = false
     }
   }
   ```

2. Pour API Gateway (si custom domain activé), ajouter un record similaire.

**Note** : Vérifier que le module frontend expose `cloudfront_distribution_hosted_zone_id` dans ses outputs.

---

### 3.3 Priorité BASSE : Améliorer la documentation des tfvars

**Fichiers à modifier** :
- `envs/dev/terraform.tfvars.example`
- `envs/prod/terraform.tfvars.example`
- `envs/shared/terraform.tfvars.example`

**Actions** :
1. Ajouter des commentaires explicites sur comment obtenir les ARN des certificats
2. Ajouter des exemples de commandes AWS CLI pour récupérer les ARN
3. Documenter l'ordre de création (certificats → validation DNS → ajout dans tfvars)

---

## 4. Résumé Comparatif

| Composant | Architecture Cible | Architecture Actuelle | Écart | Priorité |
|-----------|-------------------|----------------------|-------|----------|
| **CloudFront → S3** | ✅ Frontend servi depuis S3 | ✅ Conforme | - | - |
| **CloudFront → API Gateway** | ✅ `/api/*` routé vers API Gateway | ❌ Manquant | **CRITIQUE** | **HAUTE** |
| **API Gateway → Lambda** | ✅ Intégration Lambda | ✅ Conforme | - | - |
| **RDS PostgreSQL** | ✅ Par environnement | ✅ Conforme | - | - |
| **S3 Media** | ✅ Par environnement | ✅ Conforme | - | - |
| **Route53 Zone** | ✅ Créée par Terraform | ✅ Conforme | - | - |
| **Route53 Records** | ✅ Records pour CF/API | ❌ Manquant | Moyen | MOYENNE |
| **SES** | ✅ Créé manuellement | ✅ Conforme (pas de ressource TF) | - | - |
| **ACM Certificates** | ✅ Créés manuellement | ✅ Conforme (pas de ressource TF) | - | - |
| **Variables tfvars** | ✅ Complètes | ⚠️ Partielles | Mineur | BASSE |

---

## 5. Actions Immédiates Requises

### 🔴 Priorité CRITIQUE (bloquant pour MVP)

1. **Ajouter le routing `/api/*` dans CloudFront**
   - Fichiers : `modules/frontend/main.tf`, `modules/frontend/variables.tf`
   - Impact : Sans cela, le frontend ne peut pas appeler l'API via CloudFront

### 🟡 Priorité MOYENNE (fonctionnel mais incomplet)

2. **Ajouter les enregistrements Route53**
   - Fichiers : `envs/dev/main.tf`, `envs/prod/main.tf`
   - Impact : Les domaines personnalisés ne fonctionnent pas automatiquement

### 🟢 Priorité BASSE (amélioration documentation)

3. **Améliorer la documentation des tfvars**
   - Fichiers : `envs/*/terraform.tfvars.example`
   - Impact : Facilité de configuration pour les nouveaux déploiements

---

## 6. Notes Techniques

### 6.1 CloudFront Origin pour API Gateway

Pour ajouter API Gateway comme origin dans CloudFront, il faut :
- L'endpoint régional de l'API Gateway (format : `{api-id}.execute-api.{region}.amazonaws.com`)
- Configurer comme `custom_origin_config` (pas `s3_origin_config`)
- Utiliser HTTPS uniquement

### 6.2 Cache Behavior pour `/api/*`

Recommandations :
- `default_ttl = 0` : Pas de cache pour les réponses API
- `forwarded_values.query_string = true` : Transmettre tous les query strings
- `forwarded_values.headers = ["Authorization", "Content-Type"]` : Transmettre les headers nécessaires
- `forwarded_values.cookies.forward = "all"` : Transmettre les cookies (pour l'authentification)

### 6.3 Route53 Records

Pour CloudFront :
- Type : `A` ou `AAAA` (alias)
- Alias target : Distribution CloudFront
- Zone ID CloudFront : `Z2FDTNDATAQYW2` (toujours la même pour toutes les distributions)

Pour API Gateway (custom domain) :
- Type : `A` (alias)
- Alias target : Domain name de l'API Gateway custom domain
- Zone ID : Dépend de la région (eu-central-1)

---

## 7. Références

- [Documentation CloudFront Origins](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution#origin)
- [Documentation CloudFront Cache Behaviors](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution#ordered_cache_behavior)
- [Documentation Route53 Records](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record)
- [Phase 2 Documentation](../phase-2/phase-2.md) - Architecture alternative avec `api.kambriq.com` direct

---

**Dernière mise à jour** : 2025-12-07  
**Prochaine révision** : Après implémentation du routing `/api/*` dans CloudFront

