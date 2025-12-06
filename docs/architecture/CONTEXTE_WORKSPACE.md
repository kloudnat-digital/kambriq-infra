# Contexte du Workspace KAMBRIQ

**Date de création :** 2025-01-27  
**Dernière mise à jour :** 2025-01-27  
**Version :** 2.0 (OpenNext + Lambda NestJS + Artefacts S3)

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

**⚠️ Migration récente :**
- Frontend : Migration de static export vers **OpenNext** (SSR + Lambda)
- Backend : Adaptation NestJS pour **Lambda** (handler `dist/lambda.handler`)
- Déploiement : Nouveau système d'**artefacts S3** pour consommation par Terraform

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
- ✅ IAM : Rôles et policies Lambda
- ✅ Security Groups : RDS + Lambda

**Variables d'artefacts S3 :**
- `artifact_bucket_name` : Bucket S3 des artefacts (ex: `kambriq-artifacts-dev`)
- `api_bundle_s3_key` : Clé S3 du bundle API (ex: `api/api-abc123.zip`)
- `ssr_bundle_s3_key` : Clé S3 du bundle OpenNext (ex: `web/web-abc123.zip`)

**Backend :**
- Bucket S3 : `kloudnat-infra-shared-store`
- State file : `kambriq/dev/terraform.tfstate`

**Configuration spécifique :**
- Backup retention : **7 jours**
- `skip_final_snapshot` : **true**
- Domaines personnalisés : **Optionnels**

**Secrets (SSM Parameter Store) :**
- `/kambriq/dev/db/password`
- `/kambriq/dev/api/jwt_secret`

#### 3. `envs/prod/` - Environnement Production
**Ressources gérées :**
- Identiques à `dev` (même structure)

**Configuration spécifique :**
- Backup retention : **30 jours**
- `skip_final_snapshot` : **false**
- Domaines personnalisés : **Recommandés** (app.kambriq.com, api.kambriq.com)

**Secrets (SSM Parameter Store) :**
- `/kambriq/prod/db/password`
- `/kambriq/prod/api/jwt_secret`

### Modules Terraform (9 modules réutilisables)

**Modules Actifs :**
1. **`modules/shared/`** - Infrastructure partagée (VPC, networking)
2. **`modules/rds-postgres/`** - Base de données PostgreSQL
3. **`modules/frontend/`** - Frontend OpenNext (S3 + CloudFront + Lambda SSR) ⭐ NOUVEAU
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
- Lambda SSR (placeholder, mis à jour via CI/CD)
- Support des artefacts OpenNext depuis S3 (`ssr_bundle_s3_key`)
- Variables : `artifact_bucket_name`, `ssr_bundle_s3_key`, `api_gateway_url`

### CI/CD - GitHub Actions (3 workflows)

#### `terraform-shared.yml`
- **Déclencheurs :**
  - Pull Request vers `main` → `terraform plan` uniquement
  - Push vers `main` → `terraform plan` + `apply` automatique
- **Fichiers surveillés :** `envs/shared/**`, `modules/shared/**`, `modules/**`
- **Rôle :** Infrastructure de base (VPC, Route53, SES, ACM)

#### `terraform-dev.yml` ⭐ AMÉLIORÉ
- **Déclencheurs :**
  - Push vers `develop` → `terraform plan` + `apply` automatique
  - Workflow Dispatch → Déclenchement manuel avec inputs
- **Fichiers surveillés :** `envs/dev/**`, `modules/**`
- **Inputs (workflow_dispatch) :**
  - `api_bundle_s3_key` : Clé S3 du bundle API (ex: `api/api-abc123.zip`)
  - `ssr_bundle_s3_key` : Clé S3 du bundle OpenNext (ex: `web/web-abc123.zip`)
  - `artifact_bucket_name` : Nom du bucket S3 (ex: `kambriq-artifacts-dev`)
- **Caractéristiques :** 
  - Apply automatique pour itération rapide
  - Consomme les artefacts S3 uploadés par le repo `kambriq`
  - Documentation intégration avec `kambriq` dans les commentaires

#### `terraform-prod.yml` ⭐ AMÉLIORÉ
- **Déclencheurs :**
  - Workflow Dispatch avec choix `plan` ou `apply`
  - Push de tag `v*` → `plan` puis `apply` automatique
- **Fichiers surveillés :** `envs/prod/**`, `modules/**`
- **Inputs (workflow_dispatch) :**
  - `action` : `plan` ou `apply`
  - `api_bundle_s3_key` : Clé S3 du bundle API
  - `ssr_bundle_s3_key` : Clé S3 du bundle OpenNext
  - `artifact_bucket_name` : Nom du bucket S3
- **Structure :** 2 jobs (terraform-plan toujours, terraform-apply conditionnel)
- **Sécurité :** 
  - Plan toujours généré avant apply, sauvegardé comme artifact
  - Protection via GitHub Environment `production` (approbation manuelle commentée)
  - Documentation intégration avec `kambriq` dans les commentaires

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

