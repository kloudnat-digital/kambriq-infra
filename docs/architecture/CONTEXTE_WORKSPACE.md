# Contexte du Workspace KAMBRIQ

**Date de création :** 2025-01-27  
**Dernière mise à jour :** 2025-12-07  
**Version :** 3.1 (Séparation infrastructure/applicatif - SSM Parameter Store - Déploiements directs - Outils CLI)

---

## 📋 Vue d'ensemble

Le workspace KAMBRIQ contient **2 repositories distincts** qui travaillent ensemble pour déployer une plateforme complète sur AWS :

1. **`kambriq-aws-iac-terraform`** - Infrastructure as Code (Terraform)
2. **`kambriq`** - Application monorepo (API + Web)

---

## 🏗️ Repository 1 : `kambriq-aws-iac-terraform`

### Description
Infrastructure AWS gérée via Terraform pour la plateforme KAMBRIQ.

### Architecture
**100% serverless AWS** pour optimiser les coûts :
- **Frontend** : OpenNext (S3 static assets + CloudFront + Lambda SSR)
- **Backend** : Lambda + API Gateway (NestJS avec adaptateur Lambda)
- **Base de données** : RDS PostgreSQL (t4g.micro)
- **Stockage** : S3 (médias/documents + artefacts de build)
- **Email** : SES (Simple Email Service)
- **Réseau** : VPC avec subnets publics/privés + NAT Gateway

**⚠️ Migration récente (2025-12-07) :**
- **Séparation complète** : Terraform gère uniquement l'infrastructure, déploiements applicatifs via workflows `deploy-app-*` dans le repo `kambriq`
- Frontend : Migration de static export vers **OpenNext** (SSR + Lambda)
- Backend : Adaptation NestJS pour **Lambda** (handler `dist/lambda.handler`)
- Secrets : Standardisation sur **SSM Parameter Store** (`/kambriq/{env}/{api|web}/...`)

### Structure des Stacks (3 stacks indépendants)

#### 1. `envs/shared/` - Infrastructure Partagée
**Ressources gérées :**
- ✅ VPC : 10.0.0.0/16 avec DNS support
- ✅ Internet Gateway
- ✅ Subnets publics : 2 subnets (1 par AZ)
- ✅ Subnets privés : 2 subnets (1 par AZ)
- ✅ NAT Gateway : 1 seul (réduction coûts)
- ✅ Route53 : Hosted zone (référence manuelle)
- ✅ SES : Domain identity + email identity (référence manuelle)
- ✅ ACM : Certificats API Gateway + CloudFront (référence manuelle)
- ✅ CloudFront : Distributions avec alias gérés par Terraform (`dev.kambriq.com` en dev, `kambriq.com` en prod)
- ✅ S3 : Buckets logs + artifacts

**Backend :**
- Bucket S3 : `kloudnat-infra-shared-store`
- State file : `kambriq/shared/terraform.tfstate`
- Région : `eu-central-1`

**⚠️ Configuration manuelle requise :**
- Route53 hosted zone (récupérer zone_id)
- SES domain/email identities (récupérer ARNs)
- ACM certificates (API Gateway: eu-central-1, CloudFront: us-east-1)

#### 2. `envs/dev/` - Environnement Développement
**Ressources gérées :**
- ✅ RDS PostgreSQL : t4g.micro, 20GB gp3
- ✅ Lambda API : Node.js 20.x, 512MB, 30s timeout (handler: `dist/lambda.handler`)
- ✅ API Gateway : HTTP API
- ✅ Frontend OpenNext : S3 static assets + CloudFront + Lambda SSR
- ✅ S3 Media : Bucket médias/documents
- ✅ S3 Verify Store : Bucket documents de vérification (protégé contre la suppression)
- ✅ IAM : Rôles et policies Lambda
- ✅ Security Groups : RDS + Lambda

**Note** : Les variables d'artefacts S3 applicatifs (`api_bundle_s3_key`, `ssr_bundle_s3_key`) ne sont plus utilisées. Terraform gère uniquement l'infrastructure. Les déploiements applicatifs sont effectués via les workflows `deploy-app-dev.yml` et `deploy-app-prod.yml` dans le repository `kambriq`.

**Backend :**
- Bucket S3 : `kloudnat-infra-shared-store`
- State file : `kambriq/dev/terraform.tfstate`

**Configuration spécifique :**
- Backup retention : **7 jours**
- `skip_final_snapshot` : **true**
- Domaines personnalisés : **Optionnels**

**Secrets (SSM Parameter Store) :**
- `/kambriq/dev/api/DATABASE_URL`
- `/kambriq/dev/api/JWT_SECRET`
- `/kambriq/dev/api/FRONTEND_URL`
- `/kambriq/dev/api/SES_FROM_EMAIL`
- `/kambriq/dev/web/...` (optionnel, pour runtime SSR)

