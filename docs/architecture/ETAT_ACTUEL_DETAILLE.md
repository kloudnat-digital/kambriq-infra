# État Détaillé du Repo Infrastructure Terraform KAMBRIQ

**Date de génération :** 2025-12-07  
**Version Terraform :** >= 1.5.0  
**Provider AWS :** ~> 5.0  
**Région AWS :** eu-central-1

---

## 📋 Table des Matières

1. [Vue d'ensemble](#vue-densemble)
2. [Structure du Repository](#structure-du-repository)
3. [Stacks Terraform](#stacks-terraform)
4. [Modules Terraform](#modules-terraform)
5. [Workflows GitHub Actions](#workflows-github-actions)
6. [Backend Terraform](#backend-terraform)
7. [Gestion des Secrets](#gestion-des-secrets)
8. [Ressources Déployées](#ressources-déployées)
9. [Configuration par Environnement](#configuration-par-environnement)
10. [Code Legacy](#code-legacy)
11. [Documentation](#documentation)
12. [Points d'Attention](#points-dattention)

---

## 1. Vue d'ensemble

### 1.1 Architecture Générale

Le repo `kambriq-aws-iac-terraform` gère l'infrastructure AWS pour la plateforme KAMBRIQ via **Infrastructure as Code (IaC)** avec Terraform.

**Architecture MVP :** 100% serverless AWS
- **Frontend :** OpenNext (S3 static assets + CloudFront + Lambda SSR)
- **Backend :** Lambda + API Gateway (NestJS avec adaptateur Lambda)
- **Base de données :** RDS PostgreSQL (t4g.micro)
- **Stockage :** S3 (médias/documents + artefacts de build)
- **Email :** SES (Simple Email Service)
- **Réseau :** VPC avec subnets publics/privés + NAT Gateway

**⚠️ Migration récente (v3.1 - 2025-12-07) :**
- **Séparation complète** : Terraform gère uniquement l'infrastructure, déploiements applicatifs via workflows `deploy-app-*` dans le repo `kambriq`
- Frontend : Migration de static export vers **OpenNext** (SSR + Lambda)
- Backend : Adaptation NestJS pour **Lambda** (handler `dist/lambda.handler`)
- Secrets : Standardisation sur **SSM Parameter Store** (`/kambriq/{env}/{api|web}/...`)

### 1.2 Organisation des Stacks

L'infrastructure est organisée en **3 stacks Terraform** indépendants :

1. **`envs/shared`** - Infrastructure partagée (VPC, Route53, SES, ACM)
2. **`envs/dev`** - Environnement de développement
3. **`envs/prod`** - Environnement de production

**Ordre de déploiement obligatoire :** `shared` → `dev` → `prod`

---

## 2. Structure du Repository

```
kambriq-aws-iac-terraform/
├── .github/
│   └── workflows/
│       ├── terraform-shared.yml    # Workflow infrastructure partagée
│       ├── terraform-dev.yml       # Workflow environnement dev
│       └── terraform-prod.yml      # Workflow environnement prod
├── docs/
│   ├── architecture/               # Documentation architecture
│   ├── integration/                # Guides d'intégration
│   ├── maintenance/                # Documentation maintenance
│   ├── phase-2/                    # Documentation phase 2
│   └── setup/                      # Guides de démarrage
├── envs/
│   ├── shared/                     # Stack infrastructure partagée
│   │   ├── backend.tf
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── terraform.tfvars        # ⚠️ Non commité (gitignore)
│   │   └── terraform.tfvars.example
│   ├── dev/                        # Stack environnement dev
│   │   ├── backend.tf
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── terraform.tfvars        # ⚠️ Non commité (gitignore)
│   │   └── terraform.tfvars.example
│   └── prod/                       # Stack environnement prod
│       ├── backend.tf
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── terraform.tfvars        # ⚠️ Non commité (gitignore)
│       └── terraform.tfvars.example
├── modules/                        # Modules Terraform réutilisables
│   ├── shared/                     # Module infrastructure partagée
│   ├── rds-postgres/               # Module RDS PostgreSQL
│   ├── frontend/                   # Module Frontend OpenNext ⭐ NOUVEAU
│   ├── s3-media/                   # Module S3 médias/documents
│   ├── lambda-api/                 # Module Lambda API (handler: dist/lambda.handler)
│   ├── api-gateway/                # Module API Gateway
│   ├── iam/                        # Module IAM (rôles/policies)
│   ├── s3-static-site/             # ⚠️ LEGACY - Remplacé par modules/frontend/
│   └── cloudfront/                 # ⚠️ LEGACY - Remplacé par modules/frontend/
├── legacy/                         # Code legacy (non utilisé)
│   ├── modules/network/            # Ancien module réseau
│   ├── modules/ses/                # Ancien module SES
│   └── README.md
├── scripts/
│   └── generate-and-store-secrets.sh
├── versions.tf                     # Contraintes versions providers
└── README.md                       # Documentation principale
```

**Total fichiers Terraform :** 43 fichiers `.tf`

---

## 3. Stacks Terraform

### 3.1 Stack `shared` (Infrastructure Partagée)

**Localisation :** `envs/shared/`

**Ressources gérées :**
- ✅ **VPC** : 10.0.0.0/16 avec DNS support
- ✅ **Internet Gateway** : Accès internet public
- ✅ **Subnets publics** : 2 subnets (1 par AZ)
- ✅ **Subnets privés** : 2 subnets (1 par AZ)
- ✅ **NAT Gateway** : 1 seul (réduction coûts)
- ✅ **Route53** : Hosted zone (référence manuelle)
- ✅ **SES** : Domain identity + email identity (référence manuelle)
- ✅ **ACM** : Certificats API Gateway + CloudFront (référence manuelle)
- ✅ **S3** : Buckets logs + artifacts

**Backend :**
- **Bucket S3 :** `kloudnat-infra-shared-store`
- **State file :** `kambriq/shared/terraform.tfstate`
- **Région :** `eu-central-1`

**Variables principales :**
- `aws_region` : eu-central-1
- `vpc_cidr` : 10.0.0.0/16
- `domain_name` : kambriq.com
- `route53_zone_id` : (manuel)
- `ses_domain_identity_arn` : (manuel)
- `api_acm_certificate_arn` : (manuel)
- `cloudfront_acm_certificate_arn` : (manuel)

**Outputs exposés :**
- VPC ID, CIDR, subnets (public/private)
- NAT Gateway ID
- Route53 zone ID, name servers
- SES ARNs
- ACM certificate ARNs
- S3 buckets (logs, artifacts)

**Dépendances :** Aucune (stack racine)

---

### 3.2 Stack `dev` (Environnement Développement)

**Localisation :** `envs/dev/`

**Ressources gérées :**
- ✅ **RDS PostgreSQL** : t4g.micro, 20GB gp3
- ✅ **Lambda API** : Node.js 20.x, 512MB, 30s timeout
- ✅ **API Gateway** : HTTP API
- ✅ **S3 Static** : Bucket frontend Next.js
- ✅ **S3 Media** : Bucket médias/documents
- ✅ **CloudFront** : Distribution CDN frontend
- ✅ **IAM** : Rôles et policies Lambda
- ✅ **Security Groups** : RDS + Lambda

**Backend :**
- **Bucket S3 :** `kloudnat-infra-shared-store`
- **State file :** `kambriq/dev/terraform.tfstate`
- **Région :** `eu-central-1`

**Dépendances :**
- Consomme les outputs de `shared` via `terraform_remote_state`

**Configuration spécifique :**
- Backup retention : **7 jours**
- `skip_final_snapshot` : **true** (suppression sans snapshot)
- Domaines personnalisés : **Optionnels**

**Secrets (SSM Parameter Store) :**
- `/kambriq/dev/db/password` : Mot de passe RDS
- `/kambriq/dev/api/jwt_secret` : Clé secrète JWT

**Outputs exposés :**
- Frontend : CloudFront domain, S3 bucket name
- Media : S3 bucket names (public/private - même bucket actuellement)
- API : API Gateway base URL
- RDS : Endpoint, DB name, username
- SES : Domain identity ARN, sender email
- Lambda : Function name
- CloudFront : Distribution ID

---

### 3.3 Stack `prod` (Environnement Production)

**Localisation :** `envs/prod/`

**Ressources gérées :**
- ✅ **RDS PostgreSQL** : t4g.micro, 20GB gp3
- ✅ **Lambda API** : Node.js 20.x, 512MB, 30s timeout
- ✅ **API Gateway** : HTTP API
- ✅ **S3 Static** : Bucket frontend Next.js
- ✅ **S3 Media** : Bucket médias/documents
- ✅ **CloudFront** : Distribution CDN frontend
- ✅ **IAM** : Rôles et policies Lambda
- ✅ **Security Groups** : RDS + Lambda

**Backend :**
- **Bucket S3 :** `kloudnat-infra-shared-store`
- **State file :** `kambriq/prod/terraform.tfstate`
- **Région :** `eu-central-1`

**Dépendances :**
- Consomme les outputs de `shared` via `terraform_remote_state`

**Configuration spécifique :**
- Backup retention : **30 jours**
- `skip_final_snapshot` : **false** (toujours créer snapshot final)
- Domaines personnalisés : **Recommandés** (app.kambriq.com, api.kambriq.com)

**Secrets (SSM Parameter Store) :**
- `/kambriq/prod/db/password` : Mot de passe RDS
- `/kambriq/prod/api/jwt_secret` : Clé secrète JWT

**Outputs exposés :**
- Identiques à `dev` (même structure)

---

## 4. Modules Terraform

### 4.1 Module `shared`

**Localisation :** `modules/shared/`

**Ressources créées :**
- VPC, Internet Gateway, Subnets (public/private)
- NAT Gateway + Elastic IP
- Route Tables (public/private)
- Route53 hosted zone (référence)
- SES identities (référence)
- ACM certificates (référence)
- S3 buckets (logs, artifacts)

**Variables :**
- `project_name`, `aws_region`, `vpc_cidr`
- `domain_name`, `route53_zone_id`
- `ses_domain`, `ses_domain_identity_arn`, `ses_email_identity_arn`
- `api_acm_certificate_arn`, `cloudfront_acm_certificate_arn`
- `enable_s3_logs`, `enable_s3_artifacts`

**Outputs :**
- VPC, subnets, NAT Gateway
- Route53 zone ID, name servers
- SES ARNs
- ACM certificate ARNs
- S3 bucket IDs

---

### 4.2 Module `rds-postgres`

**Localisation :** `modules/rds-postgres/`

**Ressources créées :**
- RDS PostgreSQL instance
- DB Subnet Group
- DB Parameter Group (optionnel)

**Variables :**
- `env`, `db_name`, `db_username`, `db_password`
- `instance_class`, `allocated_storage`, `storage_type`
- `vpc_id`, `subnet_ids`, `security_group_id`
- `backup_retention_period`, `skip_final_snapshot`

**Outputs :**
- `db_host`, `db_port`, `db_name`, `db_username`

---

### 4.3 Module `frontend` ⭐ NOUVEAU

**Localisation :** `modules/frontend/`

**Ressources créées :**
- S3 bucket pour assets OpenNext statiques
- CloudFront distribution avec OAC (Origin Access Control)
- Lambda SSR function (placeholder, mis à jour via CI/CD)
- IAM roles et policies pour Lambda
- Bucket policies pour CloudFront

**Variables :**
- `env`, `project_name`
- `api_gateway_url` : URL de l'API Gateway pour configuration frontend

**Note** : Les variables `artifact_bucket_name` et `ssr_bundle_s3_key` ont été supprimées. Terraform gère uniquement l'infrastructure. Les déploiements applicatifs sont gérés par `deploy-app-dev.yml` et `deploy-app-prod.yml` dans le repo `kambriq`.

**Outputs :**
- `cloudfront_url`, `cloudfront_domain`, `cloudfront_distribution_id`
- `s3_bucket_id`, `s3_bucket_arn`
- `lambda_ssr_function_name`, `lambda_ssr_function_arn`

**Note:** Ce module remplace `modules/s3-static-site/` et `modules/cloudfront/` pour une gestion unifiée du frontend OpenNext.

---

### 4.4 Module `s3-static-site` ⚠️ LEGACY

**Localisation :** `modules/s3-static-site/`

**Status:** ⚠️ **LEGACY** - Remplacé par `modules/frontend/`

**Ressources créées :**
- S3 bucket pour frontend statique
- Bucket versioning, encryption
- Public access block

**Note:** Ce module n'est plus utilisé dans `envs/dev/` ou `envs/prod/`. Voir `modules/frontend/` pour la nouvelle architecture.

---

### 4.5 Module `s3-media`

**Localisation :** `modules/s3-media/`

**Ressources créées :**
- S3 bucket pour médias/documents
- Bucket versioning, encryption
- Public access block (privé par défaut)

**Variables :**
- `env`

**Outputs :**
- `bucket_id`, `bucket_arn`, `bucket_regional_domain_name`

**Note :** Actuellement, un seul bucket media existe. Les outputs `media_s3_public_bucket_name` et `media_s3_private_bucket_name` référencent le même bucket.

---

### 4.6 Module `cloudfront` ⚠️ LEGACY

**Localisation :** `modules/cloudfront/`

**Status:** ⚠️ **LEGACY** - Remplacé par `modules/frontend/`

**Ressources créées :**
- CloudFront distribution
- Origin Access Identity (OAI)
- Custom domain (optionnel)
- SSL certificate (optionnel)

**Note:** Ce module n'est plus utilisé dans `envs/dev/` ou `envs/prod/`. Voir `modules/frontend/` pour la nouvelle architecture OpenNext.

**Variables (legacy):**
- `env`, `s3_bucket_id`, `s3_bucket_regional_domain_name`
- `domain_name` (optionnel)
- `certificate_arn` (optionnel, doit être en us-east-1)

**Outputs :**
- `distribution_id`, `distribution_arn`, `distribution_domain_name`

---

### 4.6 Module `lambda-api`

**Localisation :** `modules/lambda-api/`

**Ressources créées :**
- Lambda function
- Lambda layer (optionnel)
- VPC configuration
- Environment variables

**Variables :**
- `env`, `runtime`, `handler`, `timeout`, `memory_size`
- `role_arn`, `vpc_id`, `subnet_ids`, `security_group_id`
- `db_host`, `db_port`, `db_name`, `db_username`, `db_password`
- `s3_media_bucket`, `ses_from_email`, `jwt_secret`

**Outputs :**
- `function_name`, `function_arn`, `function_invoke_arn`

**Note :** Le module contient un `dummy.zip` pour le déploiement initial.

---

### 4.7 Module `api-gateway`

**Localisation :** `modules/api-gateway/`

**Ressources créées :**
- API Gateway HTTP API
- Integration Lambda
- Custom domain (optionnel)
- SSL certificate (optionnel)

**Variables :**
- `env`, `lambda_function_arn`, `lambda_function_name`
- `domain_name` (optionnel)
- `certificate_arn` (optionnel, doit être en eu-central-1)

**Outputs :**
- `api_id`, `api_url`, `api_stage`

---

### 4.8 Module `iam`

**Localisation :** `modules/iam/`

**Ressources créées :**
- IAM role pour Lambda
- IAM policies :
  - Accès RDS (via security group)
  - Accès S3 media bucket
  - Accès SES (send email)

**Variables :**
- `env`
- `rds_security_group_id`
- `s3_media_bucket_arn`
- `ses_identity_arn`

**Outputs :**
- `lambda_role_arn`, `lambda_role_name`

---

## 5. Workflows GitHub Actions

### 5.1 Workflow `terraform-shared.yml`

**Déclencheurs :**
- **Pull Request** vers `main` → `terraform plan` uniquement
- **Push** vers `main` → `terraform plan` + `apply` automatique

**Fichiers surveillés :**
- `envs/shared/**`
- `modules/shared/**`
- `modules/**`
- `.github/workflows/terraform-shared.yml`

**Étapes :**
1. Checkout code
2. Configure AWS credentials (statiques)
3. Setup Terraform 1.5.0
4. Format check (`terraform fmt -check`)
5. Init Terraform
6. Validate Terraform
7. Plan Terraform
8. Comment PR avec plan (si PR)
9. Upload plan artifact (si PR)
10. Apply Terraform (si push vers main)
11. Output Terraform state
12. Display key outputs (VPC ID, Route53 Zone ID, Certificate ARN)
13. Upload outputs artifact

**Environnement :** Aucun (pas de protection)

---

### 5.2 Workflow `terraform-dev.yml` ⭐ SIMPLIFIÉ

**⚠️ Important** : Ce workflow gère **uniquement l'infrastructure**. Il ne déploie **pas** le code applicatif.

**Déclencheurs :**
- **Pull Request** vers `develop` → `terraform plan` uniquement (pas d'apply)
- **Push** vers `develop` → `terraform plan` + `apply` automatique
- **Workflow Dispatch** → `terraform plan` uniquement (manuel)

**Fichiers surveillés :**
- `envs/dev/**`
- `modules/**`
- `.github/workflows/terraform-dev.yml`

**Étapes :**
1. Checkout code
2. Configure AWS credentials (suffixe `_DEV`)
3. Setup Terraform 1.5.0
4. Init Terraform (`-input=false`)
5. Validate Terraform
6. Plan Terraform (condition : `if: github.event_name != 'push'`)
7. Plan Terraform avec output (condition : `if: github.event_name == 'push'`)
8. Upload Plan Artifact (si push)
9. Apply Terraform (condition : `if: github.event_name == 'push' && success()`)

**Environnement :** Aucun (pas de protection manuelle)

**Caractéristiques :**
- Gère uniquement l'infrastructure (Lambda functions créées, mais code non mis à jour)
- Plan sauvegardé comme artifact
- Apply automatique uniquement sur push `develop`
- Pas d'inputs nécessaires (simplifié)

---

### 5.3 Workflow `terraform-prod.yml` ⭐ SIMPLIFIÉ

**⚠️ Important** : Ce workflow gère **uniquement l'infrastructure**. Il ne déploie **pas** le code applicatif.

**Déclencheurs :**
- **Workflow Dispatch** uniquement (manuel)

**Fichiers surveillés :**
- `envs/prod/**`
- `modules/**`
- `.github/workflows/terraform-prod.yml`

**Job `terraform-prod` :**

**Environnement :** `production` (protection via GitHub Environment - approbation manuelle possible)

**Étapes :**
1. Checkout code
2. Configure AWS credentials (suffixe `_PROD`)
3. Setup Terraform 1.5.0
4. Init Terraform (`-input=false`)
5. Validate Terraform
6. Plan Terraform avec output (`-out=terraform.tfplan`)
7. Upload Plan Artifact (rétention 30 jours)
8. Apply Terraform (condition : `if: success()`)

**Caractéristiques :**
- Gère uniquement l'infrastructure (Lambda functions créées, mais code non mis à jour)
- Protection via GitHub Environment `production`
- Plan sauvegardé comme artifact (rétention 30 jours)
- Pas d'inputs nécessaires (simplifié)

**Environnement :** `production` (approbation manuelle possible mais commentée)

**Sécurité :**
- Plan toujours généré avant apply
- Apply conditionnel (pas automatique sur workflow_dispatch)
- Plan sauvegardé comme artifact pour review

---

### 5.4 Configuration AWS Credentials

**Méthode actuelle :** Credentials statiques (Option 2)

**Secrets GitHub requis :**
- `AWS_ACCESS_KEY_ID_DEV` / `AWS_ACCESS_KEY_ID_PROD`
- `AWS_SECRET_ACCESS_KEY_DEV` / `AWS_SECRET_ACCESS_KEY_PROD`
- `AWS_REGION_DEV` / `AWS_REGION_PROD` (optionnel, défaut: eu-central-1)

**Note** : Les secrets liés aux artefacts applicatifs ne sont plus nécessaires. Terraform gère uniquement l'infrastructure. Les déploiements applicatifs sont gérés par les workflows `deploy-app-dev.yml` et `deploy-app-prod.yml` dans le repository `kambriq`.

**Alternative disponible :** OIDC avec IAM Role (commenté dans les workflows)

---

## 6. Backend Terraform

### 6.1 Configuration Backend

**Type :** S3 backend

**Bucket :** `kloudnat-infra-shared-store`  
**Région :** `eu-central-1`

**State files :**
- `kambriq/shared/terraform.tfstate`
- `kambriq/dev/terraform.tfstate`
- `kambriq/prod/terraform.tfstate`

**Options commentées (non activées) :**
- `dynamodb_table` : Terraform state locking (DynamoDB)
- `encrypt` : Chiffrement du state

### 6.2 Remote State

Les stacks `dev` et `prod` consomment les outputs de `shared` via `terraform_remote_state` :

```hcl
data "terraform_remote_state" "shared" {
  backend = "s3"
  config = {
    bucket = "kloudnat-infra-shared-store"
    key    = "kambriq/shared/terraform.tfstate"
    region = "eu-central-1"
  }
}
```

---

## 7. Gestion des Secrets

### 7.1 Secrets Applicatifs

**⚠️ IMPORTANT :** Les secrets applicatifs ne sont **PAS** gérés par Terraform. Ils sont stockés dans SSM Parameter Store et lus au runtime par l'application.

**Structure de paths SSM :**
```
/kambriq/{dev|prod}/{api|web}/{parameter_name}
```

**Secrets API (stockés dans SSM) :**

**Dev :**
- `/kambriq/dev/api/DATABASE_URL` : URL de connexion PostgreSQL complète (SecureString)
- `/kambriq/dev/api/JWT_SECRET` : Clé secrète JWT (SecureString)
- `/kambriq/dev/api/FRONTEND_URL` : URL du frontend (String)
- `/kambriq/dev/api/SES_FROM_EMAIL` : Email expéditeur SES (String)

**Prod :**
- `/kambriq/prod/api/DATABASE_URL` : URL de connexion PostgreSQL complète (SecureString)
- `/kambriq/prod/api/JWT_SECRET` : Clé secrète JWT (SecureString)
- `/kambriq/prod/api/FRONTEND_URL` : URL du frontend (String)
- `/kambriq/prod/api/SES_FROM_EMAIL` : Email expéditeur SES (String)

**Secrets Web (optionnel, pour runtime SSR) :**
- `/kambriq/dev/web/...` (si nécessaire)
- `/kambriq/prod/web/...` (si nécessaire)

**Chargement au runtime :**
- **API (Lambda)** : Lit depuis SSM via `@aws-sdk/client-ssm` au démarrage (voir `api/src/infrastructure/config/config-loader.ts`)
  - Détecte l'environnement via `KAMBRIQ_ENV` (dev/prod)
  - En local : utilise `.env` (fichier local, non commité)
- **Web (SSR)** : Optionnel, via `web/src/lib/runtimeConfig.ts` si nécessaire

**GitHub Secrets :**
- Ne contiennent que des credentials techniques CI/CD (compte IAM, noms de Lambdas, buckets, IDs CloudFront)
- Ne contiennent **pas** les secrets métier (ceux-ci sont dans SSM)

### 7.2 Script de Génération

**Script disponible :** `scripts/generate-and-store-secrets.sh`

Permet de générer et stocker les secrets dans SSM Parameter Store avec la nouvelle structure de paths.

---

## 8. Ressources Déployées

### 8.1 Stack Shared

| Ressource | Type | Nom/ID | État |
|-----------|------|--------|------|
| VPC | aws_vpc | kambriq-vpc | ✅ Créé |
| Internet Gateway | aws_internet_gateway | kambriq-igw | ✅ Créé |
| Subnets Publics | aws_subnet | kambriq-public-{1,2} | ✅ Créés (2) |
| Subnets Privés | aws_subnet | kambriq-private-{1,2} | ✅ Créés (2) |
| NAT Gateway | aws_nat_gateway | kambriq-nat | ✅ Créé |
| Route53 Zone | Référence | (manuel) | ⚠️ Manuel |
| SES Domain | Référence | (manuel) | ⚠️ Manuel |
| SES Email | Référence | (manuel) | ⚠️ Manuel |
| ACM API Cert | Référence | (manuel) | ⚠️ Manuel |
| ACM CloudFront Cert | Référence | (manuel) | ⚠️ Manuel |
| S3 Logs | aws_s3_bucket | kambriq-logs-{hash} | ✅ Créé |
| S3 Artifacts | aws_s3_bucket | kambriq-artifacts-{hash} | ✅ Créé |

### 8.2 Stack Dev

| Ressource | Type | Nom/ID | État |
|-----------|------|--------|------|
| RDS PostgreSQL | aws_db_instance | kambriq-rds-dev | ✅ Créé |
| Lambda API | aws_lambda_function | kambriq-api-dev | ✅ Créé |
| API Gateway | aws_apigatewayv2_api | kambriq-api-dev | ✅ Créé |
| S3 Static | aws_s3_bucket | kambriq-static-dev-{hash} | ✅ Créé |
| S3 Media | aws_s3_bucket | kambriq-media-dev-{hash} | ✅ Créé |
| S3 Verify Store | aws_s3_bucket | kambriq-verify-store-dev | ✅ Créé |
| CloudFront | aws_cloudfront_distribution | kambriq-frontend-dev | ✅ Créé |
| IAM Role | aws_iam_role | kambriq-lambda-role-dev | ✅ Créé |
| Security Group RDS | aws_security_group | kambriq-rds-dev | ✅ Créé |
| Security Group Lambda | aws_security_group | kambriq-lambda-dev | ✅ Créé |

### 8.3 Stack Prod

| Ressource | Type | Nom/ID | État |
|-----------|------|--------|------|
| RDS PostgreSQL | aws_db_instance | kambriq-rds-prod | ✅ Créé |
| Lambda API | aws_lambda_function | kambriq-api-prod | ✅ Créé |
| API Gateway | aws_apigatewayv2_api | kambriq-api-prod | ✅ Créé |
| S3 Static | aws_s3_bucket | kambriq-static-prod-{hash} | ✅ Créé |
| S3 Media | aws_s3_bucket | kambriq-media-prod-{hash} | ✅ Créé |
| S3 Verify Store | aws_s3_bucket | kambriq-verify-store-prod | ✅ Créé |
| CloudFront | aws_cloudfront_distribution | kambriq-frontend-prod | ✅ Créé |
| IAM Role | aws_iam_role | kambriq-lambda-role-prod | ✅ Créé |
| Security Group RDS | aws_security_group | kambriq-rds-prod | ✅ Créé |
| Security Group Lambda | aws_security_group | kambriq-lambda-prod | ✅ Créé |

**Note :** Les états réels dépendent des déploiements effectués. Vérifier avec `terraform state list` dans chaque environnement.

---

## 9. Configuration par Environnement

### 9.1 Différences Dev vs Prod

| Configuration | Dev | Prod |
|---------------|-----|------|
| **RDS Backup Retention** | 7 jours | 30 jours |
| **RDS Final Snapshot** | skip (true) | create (false) |
| **Domaines personnalisés** | Optionnels | Recommandés |
| **Workflow Apply** | Auto | Manuel/Tag |
| **Environnement GitHub** | development | production |
| **SES Email** | noreply.dev@kambriq.com | noreply@kambriq.com |

### 9.2 Variables d'Environnement Lambda

**Dev :**
- `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USERNAME`, `DB_PASSWORD`
- `AWS_S3_BUCKET_NAME`
- `SES_FROM_EMAIL` : noreply.dev@kambriq.com
- `JWT_SECRET`

**Prod :**
- `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USERNAME`, `DB_PASSWORD`
- `AWS_S3_BUCKET_NAME`
- `SES_FROM_EMAIL` : noreply@kambriq.com
- `JWT_SECRET`

---

## 10. Code Legacy

### 10.1 Dossier `legacy/`

**Localisation :** `legacy/`

**Contenu :**
- `modules/network/` : Ancien module réseau (remplacé par `modules/shared`)
- `modules/ses/` : Ancien module SES (remplacé par `modules/shared`)
- `REFACTOR_PLAN.md` : Plan de refactoring (complété)

**Statut :** ❌ **NON UTILISÉ** - Conservé pour référence historique uniquement

**Action recommandée :** Peut être supprimé après validation complète.

---

## 11. Documentation

### 11.1 Structure Documentation

```
docs/
├── architecture/
│   ├── TERRAFORM_CURRENT_STATE.md
│   └── ETAT_ACTUEL_DETAILLE.md (ce document)
├── integration/
│   ├── APP_INTEGRATION.md
│   └── README.md
├── maintenance/
│   ├── CLEANUP_SUMMARY.md
│   └── README.md
├── phase-2/
│   └── phase-2.md
├── setup/
│   ├── ACM_SES_MANUAL_SETUP.md
│   ├── ROUTE53_DNS_SETUP.md
│   ├── TERRAFORM_TFVARS_EXAMPLE.md
│   ├── TERRAFORM_USAGE.md
│   └── README.md
├── SECRETS_GENERATION.md
└── TERRAFORM_TFVARS_GUIDE.md
```

### 11.2 Guides Principaux

1. **TERRAFORM_USAGE.md** : Guide complet d'utilisation Terraform
2. **APP_INTEGRATION.md** : Intégration avec le repo applicatif
3. **ACM_SES_MANUAL_SETUP.md** : Configuration manuelle SES/ACM
4. **ROUTE53_DNS_SETUP.md** : Configuration DNS Route53
5. **TERRAFORM_TFVARS_GUIDE.md** : Guide des variables tfvars

---

## 12. Points d'Attention

### 12.1 ⚠️ Configuration Manuelle Requise

**Ressources à créer manuellement dans AWS Console :**

1. **Route53 Hosted Zone** pour `kambriq.com`
   - Récupérer le `zone_id` et l'ajouter dans `envs/shared/terraform.tfvars`

2. **SES Domain Identity** pour `kambriq.com`
   - Vérifier via DNS
   - Récupérer l'ARN et l'ajouter dans `envs/shared/terraform.tfvars`

3. **SES Email Identity** pour `noreply@kambriq.com`
   - Vérifier via email
   - Récupérer l'ARN et l'ajouter dans `envs/shared/terraform.tfvars`

4. **ACM Certificate** pour API Gateway (eu-central-1)
   - Certificat wildcard `*.kambriq.com` ou spécifique
   - Récupérer l'ARN et l'ajouter dans `envs/shared/terraform.tfvars`

5. **ACM Certificate** pour CloudFront (us-east-1)
   - Certificat wildcard `*.kambriq.com` ou spécifique
   - Récupérer l'ARN et l'ajouter dans `envs/dev/terraform.tfvars` et `envs/prod/terraform.tfvars`

**⚠️ CRITIQUE :** Sans ces configurations manuelles, les déploiements échoueront ou les ressources ne seront pas complètes.

### 12.2 🔐 Gestion des Secrets

**Secrets à créer dans SSM Parameter Store :**

**Dev :**
```bash
aws ssm put-parameter \
  --name "/kambriq/dev/db/password" \
  --type "SecureString" \
  --value "CHANGE_ME_STRONG_PASSWORD"

aws ssm put-parameter \
  --name "/kambriq/dev/api/jwt_secret" \
  --type "SecureString" \
  --value "CHANGE_ME_JWT_SECRET_KEY"
```

**Prod :**
```bash
aws ssm put-parameter \
  --name "/kambriq/prod/db/password" \
  --type "SecureString" \
  --value "CHANGE_ME_STRONG_PASSWORD"

aws ssm put-parameter \
  --name "/kambriq/prod/api/jwt_secret" \
  --type "SecureString" \
  --value "CHANGE_ME_JWT_SECRET_KEY"
```

**⚠️ IMPORTANT :** Utiliser des mots de passe forts et uniques pour chaque environnement.

### 12.3 📝 Fichiers Non Commités

**Fichiers dans `.gitignore` :**
- `envs/*/terraform.tfvars` : Contiennent des secrets et configurations sensibles
- `envs/*/.terraform/` : Cache Terraform
- `envs/*/terraform.tfstate*` : State files (stockés dans S3)
- `envs/*/tfplan` : Plans Terraform

**⚠️ Ne jamais commiter ces fichiers.**

### 12.4 🔄 Ordre de Déploiement

**Ordre obligatoire :**
1. **Shared** → Déployer en premier
2. **Dev** → Dépend de Shared
3. **Prod** → Dépend de Shared

**Vérification :**
```bash
# Vérifier que shared est déployé
cd envs/shared
terraform state list

# Vérifier que les outputs sont disponibles
terraform output
```

### 12.5 💰 Optimisation Coûts

**Décisions prises pour réduire les coûts :**
- ✅ **1 seul NAT Gateway** (au lieu de 2) - Réduction ~$32/mois
- ✅ **RDS t4g.micro** - Instance la plus petite
- ✅ **20GB storage** - Minimum pour RDS
- ✅ **Backup retention 7j (dev)** - Minimum pour dev

**Coûts estimés MVP :**
- RDS t4g.micro : ~$15-20/mois
- Lambda : Pay-per-use (gratuit jusqu'à 1M requêtes/mois)
- API Gateway : Pay-per-use (gratuit jusqu'à 1M requêtes/mois)
- S3 : ~$0.023/Go/mois
- CloudFront : Pay-per-use (gratuit jusqu'à 1To/mois)
- SES : Gratuit jusqu'à 62,000 emails/mois
- **Total estimé : ~$20-30/mois** (hors trafic)

### 12.6 🚨 Sécurité Production

**Recommandations :**
- ✅ Activer l'approbation manuelle dans GitHub Environments pour `production`
- ✅ Toujours réviser le plan Terraform avant apply en prod
- ✅ Utiliser des secrets différents entre dev et prod
- ✅ Activer le versioning S3 pour le backend Terraform
- ✅ Activer le chiffrement du state Terraform
- ✅ Activer DynamoDB state locking (optionnel mais recommandé)

**Actions à faire :**
- [ ] Décommenter les lignes d'approbation manuelle dans `terraform-prod.yml`
- [ ] Activer `encrypt = true` dans les `backend.tf`
- [ ] Créer DynamoDB table pour state locking
- [ ] Activer versioning sur `kloudnat-infra-shared-store`

---

## 13. Prochaines Étapes Recommandées

### 13.1 Court Terme

- [ ] Vérifier que tous les secrets sont créés dans SSM Parameter Store
- [ ] Vérifier que les certificats ACM sont créés et validés
- [ ] Vérifier que Route53 hosted zone est configurée
- [ ] Activer l'approbation manuelle pour production
- [ ] Activer le chiffrement du state Terraform

### 13.2 Moyen Terme

- [ ] Ajouter des alarmes CloudWatch pour monitoring
- [ ] Configurer des backups automatiques RDS (déjà configuré : 7j dev, 30j prod)
- [ ] Migrer les secrets vers AWS Secrets Manager (actuellement SSM Parameter Store)
- [ ] Configurer des domaines personnalisés pour CloudFront et API Gateway (prod)
- [ ] Ajouter des règles de sécurité supplémentaires (WAF, etc.)

### 13.3 Long Terme

- [ ] Optimiser les coûts avec Reserved Instances ou Savings Plans (si applicable)
- [ ] Ajouter un certificat ACM pour CloudFront dans us-east-1 (si domaine personnalisé nécessaire)
- [ ] Implémenter des tests Terraform (terratest)
- [ ] Ajouter des validations de plan Terraform (policy as code)

---

## 14. Commandes Utiles

### 14.1 Vérifier l'État

```bash
# Lister les ressources déployées
cd envs/shared && terraform state list
cd envs/dev && terraform state list
cd envs/prod && terraform state list

# Voir les outputs
terraform output
terraform output -json

# Voir un output spécifique
terraform output -raw vpc_id
```

### 14.2 Déploiement Local

```bash
# Shared
cd envs/shared
terraform init
terraform plan
terraform apply

# Dev
cd envs/dev
terraform init
terraform plan
terraform apply

# Prod
cd envs/prod
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

### 14.3 Format et Validation

```bash
# Formater tous les fichiers
terraform fmt -recursive

# Valider la configuration
terraform validate
```

---

## 15. Conclusion

Le repo `kambriq-aws-iac-terraform` est **bien structuré** et suit les **meilleures pratiques Terraform** :

✅ **Points forts :**
- Architecture modulaire et réutilisable
- Séparation claire des environnements (shared/dev/prod)
- Gestion des secrets via SSM Parameter Store
- Workflows GitHub Actions automatisés
- Documentation complète

⚠️ **Points d'attention :**
- Configuration manuelle requise pour Route53, SES, ACM
- Secrets à créer manuellement dans SSM Parameter Store
- Approbation manuelle production à activer
- Chiffrement state Terraform à activer

🎯 **État global :** **Prêt pour déploiement** après configuration manuelle des prérequis.

---

**Dernière mise à jour :** 2025-12-05  
**Maintenu par :** Équipe Infrastructure KAMBRIQ