#### `ci.yml` ⭐ NOUVEAU
**Déclencheurs :**
- `push` et `pull_request` sur `develop` et `main`

**Actions :**
- **Job `api-ci`** : Install, generate Prisma, lint, test
- **Job `web-ci`** : Install, lint, check-types

**Rôle :** CI global pour validation du code avant merge

#### `build-artifacts.yml` ⭐ NOUVEAU
**Déclencheurs :**
- `push` sur `main`
- `workflow_dispatch` (manuel)

**Actions :**
1. Build API → `api-bundle.zip` (dist/ + node_modules/ + prisma/)
2. Build Web OpenNext → `web-ssr.zip` (.open-next/)
3. Upload vers S3 : `api/api-<sha>.zip` et `web/web-<sha>.zip`
4. Expose les clés S3 en outputs GitHub Actions

**Rôle :** Génération des artefacts pour consommation par Terraform

**Outputs :**
- `api_s3_key` : Clé S3 de l'artefact API
- `web_s3_key` : Clé S3 de l'artefact Web
- `artifacts_bucket` : Nom du bucket S3

#### `backend-dev.yml`
**Déclencheurs :**
- Push sur `develop` avec changements dans `api/**`
- Workflow Dispatch

**Actions :**
1. Setup pnpm + Node.js 22
2. Install dependencies
3. Generate Prisma client
4. Lint
5. Test
6. Build & package Lambda (`pnpm package:lambda`)
7. Upload Lambda artifact to S3 (`AWS_ARTIFACTS_BUCKET_DEV`)
8. Deploy Lambda from S3 (update function code)

**Rôle :** Déploiement automatique rapide pour développement