#### 3. `envs/prod/` - Environnement Production
**Ressources gérées :**
- Identiques à `dev` (même structure)
- ✅ S3 Verify Store : Bucket documents de vérification (protégé contre la suppression)

**Configuration spécifique :**
- Backup retention : **30 jours**
- `skip_final_snapshot` : **false**
- Domaines personnalisés : **Recommandés** (app.kambriq.com, api.kambriq.com)

**Secrets (SSM Parameter Store) :**
- `/kambriq/prod/api/DATABASE_URL`
- `/kambriq/prod/api/JWT_SECRET`
- `/kambriq/prod/api/FRONTEND_URL`
- `/kambriq/prod/api/SES_FROM_EMAIL`
- `/kambriq/prod/web/...` (optionnel, pour runtime SSR)

### Modules Terraform (9 modules réutilisables)

**Modules Actifs :**
1. **`modules/shared/`** - Infrastructure partagée (VPC, networking)
2. **`modules/rds-postgres/`** - Base de données PostgreSQL
3. **`modules/frontend/`** - Frontend OpenNext (S3 + CloudFront + Lambda SSR) ⭐ NOUVEAU
   - CloudFront aliases gérés par Terraform : `dev.kambriq.com` (dev) et `kambriq.com` (prod)
4. **`modules/s3-media/`** - Bucket S3 médias/documents
5. **`modules/lambda-api/`** - Fonction Lambda API (handler: `dist/lambda.handler`)
6. **`modules/api-gateway/`** - API Gateway HTTP API
7. **`modules/iam/`** - Rôles et policies IAM

**Modules Legacy (obsolètes) :**
- ⚠️ **`modules/s3-static-site/`** - Remplacé par `modules/frontend/` (marqué LEGACY, README ajouté)
- ⚠️ **`modules/cloudfront/`** - Remplacé par `modules/frontend/` (marqué LEGACY, README ajouté)

**Note :** Ces modules ne sont plus utilisés dans `envs/dev/` ou `envs/prod/`. Ils peuvent être déplacés vers `legacy/modules/` après validation complète.

**Module Frontend (`modules/frontend/`) :**
- Gère S3 bucket pour assets statiques OpenNext
- CloudFront distribution avec OAC
- CloudFront aliases gérés par Terraform : `dev.kambriq.com` (dev) et `kambriq.com` (prod)
- Lambda SSR (fonction créée, code mis à jour via `deploy-app-dev.yml` / `deploy-app-prod.yml`)
- Variables Terraform : `api_gateway_url` (pour configuration frontend)

### CI/CD - GitHub Actions (3 workflows)

#### `terraform-shared.yml`
- **Déclencheurs :**
  - Pull Request vers `main` → `terraform plan` uniquement
  - Push vers `main` → `terraform plan` + `apply` automatique
- **Fichiers surveillés :** `envs/shared/**`, `modules/shared/**`, `modules/**`
- **Rôle :** Infrastructure de base (VPC, Route53, SES, ACM)

