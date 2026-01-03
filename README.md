# KAMBRIQ AWS Infrastructure as Code (Terraform) - v2.0

Infrastructure Terraform modulaire pour l'application KAMBRIQ v2.0 sur AWS.

**✅ Migration V1 → V2 complétée** : L'ancienne stack serverless (Lambda + OpenNext + NestJS + API Gateway) a été supprimée. L'infrastructure actuelle utilise **ECS Fargate + ALB + CloudFront + FastAPI + Next.js**.

**⚠️ Important** : Ce repository gère **uniquement l'infrastructure AWS** (ECS, ALB, CloudFront, RDS, S3, SSM, IAM, VPC, etc.). Les déploiements applicatifs (mise à jour du code API + Web) sont gérés par les workflows `deploy-v2-dev.yml` dans le repository `kambriq`.

## 📚 Documentation

- **[Guide d'usage Terraform](docs/setup/TERRAFORM_USAGE.md)** - Guide complet pour utiliser ce dépôt
- **[Intégration avec l'application](docs/integration/APP_INTEGRATION.md)** - Comment l'app consomme les outputs Terraform
- **[Architecture V2](docs/architecture/)** - Documentation complète de l'architecture ECS Fargate

## Structure du projet

```
.
├── modules/              # Modules Terraform réutilisables
│   ├── shared/          # Ressources partagées (VPC, Route53, SES, ACM)
│   ├── rds-postgres/    # Base de données PostgreSQL
│   ├── ecs-cluster/     # ECS Cluster + CloudWatch Logs ⭐ V2
│   ├── ecs-service/     # ECS Task Definition + Service ⭐ V2
│   ├── alb/             # Application Load Balancer ⭐ V2
│   ├── cloudfront-v2/   # CloudFront Distribution (ALB origin) ⭐ V2
│   ├── iam-roles-ecs/   # IAM Roles pour ECS tasks ⭐ V2
│   ├── ecr-repository/  # ECR repositories (réutilisé)
│   ├── s3-media/        # Bucket S3 pour médias/documents
│   └── iam/             # Rôles et policies IAM
├── envs/                # Configurations par environnement
│   ├── shared/          # Stack shared (VPC, DNS, SES, ACM)
│   ├── dev-v2/          # Environnement de développement V2 ⭐
│   ├── prod-v2/         # Environnement de production V2 (à créer)
│   ├── dev/             # ⚠️ LEGACY - Ancienne stack V1 (supprimée)
│   └── prod/            # ⚠️ LEGACY - Ancienne stack V1 (à supprimer)
├── docs/                # Documentation organisée par usage
│   ├── architecture/    # Architecture V2 (ECS Fargate, ALB, CloudFront) ⭐
│   ├── setup/           # Guides de démarrage
│   ├── integration/     # Guides d'intégration
│   └── deployment/      # Guides de déploiement
└── versions.tf          # Contraintes de versions
```

## Architecture KAMBRIQ v2.0 – ECS Fargate + ALB

### Vue d'ensemble de l'architecture V2.0

L'architecture KAMBRIQ v2.0 utilise **ECS Fargate + ALB + CloudFront** pour remplacer l'ancienne stack serverless :

**Frontend :**
- **Next.js Classic** : Next.js 16 App Router avec SSR (standalone mode)
  - Déployé sur ECS Fargate (container)
  - CloudFront CDN devant ALB
  - Pas de Lambda, pas d'OpenNext
  - Support SSR/SSG/CSR hybride

**Backend :**
- **FastAPI** : Backend Python avec architecture clean
  - Déployé sur ECS Fargate (container)
  - JWT access token (15 min) + refresh token cookie (7 jours)
  - SQLAlchemy + Alembic pour la base de données
  - Compatible avec le schéma Prisma existant

**Load Balancing :**
- **ALB** : Application Load Balancer avec routing rules
  - `/api/*` → FastAPI Target Group (port 8000)
  - `/*` → Next.js Target Group (port 3000)
  - HTTPS avec ACM certificate

**Base de données :**
- **RDS PostgreSQL** : Instance dédiée t4g.micro (réutilisée)
  - 20GB gp3 storage
  - Backups automatiques (7j en dev, 30j en prod)
  - Accès via VPC privée depuis ECS

**Stockage :**
- **S3** : Buckets pour médias/documents
- **ECR** : Repositories pour images Docker (API + Web)

**Email :**
- **SES** : Amazon Simple Email Service (réutilisé)
  - Domain identity pour `kambriq.com`
  - Email identity pour `noreply@kambriq.com`

**Secrets & Configuration :**
- **SSM Parameter Store** : Stockage des secrets (réutilisé)
  - Mots de passe de base de données
  - Clés JWT
  - Variables d'environnement applicatives

**Réseau :**
- **VPC** : Réseau privé avec subnets publics/privés (réutilisé)
- **NAT Gateway** : 1 seul pour réduire les coûts (réutilisé)
- **Route53** : DNS pour `kambriq.com` (réutilisé)

> **✅ Migration complétée** : L'ancienne stack V1 (Lambda + OpenNext + NestJS + API Gateway) a été supprimée. L'infrastructure V2 est maintenant opérationnelle.

### Vue d'ensemble des stacks Terraform

L'infrastructure est organisée en **3 stacks Terraform** :

1. **`envs/shared`** : Ressources partagées entre tous les environnements
   - VPC avec public/private subnets + NAT Gateway (1 seul pour réduire les coûts)
   - Route53 hosted zone pour `kambriq.com`
   - SES domain identity
   - ACM certificates (ALB + CloudFront)
   - S3 buckets pour logs et artifacts

2. **`envs/dev-v2`** : Environnement de développement V2.0 ⭐
   - RDS PostgreSQL (instance dédiée)
   - ECS Cluster + Services (FastAPI + Next.js)
   - ALB avec routing rules (`/api/*` → FastAPI, `/*` → Next.js)
   - CloudFront Distribution (ALB origin)
   - ECR repositories (API + Web)
   - IAM roles pour ECS tasks
   - SSM Parameter Store pour secrets applicatifs (`/kambriq/dev/api/...`, `/kambriq/dev/web/...`)

3. **`envs/prod-v2`** : Environnement de production V2.0 (à créer)
   - RDS PostgreSQL (instance dédiée, backups 30 jours)
   - ECS Cluster + Services (FastAPI + Next.js)
   - ALB avec routing rules
   - CloudFront Distribution
   - ECR repositories
   - IAM roles pour ECS tasks
   - Domaines personnalisés (app.kambriq.com, api.kambriq.com)
   - SSM Parameter Store pour secrets applicatifs (`/kambriq/prod/api/...`, `/kambriq/prod/web/...`)

### Flux de déploiement

**IMPORTANT** : Le stack `shared` doit être déployé **EN PREMIER** avant `dev-v2` et `prod-v2`.

```bash
# 1. Déployer shared
cd envs/shared
terraform init
terraform plan
terraform apply

# 2. Déployer dev-v2
cd ../dev-v2
terraform init
terraform plan  # Lit les outputs de shared via remote_state
terraform apply

# 3. Déployer prod-v2 (quand prêt)
cd ../prod-v2
terraform init
terraform plan  # Lit les outputs de shared via remote_state
terraform apply
```

**⚠️ Note** : Les anciens stacks `envs/dev` et `envs/prod` (V1) ont été supprimés. Utilisez uniquement `envs/dev-v2` et `envs/prod-v2`.

### Ressources par stack

#### Stack Shared (`envs/shared`)
- **VPC** : 10.0.0.0/16 avec 2 public subnets + 2 private subnets
- **NAT Gateway** : 1 seul (dans une AZ publique) pour réduire les coûts
- **Route53** : Hosted zone pour `kambriq.com`
- **SES** : Domain identity + email identity (`noreply@kambriq.com`)
- **ACM** : Certificat wildcard `*.kambriq.com` pour API Gateway
- **S3** : Buckets pour logs et artifacts

#### Stack Dev V2 (`envs/dev-v2`)
- **RDS PostgreSQL** : t4g.micro, 20GB gp3, backups 7 jours
- **ECS Cluster** : Fargate avec Container Insights
- **ECS Service API** : FastAPI (port 8000, 256 CPU, 512 MB)
- **ECS Service Web** : Next.js (port 3000, 256 CPU, 512 MB)
- **ALB** : Application Load Balancer avec HTTPS (443) et redirect HTTP (80)
- **CloudFront** : Distribution avec origin ALB (`dev.kambriq.com`)
- **ECR** : Repositories pour images Docker (API + Web)
- **S3 Media** : Bucket pour médias/documents

#### Stack Prod V2 (`envs/prod-v2`) - À créer
- **RDS PostgreSQL** : t4g.micro, 20GB gp3, backups 30 jours
- **ECS Cluster** : Fargate avec Container Insights
- **ECS Service API** : FastAPI
- **ECS Service Web** : Next.js
- **ALB** : Application Load Balancer
- **CloudFront** : Distribution avec domaines personnalisés (`app.kambriq.com`, `api.kambriq.com`)
- **ECR** : Repositories pour images Docker
- **S3 Media** : Bucket pour médias/documents

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

#### 1. Workflow `terraform-validate-v2.yml` ⭐ V2 - Validation Terraform

Valide les configurations Terraform V2.

**Triggers :**
- **Pull Request** vers `main` ou `develop` : Validation uniquement
- **Push** vers `main` ou `develop` : Validation
- **Workflow Dispatch** : Validation manuelle

**Comportement :**
- Format check (`terraform fmt -check`)
- Validation (`terraform validate`)
- Plan (`terraform plan`) pour vérifier les changements
- Gère uniquement l'infrastructure V2 (ECS, ALB, CloudFront, RDS, etc.)

**Secrets requis :**
- `AWS_ACCESS_KEY_ID_DEV`
- `AWS_SECRET_ACCESS_KEY_DEV`
- `AWS_REGION_DEV`

**Note** : Les secrets applicatifs (DB password, JWT secrets) ne sont **pas** passés via GitHub Secrets. Ils sont gérés via SSM Parameter Store / Secrets Manager et configurés directement dans les variables d'environnement Lambda.

#### 2. Workflow `terraform-shared.yml` - Infrastructure partagée

Gère le stack `shared` (VPC, Route53, SES, ACM, S3 logs).

**Triggers :**
- **Pull Request vers `main`** : Exécute `terraform fmt`, `validate` et `plan`
- **Push vers `main`** : Exécute `terraform fmt`, `validate`, `plan` et `apply`

**Comportement :**
- Plan automatique sur les PRs (commentaire sur la PR)
- Apply automatique sur push vers main (si fichiers modifiés dans `envs/shared/` ou `modules/`)

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
   - Crée et configure les ressources AWS (ECS, ALB, CloudFront, RDS, S3, SSM, IAM, VPC, etc.)
   - Ne déploie **pas** le code applicatif

2. **Repository `kambriq`** :
   - **`deploy-v2-dev.yml`** : Déploiement applicatif V2 en DEV
     - Build Docker images (FastAPI + Next.js)
     - Push vers ECR
     - Update ECS services (rolling deployment)
     - Smoke tests

**Flux de déploiement :**

1. **Infrastructure** (ce repo) :
   - Modifier le code Terraform si nécessaire
   - Exécuter `terraform apply` dans `envs/dev-v2/` pour mettre à jour l'infrastructure

2. **Application** (repo `kambriq`) :
   - Modifier le code API (FastAPI) ou Web (Next.js)
   - Exécuter `deploy-v2-dev.yml` pour build, push ECR et déployer sur ECS

Voir [`docs/architecture/`](docs/architecture/) pour la documentation complète de l'architecture V2.

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

#### 2. Stack Dev V2

```bash
# 1. Se placer dans le répertoire dev-v2
cd envs/dev-v2

# 2. Créer le fichier terraform.tfvars à partir de l'exemple
cp terraform.tfvars.example terraform.tfvars

# 3. Éditer terraform.tfvars avec vos valeurs réelles
#    - Remplacer CHANGE_ME_SECURE_PASSWORD par un mot de passe fort
#    - Vérifier cloudfront_certificate_arn (déjà configuré par défaut)
#    Utiliser un gestionnaire de secrets (Vault, LastPass, 1Password, etc.)
#    ⚠️  Ne jamais commiter terraform.tfvars dans Git

# 4. Initialiser Terraform (télécharge les providers et configure le backend S3)
terraform init

# 5. Vérifier le plan d'exécution (optionnel mais recommandé)
terraform plan

# 6. Appliquer les changements
terraform apply
```

#### 3. Stack Prod V2 (À créer)

```bash
# 1. Se placer dans le répertoire prod-v2 (créer si nécessaire)
cd envs/prod-v2

# 2. Créer le fichier terraform.tfvars à partir de l'exemple
cp terraform.tfvars.example terraform.tfvars

# 3. Éditer terraform.tfvars avec vos valeurs réelles
#    - ⚠️  EN PRODUCTION : Utiliser OBLIGATOIREMENT un gestionnaire de secrets
#      (AWS Secrets Manager, HashiCorp Vault, etc.)
#    - Remplacer CHANGE_ME_SECURE_PASSWORD par un mot de passe fort
#    - Configurer cloudfront_certificate_arn (certificat us-east-1)
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

#### Stack Dev V2 (`envs/dev-v2`)

**CloudFront :**
- `cloudfront_domain` : Domain CloudFront Distribution

**ALB :**
- `alb_dns_name` : DNS name de l'ALB

**RDS :**
- `rds_endpoint` : Endpoint complet RDS (host:port)

**ECR :**
- `ecr_api_repo_uri` : URI ECR pour l'image API
- `ecr_web_repo_uri` : URI ECR pour l'image Web

**ECS :**
- `ecs_cluster_name` : Nom du cluster ECS
- `ecs_service_api_name` : Nom du service ECS API
- `ecs_service_web_name` : Nom du service ECS Web

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

## ✅ Migration V1 → V2 Complétée

**Date de migration :** 2025-01-XX  
**Status :** ✅ **COMPLÉTÉE**

### Ce qui a été fait

- [x] ✅ Infrastructure V1 supprimée (Lambda, OpenNext, NestJS, API Gateway)
- [x] ✅ Infrastructure V2 créée (ECS Fargate, ALB, CloudFront V2)
- [x] ✅ Modules Terraform V2 créés (ecs-cluster, alb, cloudfront-v2, iam-roles-ecs, ecs-service)
- [x] ✅ Configuration `envs/dev-v2/` créée
- [x] ✅ FastAPI backend implémenté (apps/api)
- [x] ✅ Next.js classic frontend (apps/web, no OpenNext)
- [x] ✅ CI/CD workflows V2 créés
- [x] ✅ Documentation V2 complète

### Prochaines étapes

- [ ] Déployer infrastructure shared (si pas déjà fait)
- [ ] Déployer infrastructure dev-v2
- [ ] Build et push images Docker (FastAPI + Next.js)
- [ ] Activer services ECS
- [ ] Tests de validation
- [ ] Créer configuration prod-v2
- [ ] Migration progressive vers V2 (canary)

Voir [`docs/architecture/CONTEXTE_WORKSPACE.md`](docs/architecture/CONTEXTE_WORKSPACE.md) pour le contexte complet du workspace et l'architecture V2.

## Coûts estimés (V2.0)

**Architecture V2 (ECS Fargate + ALB) :**
- ECS Fargate (2 tasks): ~$30-40/mois (256 CPU, 512 MB)
- ALB: ~$16/mois
- CloudFront: ~$5-10/mois
- RDS t4g.micro: ~$15/mois
- S3: ~$1-2/mois
- SES: Gratuit jusqu'à 62,000 emails/mois

**Total estimé V2: ~$66-81/mois** (1k-5k users, 10 req/s peak)

**Note :** V2 coûte plus cher que V1 mais offre meilleure performance (pas de cold start) et plus de flexibilité.

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

- **✅ Migration V1 → V2 complétée** : L'ancienne stack serverless a été supprimée. L'infrastructure V2 est maintenant opérationnelle.
- **Gestion des secrets** : Les secrets applicatifs (DB password, JWT secrets) sont gérés via SSM Parameter Store, **pas** via GitHub Secrets ou Terraform variables.
- **Stack shared en premier** : Le stack `shared` doit être déployé avant `dev-v2` et `prod-v2` car ces derniers dépendent de ses outputs.
- **VPC dédiée** : Une VPC dédiée est créée dans le stack `shared`.
- **NAT Gateway unique** : Un seul NAT Gateway est créé pour réduire les coûts (dans une AZ publique).
- **Documentation V2** : Voir `docs/architecture/` pour la documentation complète de l'architecture V2.
- **Modules legacy** : Les anciens modules V1 (`lambda-api`, `api-gateway`, `frontend`) ne sont plus utilisés. Utilisez les modules V2 (`ecs-cluster`, `alb`, `cloudfront-v2`, etc.).