**Secrets requis :**
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_DEFAULT_REGION` (optionnel, défaut: eu-central-1)
- `AWS_ARTIFACTS_BUCKET_DEV`

#### `frontend-dev.yml` ⭐ AMÉLIORÉ
**Déclencheurs :**
- Push sur `develop` avec changements dans `web/**`
- Workflow Dispatch

**Actions :**
1. Setup pnpm + Node.js 22
2. Install dependencies
3. Lint
4. Check types ⭐ AJOUTÉ
5. Test
6. Build OpenNext (`pnpm build:opennext`) ⭐ MIGRÉ
7. Archive OpenNext artifacts to S3
8. Deploy static assets to S3 (`.open-next/assets/`)
9. Invalidate CloudFront

**Rôle :** Déploiement automatique rapide pour développement

**Secrets requis :**
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_DEFAULT_REGION` (optionnel, défaut: eu-central-1)
- `AWS_ARTIFACTS_BUCKET_DEV` (optionnel)

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

### 1. Artefacts S3 → Infrastructure Terraform ⭐ NOUVEAU

**Flux principal :**
1. **Repo `kambriq`** : Workflow `build-artifacts.yml` build et upload vers S3
   - `api/api-<sha>.zip` → Bundle Lambda NestJS
   - `web/web-<sha>.zip` → Bundle OpenNext
   - Outputs : `api_s3_key`, `web_s3_key`, `artifacts_bucket`

2. **Repo `kambriq-aws-iac-terraform`** : Workflows Terraform consomment les artefacts
   - Variables : `api_bundle_s3_key`, `ssr_bundle_s3_key`, `artifact_bucket_name`
   - Passées via `workflow_dispatch` inputs ou variables d'environnement
   - Terraform utilise les artefacts S3 pour déployer Lambda et OpenNext

**Récupération des clés S3 :**
1. Aller dans `kambriq` → Actions → `build-artifacts` workflow
2. Copier les S3 keys depuis les outputs
3. Utiliser dans `terraform-dev.yml` ou `terraform-prod.yml`

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

### 3. Secrets Management

**Backend (Lambda) :**
- Secrets récupérés depuis SSM Parameter Store
- Variables d'environnement Lambda configurées par Terraform :
  - `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USERNAME`, `DB_PASSWORD`
  - `S3_MEDIA_BUCKET`
  - `SES_FROM_EMAIL`
  - `JWT_SECRET`

**Frontend (Next.js) :**
- Variables d'environnement publiques (préfixe `NEXT_PUBLIC_`)
- Générées depuis les outputs Terraform

### 4. CI/CD Coordination

**Flux de déploiement :**

1. **Application (repo `kambriq`) :**
   - Workflow `build-artifacts.yml` : Build et upload artefacts S3
   - Workflows `backend-dev.yml` / `frontend-dev.yml` : Déploiement auto sur `develop`

2. **Infrastructure (repo `kambriq-aws-iac-terraform`) :**
   - Workflows Terraform consomment les artefacts S3
   - Déploient l'infrastructure avec les nouveaux artefacts
   - Génèrent les outputs nécessaires

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
# Déploiement automatique via GitHub Actions sur push vers develop
# Ou manuellement :
cd kambriq/web
pnpm build:static
# Sync vers S3 et invalidation CloudFront
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
| `terraform-dev.yml` | Push vers `develop` | `terraform plan` + `apply` (auto) |
| `terraform-dev.yml` | Workflow Dispatch | `terraform plan` + `apply` avec inputs artefacts S3 |
| `terraform-prod.yml` | Workflow Dispatch | `terraform plan` (toujours) + `apply` (conditionnel, avec inputs) |
| `terraform-prod.yml` | Tag `v*` | `terraform plan` + `apply` (auto) |

### Application (`kambriq`)

| Workflow | Déclencheur | Actions |
|----------|-------------|---------|
| `ci.yml` | Push/PR sur `develop`, `main` | Lint, test, check-types (API + Web) |
| `build-artifacts.yml` | Push sur `main`, `workflow_dispatch` | Build API + Web OpenNext, upload S3 artefacts |
| `backend-dev.yml` | Push vers `develop` (api/**) | Build, test, package Lambda, deploy (auto) |
| `frontend-dev.yml` | Push vers `develop` (web/**) | Build OpenNext, deploy S3, invalidate CloudFront (auto) |

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
- [ ] Configurer secrets GitHub Actions (AWS credentials)
- [ ] Tester workflow `ci.yml` (lint, test, check-types)
- [ ] Tester workflow `build-artifacts.yml` (build et upload S3)
- [ ] Tester déploiement backend (push vers `develop` → `backend-dev.yml`)
- [ ] Tester déploiement frontend (push vers `develop` → `frontend-dev.yml`)
- [ ] Vérifier que l'application fonctionne avec l'infrastructure

### Intégration Artefacts S3
- [ ] Vérifier que `build-artifacts.yml` upload correctement vers S3
- [ ] Tester déploiement Terraform avec artefacts S3 (workflow_dispatch avec inputs)
- [ ] Vérifier que Lambda utilise le bon bundle API
- [ ] Vérifier que OpenNext utilise le bon bundle Web

---

---

## 📦 Système d'Artefacts S3

### Structure des Artefacts

Les artefacts sont générés par le repo `kambriq` et uploadés dans un bucket S3 dédié :

**Bucket S3 :** `kambriq-artifacts-{env}` (ex: `kambriq-artifacts-dev`, `kambriq-artifacts-prod`)

**Structure :**
```
kambriq-artifacts-{env}/
├── api/
│   └── api-<sha>.zip          # Bundle Lambda NestJS
└── web/
    └── web-<sha>.zip          # Bundle OpenNext
```

**Contenu des artefacts :**

**API Bundle (`api/api-<sha>.zip`) :**
- `dist/` - Code compilé NestJS (inclut `dist/lambda.js`)
- `node_modules/` - Dépendances runtime
- `prisma/` - Schema et migrations
- `package.json` - Métadonnées

**Web Bundle (`web/web-<sha>.zip`) :**
- `.open-next/` - Structure complète OpenNext
  - `.open-next/assets/` - Assets statiques pour S3
  - `.open-next/server/` - Lambda functions pour SSR
  - `.open-next/cache/` - Configuration ISR
  - `.open-next/image-optimization/` - Lambda@Edge pour images

### Utilisation dans Terraform

Les workflows Terraform consomment ces artefacts via variables :
- `artifact_bucket_name` : Nom du bucket S3
- `api_bundle_s3_key` : Clé S3 du bundle API
- `ssr_bundle_s3_key` : Clé S3 du bundle OpenNext

**Exemple :**
```hcl
# envs/dev/main.tf
module "lambda" {
  source = "../../modules/lambda-api"
  # ...
  artifact_bucket_name = var.artifact_bucket_name
  api_bundle_s3_key    = var.api_bundle_s3_key
}

module "frontend" {
  source = "../../modules/frontend"
  # ...
  artifact_bucket_name = var.artifact_bucket_name
  ssr_bundle_s3_key   = var.ssr_bundle_s3_key
}
```

---

## 🔄 Changements Récents (Migration OpenNext + Lambda)

### Migration Frontend (Next.js → OpenNext)

**Avant :**
- Export statique Next.js (`output: 'export'`)
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

### Nouveau Système d'Artefacts

**Avant :**
- Déploiement direct depuis workflows applicatifs
- Pas de séparation claire entre build et déploiement infra

**Après :**
- Workflow `build-artifacts.yml` : Build et upload artefacts S3
- Workflows Terraform : Consomment les artefacts S3
- Traçabilité : Artefacts versionnés avec SHA
- Rollback facilité : Utiliser un artefact précédent

---

**Dernière mise à jour :** 2025-01-27  
**Version :** 2.0 (OpenNext + Lambda NestJS + Artefacts S3)  
**Maintenu par :** Équipe Infrastructure KAMBRIQ