#### `terraform-dev.yml` ⭐ SIMPLIFIÉ (Infra only)
- **Déclencheurs :**
  - Pull Request vers `develop` : Plan uniquement (pas d'apply)
  - Push vers `develop` : Plan + Apply automatique
  - Workflow Dispatch : Plan uniquement (manuel)
- **Fichiers surveillés :** `envs/dev/**`, `modules/**`, `.github/workflows/terraform-dev.yml`
- **Caractéristiques :** 
  - Gère **uniquement l'infrastructure** (Lambda, API Gateway, RDS, S3, CloudFront, SSM, IAM, VPC, etc.)
  - **Ne déploie pas le code applicatif** (fait par `deploy-app-dev.yml` dans le repo `kambriq`)
  - Plan sauvegardé comme artifact

#### `terraform-prod.yml` ⭐ SIMPLIFIÉ (Infra only)
- **Déclencheurs :**
  - Workflow Dispatch uniquement (manuel)
- **Fichiers surveillés :** `envs/prod/**`, `modules/**`
- **Sécurité :** 
  - Protection via GitHub Environment `production` (approbation manuelle possible)
  - Plan sauvegardé comme artifact (rétention 30 jours)
  - Gère **uniquement l'infrastructure** (Lambda, API Gateway, RDS, S3, CloudFront, SSM, IAM, VPC, etc.)
  - **Ne déploie pas le code applicatif** (fait par `deploy-app-prod.yml` dans le repo `kambriq`)

### Backend Terraform
- **Type :** S3 backend
- **Bucket :** `kloudnat-infra-shared-store`
- **Région :** `eu-central-1`
- **State files :**
  - `kambriq/shared/terraform.tfstate`
  - `kambriq/dev/terraform.tfstate`
  - `kambriq/prod/terraform.tfstate`
- **Remote State :** `dev` et `prod` consomment les outputs de `shared` via `terraform_remote_state`

### Gestion des Secrets
- **⚠️ IMPORTANT :** Les secrets applicatifs ne sont **PAS** gérés par Terraform
- **Stockage :** SSM Parameter Store
- **Script :** `scripts/generate-and-store-secrets.sh`
- **Secrets :**
  - `/kambriq/dev/db/password`
  - `/kambriq/dev/api/jwt_secret`
  - `/kambriq/prod/db/password`
  - `/kambriq/prod/api/jwt_secret`

### Ordre de déploiement obligatoire
1. **Shared** → Déployer en premier
2. **Dev** → Dépend de Shared
3. **Prod** → Dépend de Shared

---

## 💻 Repository 2 : `kambriq`

### Description
Monorepo contenant l'application KAMBRIQ avec backend et frontend.

### Structure
```
kambriq/
├── api/        # Backend NestJS + Prisma
├── web/        # Frontend Next.js
├── docs/       # Documentation additionnelle
└── scripts/    # Scripts utilitaires
```

### API (`api/`) - Backend NestJS

**Technologies :**
- NestJS avec architecture DDD (Domain-Driven Design)
- Prisma ORM pour PostgreSQL
- Node.js 20.x
- TypeScript

**Structure :**
```
api/
├── prisma/          # Prisma ORM (schema, migrations, seed)
├── src/
│   ├── domain/      # Entités, repositories, services, exceptions
│   ├── application/ # Use cases, DTOs
│   ├── infrastructure/ # Prisma, sécurité, email, config
│   └── presentation/ # Controllers, guards, filters
├── test/            # Tests e2e
└── docker-compose.yml # PostgreSQL local
```

**Adaptation Lambda :**
- **Handler Lambda :** `api/src/lambda.ts` (nouveau fichier)
  - Utilise `@vendia/serverless-express` pour adapter NestJS à Lambda
  - Optimisation cold start (cache de l'instance NestJS)
  - Compatible HTTP API Gateway (payload v2)
  - Handler exporté : `dist/lambda.handler`
- **Fichier main.ts :** Conservé pour développement local (`pnpm dev`)

**Scripts principaux :**
- `pnpm dev` - Démarre en mode watch (http://localhost:3001) - Serveur HTTP classique
- `pnpm build` - Build de production
- `pnpm build:prod` - Build en mode production (NODE_ENV=production)
- `pnpm package:lambda` - Génère le package Lambda (ZIP) pour déploiement AWS
- `pnpm prisma:generate` - Génère le client Prisma
- `pnpm prisma:migrate` - Applique les migrations

**Packaging Lambda :**
- Génère `kambriq-api-dev.zip` contenant :
  - `dist/` - Code compilé NestJS (inclut `dist/lambda.js`)
  - `node_modules/` - Dépendances runtime
  - `prisma/` - Schema et migrations
  - `package.json` - Métadonnées
- Handler utilisé par Terraform : `dist/lambda.handler`

### Web (`web/`) - Frontend Next.js

**Technologies :**
- Next.js 16.0.3 (App Router)
- React 19.2.0 avec React Compiler
- Tailwind CSS 4 avec design system KAMBRIQ
- i18next & react-i18next (FR/EN)
- React Query (@tanstack/react-query)
- shadcn/ui
- TypeScript

**Fonctionnalités :**
- **KAMBRIQ Lands** : Browse and purchase verified land titles in Cameroon
- **KAMBRIQ Verify** : Verify land title authenticity (48-72h service)
- **KBS (KAMBRIQ Business School)** : Certified training in Cameroonian land transactions
- **KAMNET** : Network of certified land agents

**Adaptation OpenNext :**
- **Configuration OpenNext :** `web/opennext.config.ts`
  - Build command : `pnpm build`
  - Output directory : `.open-next/`
  - Lambda configuration : memory 1024MB, timeout 30s, runtime nodejs20.x
  - Image optimization : Lambda@Edge
  - ISR et Server Actions activés
- **Configuration Next.js :** `web/next.config.ts`
  - Optimisé pour OpenNext (pas de `output: 'export'`)
  - Image optimization via Lambda@Edge
  - React Compiler activé

**Scripts principaux :**
- `pnpm dev` - Serveur de dev (http://localhost:3000) - Mode développement classique
- `pnpm build` - Build Next.js standard
- `pnpm build:opennext` - Build OpenNext (génère `.open-next/` pour AWS) ⭐ NOUVEAU
- `pnpm lint` - Lint du code
- `pnpm check-types` - Vérification TypeScript

**Structure OpenNext :**
- `.open-next/assets/` → Assets statiques pour S3
- `.open-next/server/` → Lambda functions pour SSR
- `.open-next/cache/` → Configuration ISR
- `.open-next/image-optimization/` → Lambda@Edge pour images

### CI/CD - GitHub Actions (4 workflows)

#### `ci.yml` - CI Global
**Déclencheurs :**
- `push` et `pull_request` sur `develop` et `main`

**Actions :**
- **Job `api`** : Install, generate Prisma, lint, test
- **Job `web`** : Install, lint, check-types

**Rôle :** CI global pour validation du code avant merge

#### `build-artifacts.yml` - Build Artefacts (Optionnel)
**Déclencheurs :**
- `push` sur `main`
- `workflow_dispatch` (manuel)

**Actions :**
1. Build API → `api-bundle.zip` (dist/ + node_modules/ + prisma/ + package.json)
2. Build Web OpenNext → `web-ssr.zip` (.open-next/)
3. Upload vers S3 : `api/api-<sha>.zip` et `web/web-<sha>.zip`
4. Expose les clés S3 en outputs GitHub Actions

**Rôle :** Génération optionnelle des artefacts pour consommation future

**Outputs :**
- `api_s3_key` : Clé S3 de l'artefact API
- `web_s3_key` : Clé S3 de l'artefact Web
- `artifacts_bucket` : Nom du bucket S3

#### `deploy-app-dev.yml` ⭐ NOUVEAU - Déploiement Applicatif DEV
**Déclencheurs :**
- `workflow_dispatch` (manuel)

**Actions :**
1. Build API (NestJS) → package en ZIP
2. Build Web (OpenNext) → package bundle SSR
3. Update Lambda API : `aws lambda update-function-code`
4. Update Lambda SSR : `aws lambda update-function-code`
5. Sync assets statiques vers S3
6. Invalidation CloudFront cache

**Rôle :** Déploiement direct du code applicatif en DEV (sans passer par Terraform)

**Secrets requis :**
- `AWS_ACCESS_KEY_ID_DEV`, `AWS_SECRET_ACCESS_KEY_DEV`, `AWS_REGION_DEV`
- `API_LAMBDA_NAME_DEV`, `WEB_SSR_LAMBDA_NAME_DEV`
- `WEB_ASSETS_BUCKET_DEV`, `CLOUDFRONT_DISTRIBUTION_ID_DEV`

#### `deploy-app-prod.yml` ⭐ NOUVEAU - Déploiement Applicatif PROD
**Déclencheurs :**
- `workflow_dispatch` (manuel)

**Protection :**
- Environment `production` (approbation manuelle possible)

**Actions :** Identiques à `deploy-app-dev.yml` mais pour l'environnement production

**Secrets requis :** Même structure avec suffixe `_PROD`

**⚠️ Note :** Les workflows `backend-dev.yml` et `frontend-dev.yml` ont été supprimés. Le déploiement se fait maintenant directement via `deploy-app-dev.yml` et `deploy-app-prod.yml`.

### Scripts Utilitaires

#### Génération d'environnement frontend depuis Terraform
```bash
# Depuis la racine du repo
npm run env:frontend:dev
# ou
node scripts/generate-frontend-env-from-terraform.js
```

Génère `web/.env.dev.terraform` avec les variables d'environnement depuis les outputs Terraform (`kambriq-aws-iac-terraform/envs/dev`).

**Prérequis :** Terraform doit être initialisé et le stack `dev` déployé.

---

## 🔗 Intégration entre les Repos

### 1. Séparation des Responsabilités ⭐ NOUVEAU (2025-12-07)

**Repository `kambriq-aws-iac-terraform` (ce repo) :**
- Gère **uniquement l'infrastructure** via Terraform
- Crée et configure les ressources AWS (Lambda, API Gateway, RDS, S3, CloudFront, SSM, IAM, VPC, etc.)
- Ne déploie **pas** le code applicatif

**Repository `kambriq` :**
- Gère le code applicatif (API + Web)
- Déploie le code via les workflows `deploy-app-dev.yml` et `deploy-app-prod.yml`
- Effectue directement : build, package, `aws lambda update-function-code`, sync S3, invalidation CloudFront

### 2. Flux de Déploiement

**Infrastructure (ce repo) :**
1. Modifier le code Terraform si nécessaire
2. Exécuter `terraform-dev.yml` ou `terraform-prod.yml` pour mettre à jour l'infrastructure
3. Terraform crée/modifie les ressources AWS (Lambda functions, API Gateway, RDS, S3, CloudFront, etc.)

**Application (repo `kambriq`) :**
1. Modifier le code API ou Web
2. Exécuter `deploy-app-dev.yml` ou `deploy-app-prod.yml` pour déployer le nouveau code
3. Les workflows effectuent directement :
   - Build API + Web
   - Package en ZIP
   - `aws lambda update-function-code` (API + SSR)
   - Sync assets S3
   - Invalidation CloudFront

### 2. Terraform Outputs → Variables d'environnement applicatif

**Script d'intégration :**
- `kambriq/scripts/generate-frontend-env-from-terraform.js`
- Génère `web/.env.dev.terraform` depuis les outputs Terraform

**Mapping des outputs :**

| Terraform Output | Variable d'environnement | Usage |
|-----------------|---------------------------|-------|
| `api_gateway_base_url` | `NEXT_PUBLIC_API_BASE_URL` | API endpoint pour frontend |
| `frontend_cloudfront_url` | `NEXT_PUBLIC_SITE_URL` | Site URL pour metadata |
| `media_s3_public_bucket_name` | `NEXT_PUBLIC_S3_BUCKET_NAME` | S3 bucket pour uploads |

### 3. Secrets Management ⭐ NOUVEAU (2025-12-07)

**Structure SSM Parameter Store :**
```
/kambriq/{dev|prod}/{api|web}/{parameter_name}
```

**Secrets API (stockés dans SSM) :**
- `/kambriq/dev/api/DATABASE_URL`
- `/kambriq/dev/api/JWT_SECRET`
- `/kambriq/dev/api/FRONTEND_URL`
- `/kambriq/dev/api/SES_FROM_EMAIL`
- Même structure pour `/kambriq/prod/api/...`

**Secrets Web (optionnel, pour runtime SSR) :**
- `/kambriq/dev/web/...` (si nécessaire)
- `/kambriq/prod/web/...` (si nécessaire)

**Chargement au runtime :**
- **API (Lambda)** : Lit depuis SSM via `@aws-sdk/client-ssm` au démarrage (voir `api/src/infrastructure/config/config-loader.ts`)
- **Web (SSR)** : Optionnel, via `web/src/lib/runtimeConfig.ts` si nécessaire
- **Local** : Utilise `.env` (fichier local, non commité)

**GitHub Secrets :**
- Ne contiennent que des credentials techniques CI/CD (compte IAM, noms de Lambdas, buckets, IDs CloudFront)
- Ne contiennent **pas** les secrets métier (ceux-ci sont dans SSM)

### 4. CI/CD Coordination

**Flux de déploiement :**

1. **Application (repo `kambriq`) :**
   - Workflow `build-artifacts.yml` : Build et upload artefacts S3 (optionnel)
   - Workflows `deploy-app-dev.yml` et `deploy-app-prod.yml` : Déploiement direct du code applicatif (API + Web)

2. **Infrastructure (repo `kambriq-aws-iac-terraform`) :**
   - Workflows Terraform (`terraform-dev.yml`, `terraform-prod.yml`) : Gestion de l'infrastructure uniquement (ne déploie pas le code applicatif)
   - Créent/modifient les ressources AWS (Lambda, API Gateway, RDS, S3, CloudFront, SSM, IAM, VPC, etc.)
   - Génèrent les outputs nécessaires (noms de Lambdas, buckets, IDs CloudFront, etc.)

**Ordre recommandé :**
1. Déployer infrastructure `shared` → `dev` → `prod`
2. Créer les secrets dans SSM Parameter Store
3. Build artefacts dans `kambriq` (workflow `build-artifacts.yml`)
4. Déployer infrastructure avec artefacts (workflows Terraform)

---

## 📊 Architecture Complète

```
┌─────────────────────────────────────────────────────────────┐
│                    KAMBRIQ Platform                          │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Frontend (Next.js 16 + OpenNext)                   │   │
│  │  - S3 Static Assets (.open-next/assets/)             │   │
│  │  - CloudFront CDN                                    │   │
│  │  - Lambda SSR (.open-next/server/)                    │   │
│  │  - Lambda@Edge (Image Optimization)                  │   │
│  │  - Domain: app.kambriq.com (prod)                   │   │
│  └──────────────────────────────────────────────────────┘   │
│                          ↕ HTTP                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Backend (NestJS Lambda)                             │   │
│  │  - Lambda Function (kambriq-api-{env})               │   │
│  │  - API Gateway HTTP API                               │   │
│  │  - Domain: api.kambriq.com (prod)                    │   │
│  └──────────────────────────────────────────────────────┘   │
│                          ↕ PostgreSQL                        │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Database (RDS PostgreSQL)                           │   │
│  │  - Instance: t4g.micro, 20GB gp3                      │   │
│  │  - VPC Private Subnets                                │   │
│  │  - Backup: 7j (dev) / 30j (prod)                     │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Storage & Services                                   │   │
│  │  - S3 Media Bucket (kambriq-media-{env})             │   │
│  │  - SES (Email: noreply@kambriq.com)                  │   │
│  │  - Route53 (DNS: kambriq.com)                        │   │
│  │  - S3 Artifacts Bucket (artefacts de build)         │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Network (VPC)                                        │   │
│  │  - CIDR: 10.0.0.0/16                                  │   │
│  │  - Public Subnets: 2 (1 par AZ)                      │   │
│  │  - Private Subnets: 2 (1 par AZ)                      │   │
│  │  - NAT Gateway: 1 seul (réduction coûts)            │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔐 Gestion des Secrets

### Secrets dans SSM Parameter Store

**Convention de nommage :**
```
/kambriq/{environment}/{parameter_name}
```

**Secrets requis :**

**Dev :**
- `/kambriq/dev/db/password` - Mot de passe RDS
- `/kambriq/dev/api/jwt_secret` - Clé secrète JWT

**Prod :**
- `/kambriq/prod/db/password` - Mot de passe RDS
- `/kambriq/prod/api/jwt_secret` - Clé secrète JWT

**Script de génération :**
```bash
./scripts/generate-and-store-secrets.sh [dev|prod|all]
```

**⚠️ IMPORTANT :**
- Les secrets ne sont **jamais** dans Git ou Terraform outputs
- Les secrets sont stockés dans SSM Parameter Store
- Lambda récupère les secrets via variables d'environnement configurées par Terraform

---

## 🚀 Flux de Déploiement Complet

### 1. Infrastructure (repo `kambriq-aws-iac-terraform`)

**Ordre obligatoire :**

```bash
# 1. Déployer shared (EN PREMIER)
cd kambriq-aws-iac-terraform/envs/shared
terraform init
terraform plan
terraform apply

# 2. Configurer manuellement (après shared) :
# - Route53 hosted zone (récupérer zone_id)
# - SES domain/email identities (récupérer ARNs)
# - ACM certificates (récupérer ARNs)

# 3. Déployer dev
cd ../dev
terraform init
terraform plan  # Lit les outputs de shared via remote_state
terraform apply

# 4. Déployer prod
cd ../prod
terraform init
terraform plan  # Lit les outputs de shared via remote_state
terraform apply
```

### 2. Secrets (SSM Parameter Store)

```bash
# Générer et stocker les secrets
cd kambriq-aws-iac-terraform
./scripts/generate-and-store-secrets.sh all
```

### 3. Application (repo `kambriq`)

**Backend :**
```bash
# Déploiement automatique via GitHub Actions sur push vers develop
# Ou manuellement :
cd kambriq/api
pnpm package:lambda
# Upload vers S3 et update Lambda function
```

**Frontend :**
```bash
# Déploiement automatique via GitHub Actions (workflow build-artifacts.yml)
# Ou manuellement :
cd kambriq/web
pnpm build:opennext  # Build OpenNext (génère .open-next/)
# Upload artefacts vers S3 et déploiement via Terraform
```

---

## 📝 Technologies Principales

| Composant | Technologies |
|-----------|-------------|
| **Infrastructure** | Terraform 1.5.0+, AWS Provider ~> 5.0 |
| **Frontend** | Next.js 16, React 19, Tailwind CSS 4, TypeScript |
| **Backend** | NestJS, Prisma ORM, PostgreSQL 15 |
| **Runtime** | Node.js 20.x (Lambda), Node.js 22 (CI/CD) |
| **Package Manager** | pnpm 9.x+ |
| **CI/CD** | GitHub Actions |
| **Cloud** | AWS (eu-central-1) |
| **Database** | PostgreSQL 15.15 (RDS) |

---

## ⚠️ Points d'Attention Critiques

### Configuration Manuelle Requise

**Avant de déployer l'infrastructure :**

1. **Route53 Hosted Zone** pour `kambriq.com`
   - Créer manuellement dans AWS Console
   - Récupérer le `zone_id`
   - Ajouter dans `envs/shared/terraform.tfvars`

2. **SES Domain Identity** pour `kambriq.com`
   - Créer et vérifier via DNS
   - Récupérer l'ARN
   - Ajouter dans `envs/shared/terraform.tfvars`

3. **SES Email Identity** pour `noreply@kambriq.com`
   - Créer et vérifier via email
   - Récupérer l'ARN
   - Ajouter dans `envs/shared/terraform.tfvars`

4. **ACM Certificate** pour API Gateway (eu-central-1)
   - Certificat wildcard `*.kambriq.com` ou spécifique
   - Récupérer l'ARN
   - Ajouter dans `envs/shared/terraform.tfvars`

5. **ACM Certificate** pour CloudFront (us-east-1)
   - Certificat wildcard `*.kambriq.com` ou spécifique
   - Récupérer l'ARN
   - Ajouter dans `envs/dev/terraform.tfvars` et `envs/prod/terraform.tfvars`

**⚠️ CRITIQUE :** Sans ces configurations manuelles, les déploiements échoueront ou les ressources ne seront pas complètes.

### Ordre de Déploiement

**IMPORTANT :** Le stack `shared` doit être déployé **EN PREMIER** avant `dev` et `prod`.

### Secrets

**⚠️ Ne jamais :**
- Commiter les secrets dans Git
- Stocker les secrets dans Terraform outputs
- Utiliser les mêmes secrets entre dev et prod

**✅ Toujours :**
- Utiliser SSM Parameter Store
- Générer des secrets forts et uniques
- Utiliser le script de génération fourni

---

## 📚 Documentation Complémentaire

### Repo Infrastructure (`kambriq-aws-iac-terraform`)
- `README.md` - Vue d'ensemble
- `docs/architecture/ETAT_ACTUEL_DETAILLE.md` - État détaillé de l'infrastructure
- `docs/setup/TERRAFORM_USAGE.md` - Guide d'usage Terraform
- `docs/integration/APP_INTEGRATION.md` - Guide d'intégration avec l'application
- `docs/setup/ACM_SES_MANUAL_SETUP.md` - Configuration manuelle SES/ACM
- `docs/setup/ROUTE53_DNS_SETUP.md` - Configuration DNS Route53

### Repo Application (`kambriq`)
- `README.md` - Vue d'ensemble monorepo
- `api/README.md` - Documentation API NestJS
- `web/README.md` - Documentation Web Next.js
- `docs/deployment/PIPELINE_OVERVIEW.md` ⭐ NOUVEAU - Documentation complète du pipeline de déploiement
- `docs/` - Guides d'intégration backend, état d'implémentation

---

## 💰 Optimisations Coûts

**Décisions prises pour réduire les coûts :**
- ✅ **1 seul NAT Gateway** (au lieu de 2) - Réduction ~$32/mois
- ✅ **RDS t4g.micro** - Instance la plus petite
- ✅ **20GB storage** - Minimum pour RDS
- ✅ **Backup retention 7j (dev)** - Minimum pour dev
- ✅ **Architecture serverless** - Pay-per-use

**Coûts estimés MVP :**
- RDS t4g.micro : ~$15-20/mois
- Lambda : Pay-per-use (gratuit jusqu'à 1M requêtes/mois)
- API Gateway : Pay-per-use (gratuit jusqu'à 1M requêtes/mois)
- S3 : ~$0.023/Go/mois
- CloudFront : Pay-per-use (gratuit jusqu'à 1To/mois)
- SES : Gratuit jusqu'à 62,000 emails/mois
- **Total estimé : ~$20-30/mois** (hors trafic)

---

## 🔄 Workflows GitHub Actions - Résumé

### Infrastructure (`kambriq-aws-iac-terraform`)

| Workflow | Déclencheur | Actions |
|----------|-------------|---------|
| `terraform-shared.yml` | PR vers `main` | `terraform plan` (commentaire PR) |
| `terraform-shared.yml` | Push vers `main` | `terraform plan` + `apply` |
| `terraform-dev.yml` | PR vers `develop` (plan), Push `develop` (plan+apply), Workflow Dispatch (plan) | Infrastructure DEV uniquement (ne déploie pas le code applicatif) |
| `terraform-prod.yml` | Workflow Dispatch | Infrastructure PROD uniquement (ne déploie pas le code applicatif) + protection environnement `production` |

### Application (`kambriq`)

| Workflow | Déclencheur | Actions |
|----------|-------------|---------|
| `ci.yml` | Push/PR sur `develop`, `main` | Lint, test, check-types (API + Web) |
| `build-artifacts.yml` | Push sur `main`, `workflow_dispatch` | Build API + Web OpenNext, upload S3 artefacts, expose `api_s3_key` et `web_s3_key` (optionnel) |
| `deploy-app-dev.yml` ⭐ NOUVEAU | Workflow Dispatch | Déploiement applicatif DEV : build, update Lambda API + SSR, sync S3, invalidation CloudFront |
| `deploy-app-prod.yml` ⭐ NOUVEAU | Workflow Dispatch | Déploiement applicatif PROD : même logique que dev, avec protection `production` |

---

## ✅ Checklist de Déploiement Initial

### Infrastructure
- [ ] Déployer stack `shared`
- [ ] Configurer Route53 hosted zone (manuel)
- [ ] Configurer SES identities (manuel)
- [ ] Configurer ACM certificates (manuel)
- [ ] Déployer stack `dev`
- [ ] Déployer stack `prod`

### Secrets
- [ ] Générer secrets dev (`generate-and-store-secrets.sh dev`)
- [ ] Générer secrets prod (`generate-and-store-secrets.sh prod`)
- [ ] Vérifier que les secrets sont dans SSM Parameter Store

### Application
- [ ] Configurer secrets GitHub Actions (AWS credentials pour workflows applicatifs)
- [ ] Tester workflow `ci.yml` (lint, test, check-types)
- [ ] Tester workflow `build-artifacts.yml` (build et upload S3 - optionnel)
- [ ] Tester déploiement applicatif DEV (workflow `deploy-app-dev.yml`)
- [ ] Tester déploiement applicatif PROD (workflow `deploy-app-prod.yml`)
- [ ] Vérifier que l'application fonctionne avec l'infrastructure

### Intégration Infrastructure/Application
- [ ] Vérifier que l'infrastructure est déployée (via `terraform-dev.yml` / `terraform-prod.yml`)
- [ ] Vérifier que les Lambda functions existent (créées par Terraform)
- [ ] Tester déploiement du code applicatif (via `deploy-app-dev.yml` / `deploy-app-prod.yml`)
- [ ] Vérifier que Lambda API utilise le nouveau code
- [ ] Vérifier que Lambda SSR utilise le nouveau code
- [ ] Vérifier que les assets S3 sont synchronisés

---

---

## 📦 Déploiements Applicatifs

**⚠️ Important** : Depuis 2025-12-07, les déploiements applicatifs (mise à jour du code API + Web) sont gérés par les workflows `deploy-app-dev.yml` et `deploy-app-prod.yml` dans le repository `kambriq`. Terraform ne gère plus les artefacts applicatifs.

### Workflows de Déploiement Applicatif

**Repository `kambriq` :**

**`deploy-app-dev.yml`** :
- Build API + Web
- Package en ZIP
- `aws lambda update-function-code` (API + SSR)
- Sync assets S3
- Invalidation CloudFront

**`deploy-app-prod.yml`** :
- Même logique que dev
- Protection via GitHub Environment `production`

### Structure des Bundles

**API Bundle** :
- `dist/` - Code compilé NestJS (inclut `dist/lambda.js`)
- `node_modules/` - Dépendances runtime
- `prisma/` - Schema et migrations
- `package.json` - Métadonnées

**Web Bundle** :
- `.open-next/` - Structure complète OpenNext
  - `.open-next/assets/` - Assets statiques pour S3
  - `.open-next/server/` - Lambda functions pour SSR
  - `.open-next/cache/` - Configuration ISR
  - `.open-next/image-optimization/` - Lambda@Edge pour images

**Note** : Le workflow `build-artifacts.yml` peut toujours générer et uploader des artefacts S3 (optionnel), mais ils ne sont plus consommés par Terraform.

**Note** : Les variables Terraform `artifact_bucket_name`, `api_bundle_s3_key` et `ssr_bundle_s3_key` ne sont plus utilisées. Terraform crée uniquement les Lambda functions (structure), le code est mis à jour via les workflows `deploy-app-dev.yml` et `deploy-app-prod.yml` dans le repository `kambriq`.

---

## 🔄 Changements Récents (Migration OpenNext + Lambda)

### Migration Frontend (Next.js → OpenNext)

**Avant :**
- OpenNext build (`pnpm build:opennext` génère `.open-next/`)
- Déploiement S3 + CloudFront uniquement
- Pas de SSR

**Après :**
- OpenNext pour SSR avec Lambda
- Build : `pnpm build:opennext` (génère `.open-next/`)
- Structure : Assets S3 + Lambda SSR + Lambda@Edge images
- Module Terraform : `modules/frontend/` (remplace `s3-static-site` + `cloudfront`)

### Migration Backend (NestJS → Lambda)

**Avant :**
- Serveur HTTP classique uniquement
- Handler : `dist/lambda.handler` (adaptateur `@vendia/serverless-express`)

**Après :**
- Adaptateur Lambda : `api/src/lambda.ts` avec `@vendia/serverless-express`
- Handler : `dist/lambda.handler`
- Cold start optimization (cache de l'instance NestJS)
- Compatible HTTP API Gateway (payload v2)

### Séparation Infrastructure/Applicatif (2025-12-07)

**Avant (modèle obsolète) :**
- Terraform déployait aussi le code applicatif via artefacts S3
- Workflows Terraform avec inputs `api_s3_key` et `web_s3_key`
- Variables Terraform `api_bundle_s3_key` et `ssr_bundle_s3_key` (supprimées)

**Après :**
- Terraform gère uniquement l'infrastructure (création/modification des ressources AWS)
- Déploiements applicatifs via workflows `deploy-app-dev.yml` et `deploy-app-prod.yml` dans le repo `kambriq`
- Workflows Terraform simplifiés (pas d'inputs pour artefacts)
- Secrets gérés via SSM Parameter Store (`/kambriq/{env}/{api|web}/...`)
- Chargement des secrets au runtime par l'application

---

**Dernière mise à jour :** 2025-12-07  
**Version :** 3.1 (Séparation infrastructure/applicatif - SSM Parameter Store - Déploiements directs - Outils CLI)  
**Maintenu par :** Équipe Infrastructure KAMBRIQ
