# KAMBRIQ AWS Infrastructure as Code (Terraform)

Infrastructure Terraform modulaire pour l'application KAMBRIQ sur AWS.

**⚠️ Important** : Ce repository gère **uniquement l'infrastructure AWS** (Lambda, API Gateway, RDS, S3, CloudFront, SSM, IAM, VPC, etc.). Les déploiements applicatifs (mise à jour du code API + Web) sont gérés par les workflows optimisés `deploy-app-dev-optimized.yml` et `deploy-app-prod-optimized.yml` dans le repository `kambriq`.

## 📚 Documentation

- **[Guide d'usage Terraform](docs/setup/TERRAFORM_USAGE.md)** - Guide complet pour utiliser ce dépôt
- **[Intégration avec l'application](docs/integration/APP_INTEGRATION.md)** - Comment l'app consomme les outputs Terraform
- **[Résumé du nettoyage](docs/maintenance/CLEANUP_SUMMARY.md)** - Historique du nettoyage du dépôt

## Structure du projet

```
.
├── modules/              # Modules Terraform réutilisables
│   ├── shared/          # Ressources partagées (VPC, Route53, SES, ACM)
│   ├── rds-postgres/    # Base de données PostgreSQL
│   ├── frontend/         # Frontend OpenNext (S3 + CloudFront + Lambda SSR) ⭐
│   ├── s3-media/        # Bucket S3 pour médias/documents
│   ├── lambda-api/      # Fonction Lambda pour API NestJS (handler: dist/lambda.handler)
│   ├── api-gateway/     # API Gateway HTTP API
│   ├── iam/             # Rôles et policies IAM
│   ├── s3-static-site/  # ⚠️ LEGACY - Remplacé par modules/frontend/
│   └── cloudfront/      # ⚠️ LEGACY - Remplacé par modules/frontend/
├── envs/                # Configurations par environnement
│   ├── shared/          # Stack shared (VPC, DNS, SES, ACM)
│   ├── dev/             # Environnement de développement
│   └── prod/            # Environnement de production
├── docs/                # Documentation organisée par usage
│   ├── setup/           # Guides de démarrage (TERRAFORM_USAGE.md)
│   ├── integration/     # Guides d'intégration (APP_INTEGRATION.md)
│   └── maintenance/     # Documentation de maintenance
├── legacy/              # Modules et fichiers obsolètes (référence uniquement)
│   └── modules/         # Anciens modules (network, ses) - non utilisés
└── versions.tf          # Contraintes de versions
```

## Architecture MVP KAMBRIQ – Serverless AWS

### Vue d'ensemble de l'architecture MVP

Pour le MVP (v1.0.0), l'architecture retenue est **100 % serverless AWS** pour optimiser les coûts et simplifier l'opérationnel :

**Frontend :**
- **OpenNext** : Next.js 16 avec SSR sur AWS (S3 + CloudFront + Lambda)
  - S3 pour assets statiques (`.open-next/assets/`)
  - CloudFront CDN pour distribution globale
  - Lambda SSR pour rendu côté serveur (`.open-next/server/`)
  - Lambda@Edge pour optimisation d'images
  - Support ISR (Incremental Static Regeneration)
  - Coûts optimisés (pay-per-use)

**Backend :**
- **Lambda + API Gateway** : NestJS déployé comme fonction serverless
  - Lambda Node.js 20.x (512MB, 30s timeout)
  - Handler : `dist/lambda.handler` (adaptateur `@vendia/serverless-express`)
  - API Gateway HTTP API pour le routage (payload v2)
  - Auto-scaling selon la charge, pay-per-use
  - Optimisation cold start (cache de l'instance NestJS)

**Base de données :**
- **RDS PostgreSQL** : Instance dédiée t4g.micro
  - 20GB gp3 storage
  - Backups automatiques (7j en dev, 30j en prod)
  - Accès via VPC privée depuis Lambda

**Stockage :**
- **S3** : Buckets séparés pour :
  - Frontend OpenNext assets (public via CloudFront)
  - Médias/documents (privé, accès via API)
  - Artefacts de build (pour consommation par Terraform)

**Email :**
- **SES** : Amazon Simple Email Service
  - Domain identity pour `kambriq.com`
  - Email identity pour `noreply@kambriq.com`

**Secrets & Configuration :**
- **SSM Parameter Store / Secrets Manager** : Stockage des secrets
  - Mots de passe de base de données
  - Clés JWT
  - Secrets OAuth
  - **Jamais** dans Git ou Terraform outputs

**Réseau :**
- **VPC** : Réseau privé avec subnets publics/privés
- **NAT Gateway** : 1 seul pour réduire les coûts
- **Route53** : DNS pour `kambriq.com`

> **Note** : Pour le MVP (v1.0.0), l'architecture retenue est 100 % serverless AWS (Lambda + API Gateway + S3 + CloudFront + RDS). Une migration vers ECS/EKS pourra être envisagée plus tard en fonction de la montée en charge et des besoins spécifiques (WebSockets, long-running tasks, etc.).

### Vue d'ensemble des stacks Terraform

L'infrastructure est organisée en **3 stacks Terraform** :

1. **`envs/shared`** : Ressources partagées entre tous les environnements
   - VPC avec public/private subnets + NAT Gateway (1 seul pour réduire les coûts)
   - Route53 hosted zone pour `kambriq.com`
   - SES domain identity
   - ACM certificates (API Gateway)
   - S3 buckets pour logs et artifacts

2. **`envs/dev`** : Environnement de développement
   - RDS PostgreSQL (instance dédiée)
   - Lambda API + API Gateway (handler: `dist/lambda.handler`)
   - Frontend OpenNext (S3 + CloudFront + Lambda SSR)
   - S3 media bucket
   - IAM roles pour Lambda
   - SSM Parameter Store pour secrets applicatifs (`/kambriq/dev/api/...`, `/kambriq/dev/web/...`)

3. **`envs/prod`** : Environnement de production
   - RDS PostgreSQL (instance dédiée, backups 30 jours)
   - Lambda API + API Gateway (handler: `dist/lambda.handler`)
   - Frontend OpenNext (S3 + CloudFront + Lambda SSR)
   - S3 media bucket
   - IAM roles pour Lambda
   - Domaines personnalisés (app.kambriq.com, api.kambriq.com)
   - SSM Parameter Store pour secrets applicatifs (`/kambriq/prod/api/...`, `/kambriq/prod/web/...`)

### Flux de déploiement

**IMPORTANT** : Le stack `shared` doit être déployé **EN PREMIER** avant `dev` et `prod`.

```bash
# 1. Déployer shared
cd envs/shared
terraform init
terraform plan
terraform apply

# 2. Déployer dev
cd ../dev
terraform init
terraform plan  # Lit les outputs de shared via remote_state
terraform apply

# 3. Déployer prod
cd ../prod
terraform init
terraform plan  # Lit les outputs de shared via remote_state
terraform apply
```

### Ressources par stack

#### Stack Shared (`envs/shared`)
- **VPC** : 10.0.0.0/16 avec 2 public subnets + 2 private subnets
- **NAT Gateway** : 1 seul (dans une AZ publique) pour réduire les coûts
- **Route53** : Hosted zone pour `kambriq.com`
- **SES** : Domain identity + email identity (`noreply@kambriq.com`)
- **ACM** : Certificat wildcard `*.kambriq.com` pour API Gateway
- **S3** : Buckets pour logs et artifacts

#### Stack Dev (`envs/dev`)
- **RDS PostgreSQL** : t4g.micro, 20GB gp3, backups 7 jours
- **Lambda API** : Node.js 20.x, 512MB, 30s timeout
- **API Gateway** : HTTP API (URL par défaut ou `api-dev.kambriq.com`)
- **S3 Static** : Bucket pour frontend Next.js
- **S3 Media** : Bucket pour médias/documents
- **CloudFront** : Distribution pour frontend (URL par défaut ou `app-dev.kambriq.com`)

#### Stack Prod (`envs/prod`)
- **RDS PostgreSQL** : t4g.micro, 20GB gp3, backups 30 jours
- **Lambda API** : Node.js 20.x, 512MB, 30s timeout
- **API Gateway** : HTTP API avec domaine personnalisé (`api.kambriq.com`)
- **S3 Static** : Bucket pour frontend Next.js
- **S3 Media** : Bucket pour médias/documents
- **CloudFront** : Distribution avec domaine personnalisé (`app.kambriq.com`)

### Différences entre environnements

| Configuration | Dev | Prod |
|--------------|-----|------|
| Backup retention | 7 jours | 30 jours |
| Final snapshot | Non (skip_final_snapshot = true) | Oui (skip_final_snapshot = false) |
| Domaines personnalisés | Optionnel | Recommandé (app.kambriq.com, api.kambriq.com) |

## Déploiement

### Prérequis

1. Installer Terraform (>= 1.5.0)
2. Configurer les credentials AWS (via `aws configure` ou variables d'environnement)
3. Le backend S3 est configuré : `kloudnat-infra-shared-store` dans `eu-central-1`

## CI/CD

### Workflows GitHub Actions

Trois workflows GitHub Actions gèrent le déploiement de l'infrastructure :

#### Vue d'ensemble

**⚠️ Important** : Les workflows Terraform gèrent **uniquement l'infrastructure** (création/modification des ressources AWS). Ils ne déploient **pas** le code applicatif. Les déploiements applicatifs sont effectués par les workflows `deploy-app-dev.yml` et `deploy-app-prod-optimized.yml` dans le repository `kambriq`.

Les workflows Terraform sont configurés pour :
- **Développement** : Plan/Apply sur push vers `develop` ou déclenchement manuel
- **Production** : Déploiement manuel uniquement pour sécurité maximale
- **Validation** : Format check, validation, et plan avant chaque apply

### Workflows Terraform

#### 1. Workflow `terraform-dev-optimized.yml` ⭐ Optimisé (2025-12-15) - Environnement de développement

Gère le stack `dev` (infrastructure uniquement).

**Triggers :**
- **Pull Request** vers `develop` : Plan uniquement (pas d'apply)
- **Push** vers `develop` : Plan + Apply automatique
- **Workflow Dispatch** : Plan uniquement (manuel)

**Comportement :**
- Format check et validation avant chaque plan
- Plan généré et sauvegardé comme artifact
- Apply automatique uniquement sur push vers `develop`
- Gère uniquement l'infrastructure (Lambda, API Gateway, RDS, S3, CloudFront, SSM, IAM, VPC, etc.)
- **Ne déploie pas le code applicatif** (fait par `deploy-app-dev.yml` dans le repo `kambriq`)

**Secrets requis :**
- `AWS_ACCESS_KEY_ID_DEV`
- `AWS_SECRET_ACCESS_KEY_DEV`
- `AWS_REGION_DEV`

**Note** : Les secrets applicatifs (DB password, JWT secrets) ne sont **pas** passés via GitHub Secrets. Ils sont gérés via SSM Parameter Store / Secrets Manager et configurés directement dans les variables d'environnement Lambda.

#### 2. Workflow `terraform-prod-optimized.yml` ⭐ Optimisé (2025-12-15) - Environnement de production

Gère le stack `prod` (infrastructure uniquement) avec sécurité renforcée.

**Triggers :**
- **Workflow Dispatch** : Déclenchement manuel uniquement

**Comportement :**
- Terraform init, validate, plan et apply dans `envs/prod/`
- Protection via GitHub Environment `production` (approbation manuelle possible)
- Plan sauvegardé comme artifact (rétention 30 jours)
- Gère uniquement l'infrastructure (Lambda, API Gateway, RDS, S3, CloudFront, SSM, IAM, VPC, etc.)
- **Ne déploie pas le code applicatif** (fait par `deploy-app-prod-optimized.yml` dans le repo `kambriq`)

**Secrets requis :**
- `AWS_ACCESS_KEY_ID_PROD`
- `AWS_SECRET_ACCESS_KEY_PROD`
- `AWS_REGION_PROD`

**Note** : Les secrets applicatifs (DB password, JWT secrets) ne sont **pas** passés via GitHub Secrets. Ils sont gérés via SSM Parameter Store / Secrets Manager et configurés directement dans les variables d'environnement Lambda.

> **⚠️ Sécurité** : Le workflow prod nécessite une action explicite pour appliquer les changements. Toujours revoir le plan avant d'appliquer en production.

#### 3. Workflow `terraform-shared.yml` - Infrastructure partagée

Gère le stack `shared` (VPC, Route53, SES, ACM, S3 logs).

**Triggers :**
- **Pull Request vers `main`** : Exécute `terraform fmt`, `validate` et `plan`
- **Push vers `main`** : Exécute `terraform fmt`, `validate`, `plan` et `apply`

**Comportement :**
- Plan automatique sur les PRs (commentaire sur la PR)
- Apply automatique sur push vers main (si fichiers modifiés dans `envs/shared/` ou `modules/`)

**Pour lancer un apply en production :**

1. Aller dans l'onglet "Actions" du repository
2. Sélectionner "Terraform Prod (infra only)"
3. Cliquer sur "Run workflow"
4. Choisir la branche
5. ⚠️ Approbation manuelle requise (si configurée dans GitHub Environment `production`)
6. Cliquer sur "Run workflow"

⚠️ **Note** : Pour la production, il est recommandé d'activer l'approbation manuelle dans GitHub (Settings → Environments → production).

### Intégration avec le repo applicatif

**Séparation des responsabilités :**

1. **Repository `kambriq-aws-iac-terraform` (ce repo)** :
   - Gère **uniquement l'infrastructure** via Terraform
   - Crée et configure les ressources AWS (Lambda, API Gateway, RDS, S3, CloudFront, SSM, IAM, VPC, etc.)
   - Ne déploie **pas** le code applicatif

2. **Repository `kambriq`** :
   - **`ci.yml`** : CI global (lint, test, check-types)
   - **`build-artifacts.yml`** : Build et upload artefacts S3 (optionnel, pour consommation future)
   - **`deploy-app-dev.yml`** : Déploiement applicatif direct en DEV
     - Build API + Web, package en ZIP
     - `aws lambda update-function-code` (API + SSR)
     - Sync assets S3, invalidation CloudFront
   - **`deploy-app-prod-optimized.yml`** : Déploiement applicatif direct en PROD (même logique, avec protection `production`)

**Flux de déploiement :**

1. **Infrastructure** (ce repo) :
   - Modifier le code Terraform si nécessaire
   - Exécuter `terraform-dev-optimized.yml` ou `terraform-prod-optimized.yml` pour mettre à jour l'infrastructure

2. **Application** (repo `kambriq`) :
   - Modifier le code API ou Web
   - Exécuter `deploy-app-dev.yml` ou `deploy-app-prod-optimized.yml` pour déployer le nouveau code

Voir [`docs/integration/APP_INTEGRATION.md`](docs/integration/APP_INTEGRATION.md) pour les détails sur l'intégration. Voir aussi [`docs/setup/TERRAFORM_USAGE.md`](docs/setup/TERRAFORM_USAGE.md) pour un guide d'usage complet. Voir [`docs/architecture/CONTEXTE_WORKSPACE.md`](docs/architecture/CONTEXTE_WORKSPACE.md) pour une vue d'ensemble complète.

#### Configuration des secrets GitHub

Configurer les secrets suivants dans GitHub (Settings → Secrets and variables → Actions) :

**Option 1 : OIDC avec IAM Role (Recommandé)**
- `AWS_ROLE_ARN` : ARN du rôle IAM (ex: `arn:aws:iam::ACCOUNT_ID:role/github-actions-role`)
- `AWS_REGION` : `eu-central-1`

**Option 2 : Credentials statiques**
- `AWS_ACCESS_KEY_ID_DEV` / `AWS_ACCESS_KEY_ID_PROD` : Clé d'accès AWS
- `AWS_SECRET_ACCESS_KEY_DEV` / `AWS_SECRET_ACCESS_KEY_PROD` : Clé secrète AWS
- `AWS_REGION_DEV` / `AWS_REGION_PROD` : `eu-central-1`

**⚠️ Important** : Les secrets applicatifs (DB password, JWT secrets) ne sont **pas** stockés dans GitHub Secrets. Ils sont gérés via :

- **SSM Parameter Store** : Source de vérité pour les secrets runtime dev/prod
  - Structure de paths : `/kambriq/dev/api/...`, `/kambriq/dev/web/...`, `/kambriq/prod/api/...`, `/kambriq/prod/web/...`
  - Secrets stockés : `DATABASE_URL`, `JWT_SECRET`, `FRONTEND_URL`, `SES_FROM_EMAIL`, etc.
  - L'API et le Web (SSR) lisent depuis SSM au runtime via `@aws-sdk/client-ssm`
- **Local (.env)** : Utilisé uniquement pour le développement local sur la machine du développeur
- **GitHub Secrets** : Ne contiennent que des credentials techniques CI/CD (compte IAM, noms de Lambdas, buckets, IDs CloudFront)
- Les workflows Terraform ne gèrent que l'infrastructure, pas les secrets applicatifs

**⚠️ Bonnes pratiques de sécurité :**
- Les secrets applicatifs (DB password, JWT secrets) sont stockés dans SSM Parameter Store / Secrets Manager
- Ne jamais réutiliser les mêmes secrets entre dev et prod
- Utiliser des mots de passe forts et uniques pour chaque environnement
- Générer des JWT_SECRET d'au moins 32 caractères
- Les workflows Terraform ne manipulent pas les secrets applicatifs, uniquement l'infrastructure

**Configuration OIDC :**
1. Créer un OIDC provider dans AWS IAM (si pas déjà fait)
2. Créer un rôle IAM avec trust policy permettant GitHub Actions
3. Attacher les policies nécessaires au rôle (S3, Terraform state, etc.)
4. Configurer `AWS_ROLE_ARN` dans les secrets GitHub
5. Décommenter la section OIDC dans les workflows et commenter la section static credentials

**Note** : Actuellement, les workflows sont configurés pour utiliser l'**Option 2 (Credentials statiques)** par défaut. Pour passer à OIDC, suivez les instructions dans chaque workflow.

### Déploiement local

#### 1. Stack Shared (à déployer EN PREMIER)

```bash
# 1. Se placer dans le répertoire shared
cd envs/shared

# 2. Créer le fichier terraform.tfvars à partir de l'exemple
cp terraform.tfvars.example terraform.tfvars

# 3. Éditer terraform.tfvars si nécessaire (les valeurs par défaut sont généralement correctes)

# 4. Initialiser Terraform
terraform init

# 5. Vérifier le plan d'exécution
terraform plan

# 6. Appliquer les changements
terraform apply
```

#### 2. Stack Dev

```bash
# 1. Se placer dans le répertoire dev
cd envs/dev

# 2. Créer le fichier terraform.tfvars à partir de l'exemple
cp terraform.tfvars.example terraform.tfvars

# 3. Éditer terraform.tfvars avec vos valeurs réelles
#    - Remplacer CHANGE_ME_STRONG_PASSWORD par un mot de passe fort
#    - Remplacer CHANGE_ME_JWT_SECRET_KEY par une clé secrète JWT
#    Utiliser un gestionnaire de secrets (Vault, LastPass, 1Password, etc.)
#    ⚠️  Ne jamais commiter terraform.tfvars dans Git

# 4. Initialiser Terraform (télécharge les providers et configure le backend S3)
terraform init

# 5. Vérifier le plan d'exécution (optionnel mais recommandé)
terraform plan

# 6. Appliquer les changements
terraform apply
```

#### 3. Stack Prod

```bash
# 1. Se placer dans le répertoire prod
cd envs/prod

# 2. Créer le fichier terraform.tfvars à partir de l'exemple
cp terraform.tfvars.example terraform.tfvars

# 3. Éditer terraform.tfvars avec vos valeurs réelles
#    - ⚠️  EN PRODUCTION : Utiliser OBLIGATOIREMENT un gestionnaire de secrets
#      (AWS Secrets Manager, HashiCorp Vault, etc.)
#    - Remplacer CHANGE_ME_STRONG_PASSWORD par un mot de passe fort
#    - Remplacer CHANGE_ME_JWT_SECRET_KEY par une clé secrète JWT
#    - Optionnel : Configurer les domaines personnalisés (cloudfront_domain, api_domain)
#    ⚠️  Ne jamais commiter terraform.tfvars dans Git

# 4. Initialiser Terraform
terraform init

# 5. Vérifier le plan d'exécution (OBLIGATOIRE en production)
terraform plan

# 6. Appliquer les changements
#    ⚠️  En production, le déploiement se fait principalement via GitHub Actions
#    pour garantir la traçabilité et la sécurité
terraform apply
```

**Note** : Les fichiers `terraform.tfvars` sont ignorés par git (`.gitignore`) pour des raisons de sécurité. Ils contiennent des secrets et ne doivent jamais être commités.

## Outputs Terraform

Les outputs Terraform fournissent les informations nécessaires pour configurer l'application. Pour les consulter :

```bash
cd envs/dev  # ou envs/prod
terraform output
```

**📚 Documentation complète** : Voir [`docs/integration/APP_INTEGRATION.md`](docs/integration/APP_INTEGRATION.md) pour :
- Le mapping complet entre outputs Terraform et variables d'environnement de l'application
- Comment intégrer les outputs dans les pipelines CI/CD
- La gestion des secrets via SSM Parameter Store

### Outputs disponibles

#### Stack Shared (`envs/shared`)

**VPC & Networking :**
- `vpc_id` : ID de la VPC
- `vpc_cidr` : CIDR block de la VPC
- `public_subnet_ids` : Liste des IDs des subnets publics
- `private_subnet_ids` : Liste des IDs des subnets privés
- `all_subnet_ids` : Liste de tous les subnets (public + private)
- `nat_gateway_id` : ID du NAT Gateway

**Route53 :**
- `route53_zone_id` : ID de la hosted zone
- `route53_zone_name` : Nom de la hosted zone
- `route53_name_servers` : Serveurs DNS (à configurer dans le registrar)

**SES :**
- `ses_domain_identity_arn` : ARN de l'identité domaine SES
- `ses_email_identity_arn` : ARN de l'identité email SES
- `ses_from_email` : Adresse email par défaut
- `ses_domain_verification_token` : Token de vérification DNS

**ACM :**
- `api_certificate_arn` : ARN du certificat pour API Gateway

**S3 :**
- `logs_bucket_id` : ID du bucket S3 pour logs
- `artifacts_bucket_id` : ID du bucket S3 pour artifacts

#### Stack Dev/Prod (`envs/dev` et `envs/prod`)

**AWS Region :**
- `region` : Région AWS (ex: `eu-central-1`)

**Frontend :**
- `frontend_cloudfront_url` : URL complète CloudFront (https://...)
- `frontend_cloudfront_domain` : Nom de domaine CloudFront
- `frontend_s3_bucket_name` : Nom du bucket S3 pour les assets OpenNext

**Media S3 :**
- `media_s3_public_bucket_name` : Nom du bucket S3 pour les médias publics
- `media_s3_private_bucket_name` : Nom du bucket S3 pour les médias privés
- **Note** : Actuellement, les deux référencent le même bucket

**API Gateway :**
- `api_gateway_base_url` : URL complète de l'API Gateway (https://...)

**Base de données :**
- `rds_endpoint` : Endpoint complet RDS (host:port)
- `rds_db_name` : Nom de la base de données
- `rds_username` : Nom d'utilisateur de la base de données (**sensible**)

**SES :**
- `ses_domain_identity_arn` : ARN de l'identité domaine SES (depuis shared)
- `ses_from_email` : Adresse email par défaut pour l'envoi (depuis shared)

**Lambda :**
- `lambda_function_name` : Nom de la fonction Lambda API
- `lambda_function_arn` : ARN de la fonction Lambda API
- `lambda_handler` : Handler Lambda (ex: `dist/lambda.handler`)
- `cloudfront_distribution_id` : ID de la distribution CloudFront (pour invalidation de cache)

### Utilisation dans le repo applicatif

Ces outputs peuvent être récupérés via `terraform output -json` et utilisés pour configurer l'application :

```bash
# Exporter les outputs en JSON
terraform output -json > terraform-outputs.json

# Ou récupérer une valeur spécifique
terraform output -raw api_url
terraform output -raw db_endpoint
```

## Backend Terraform (État)

L'état Terraform est stocké dans S3 : `kloudnat-infra-shared-store`

- **Shared** : `kambriq/shared/terraform.tfstate`
- **Dev** : `kambriq/dev/terraform.tfstate`
- **Prod** : `kambriq/prod/terraform.tfstate`

Région : `eu-central-1`

La configuration est déjà définie dans `envs/*/backend.tf`.

**Important** : Les stacks `dev` et `prod` consomment les outputs du stack `shared` via `terraform_remote_state`. Assurez-vous que le stack `shared` est déployé et que son état est accessible avant de déployer `dev` ou `prod`.

## TODO

- [x] Migrer l'état Terraform vers S3 backend
- [x] Créer une structure shared/dev/prod avec remote_state
- [x] Créer des workflows GitHub Actions séparés par stack
- [x] Séparer les secrets entre dev et prod
- [x] Créer les workflows de déploiement applicatif (deploy-dev.yml)
- [ ] Ajouter des alarmes CloudWatch pour monitoring
- [ ] Configurer des backups automatiques pour RDS (déjà configuré : 7j dev, 30j prod)
- [ ] Migrer les secrets vers AWS Secrets Manager (actuellement SSM Parameter Store)
- [ ] Configurer des domaines personnalisés pour CloudFront et API Gateway (prod) - optionnel
- [ ] Ajouter des règles de sécurité supplémentaires (WAF, etc.)
- [ ] Optimiser les coûts avec Reserved Instances ou Savings Plans (si applicable)
- [ ] Ajouter un certificat ACM pour CloudFront dans us-east-1 (si domaine personnalisé nécessaire)

> **Note** : Pour le MVP (v1.0.0), l'architecture retenue est 100 % serverless AWS (Lambda + API Gateway + S3 + CloudFront + RDS). Une migration vers ECS/EKS pourra être envisagée plus tard en fonction de la montée en charge et des besoins spécifiques (WebSockets, long-running tasks, etc.).

## Coûts estimés (MVP)

- RDS t4g.micro: ~$15-20/mois
- Lambda: Pay-per-use (gratuit jusqu'à 1M requêtes/mois)
- API Gateway: Pay-per-use (gratuit jusqu'à 1M requêtes/mois)
- S3: ~$0.023/Go/mois
- CloudFront: Pay-per-use (gratuit jusqu'à 1To/mois)
- SES: Gratuit jusqu'à 62,000 emails/mois

Total estimé MVP: ~$20-30/mois (hors trafic)

## Architecture technique

### Remote State

Les stacks `dev` et `prod` consomment les outputs du stack `shared` via `terraform_remote_state` :

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

Cela permet de :
- Réutiliser la VPC, Route53, SES créés dans `shared`
- Éviter la duplication de ressources
- Maintenir une séparation claire entre ressources partagées et spécifiques

### Workflows GitHub Actions

Le repository utilise **3 workflows séparés** pour une meilleure organisation :

1. **`terraform-shared.yml`** : Gère uniquement le stack shared
2. **`terraform-dev-optimized.yml`** : Gère uniquement le stack dev
3. **`terraform-prod-optimized.yml`** : Gère uniquement le stack prod (déclenchement manuel)

Chaque workflow :
- Vérifie le format avec `terraform fmt -check`
- Valide la configuration avec `terraform validate`
- Génère un plan avec `terraform plan`
- Applique les changements (selon les conditions définies)
- Commente automatiquement les PRs avec le plan Terraform
- Sauvegarde les outputs comme artifacts

## Notes importantes

- **Gestion des secrets** : Les secrets applicatifs (DB password, JWT secrets) sont gérés via SSM Parameter Store / Secrets Manager, **pas** via GitHub Secrets ou Terraform variables. Les workflows Terraform ne manipulent que l'infrastructure.
- **Stack shared en premier** : Le stack `shared` doit être déployé avant `dev` et `prod` car ces derniers dépendent de ses outputs.
- **VPC dédiée** : Une VPC dédiée est créée dans le stack `shared` (plus de VPC par défaut).
- **NAT Gateway unique** : Un seul NAT Gateway est créé pour réduire les coûts (dans une AZ publique).
- **Documentation organisée** : La documentation est organisée par usage dans `docs/setup/`, `docs/integration/`, et `docs/maintenance/`.
- **Modules legacy** : Les anciens modules (`network`, `ses`) ont été déplacés dans `legacy/` et ne sont plus utilisés.
- **Coûts** : Les ressources sont configurées pour minimiser les coûts tout en restant fonctionnelles.

