# Contexte du Workspace KAMBRIQ

**Date de création :** 2025-01-27  
**Dernière mise à jour :** 2026-01-13  
**Version :** 5.0 (Architecture 3 repos séparés - kambriq-infra, kambriq-api, kambriq-web)

---

## 📋 Vue d'ensemble

Le workspace KAMBRIQ contient **3 repositories distincts** qui travaillent ensemble pour déployer une plateforme complète sur AWS :

1. **`kambriq-infra`** - Infrastructure as Code (Terraform)
2. **`kambriq-api`** - Backend API (FastAPI + SQLAlchemy + Alembic) - **Refait from scratch**
3. **`kambriq-web`** - Frontend (Next.js sans NextAuth) - **Refait from scratch**

**⚠️ IMPORTANT :** Les repos `kambriq-api` et `kambriq-web` sont **complètement nouveaux** et **refaits from scratch**. Aucun lien avec l'ancien code monorepo `kambriq`.

---

## 🏗️ Repository 1 : `kambriq-infra`

### Description
Infrastructure AWS gérée via Terraform pour la plateforme KAMBRIQ v2.0.

### Architecture V2.0
**ECS Fargate + ALB + CloudFront** pour remplacer l'ancienne stack serverless :
- **Frontend** : Next.js Classic (standalone, ECS Fargate)
- **Backend** : FastAPI (ECS Fargate)
- **Load Balancing** : ALB avec routing rules (`/api/*` → FastAPI, `/*` → Next.js)
- **CDN** : CloudFront devant ALB
- **Base de données** : RDS PostgreSQL (t4g.micro, réutilisé)
- **Stockage** : S3 (médias/documents), ECR (images Docker)
- **Email** : SES (Simple Email Service, réutilisé)
- **Réseau** : VPC avec subnets publics/privés + NAT Gateway (réutilisé)

**✅ Migration V1 → V2 complétée (2026-01-03) :**
- **Infrastructure V1 supprimée** : Lambda, API Gateway, OpenNext
- **Infrastructure V2 créée** : ECS, ALB, CloudFront V2
- **Application V2** : FastAPI + Next.js classic
- **Documentation V2** : Complète et à jour

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
- ✅ ACM : Certificats ALB + CloudFront (référence manuelle)
- ✅ S3 : Buckets logs + artifacts

**Backend :**
- Bucket S3 : `kloudnat-infra-shared-store`
- State file : `kambriq/shared/terraform.tfstate`
- Région : `eu-central-1`

**⚠️ Configuration manuelle requise :**
- Route53 hosted zone (récupérer zone_id)
- SES domain/email identities (récupérer ARNs)
- ACM certificates (ALB: eu-central-1, CloudFront: us-east-1)

#### 2. `envs/dev-v2/` - Environnement Développement V2.0 ⭐
**Ressources gérées :**
- ✅ RDS PostgreSQL : t4g.micro, 20GB gp3
- ✅ ECS Cluster : Fargate avec Container Insights
- ✅ ECS Service API : FastAPI (port 8000, 256 CPU, 512 MB)
- ✅ ECS Service Web : Next.js (port 3000, 256 CPU, 512 MB)
- ✅ ALB : Application Load Balancer avec routing rules
- ✅ CloudFront V2 : Distribution avec origin ALB
- ✅ ECR : Repositories pour images Docker (kambriq-api, kambriq-web - partagés dev/prod)
- ✅ IAM : Rôles et policies ECS (SSM, RDS, CloudWatch Logs)
- ✅ Security Groups : RDS + ECS + ALB

**Backend :**
- Bucket S3 : `kloudnat-infra-shared-store`
- State file : `kambriq/dev-v2/terraform.tfstate`

**Configuration spécifique :**
- Backup retention : **7 jours**
- `skip_final_snapshot` : **true**
- Domain : **dev.kambriq.com**

**Secrets (SSM Parameter Store) :**
- `/kambriq/dev/db/url` - Database connection string (SecureString)
- `/kambriq/dev/api/JWT_SECRET` - JWT secret (SecureString)
- `/kambriq/dev/api/SES_FROM_EMAIL` - Email expéditeur SES (String)

**Variables d'environnement ECS (configurées par Terraform) :**
- `ENV` : `dev`
- `AWS_REGION` : `eu-central-1`
- `DATABASE_URL` : Depuis SSM Parameter Store (secret)
- `JWT_SECRET` : Depuis SSM Parameter Store (secret)
- `NEXT_PUBLIC_SITE_URL` : `https://dev.kambriq.com`
- `NEXT_PUBLIC_API_URL` : `https://dev.kambriq.com/api`

#### 3. `envs/prod/` - Environnement Production (V1 - À migrer vers V2)
**⚠️ Note :** L'environnement `prod` utilise encore l'ancienne stack V1 (Lambda + API Gateway).  
Voir `envs/prod/MIGRATION_TO_V2.md` pour le plan de migration.

**Ressources gérées (V1) :**
- RDS PostgreSQL : t4g.micro, 20GB gp3
- Lambda API : NestJS (handler: `dist/lambda.handler`)
- Lambda SSR : OpenNext (Next.js SSR)
- API Gateway : HTTP API
- CloudFront : Distribution avec origin S3 + Lambda Function URL
- S3 : Buckets pour assets statiques et médias

**Configuration spécifique :**
- Backup retention : **30 jours**
- `skip_final_snapshot` : **false**
- Domain : **kambriq.com**

### Modules Terraform V2 (modules réutilisables)

**Modules Actifs V2 :**
1. **`modules/shared/`** - Infrastructure partagée (VPC, networking)
2. **`modules/rds-postgres/`** - Base de données PostgreSQL
3. **`modules/ecs-cluster/`** - ECS Cluster + Task Execution Role + CloudWatch Logs ⭐ V2
4. **`modules/ecs-service/`** - ECS Task Definition + Service ⭐ V2
5. **`modules/alb/`** - Application Load Balancer avec routing rules ⭐ V2
6. **`modules/cloudfront-v2/`** - CloudFront Distribution (ALB origin) ⭐ V2
7. **`modules/iam-roles-ecs/`** - IAM Roles pour ECS tasks (SSM, RDS) ⭐ V2
8. **`modules/ecr-repository/`** - ECR repositories pour images Docker
9. **`modules/s3-media/`** - Bucket S3 médias/documents
10. **`modules/iam/`** - Rôles et policies IAM
11. **`modules/ssm-app-parameters/`** - SSM Parameter Store (secrets)

**Modules Legacy (obsolètes - V1) :**
- ⚠️ **`modules/lambda-api/`** - Remplacé par ECS Fargate (V1 uniquement)
- ⚠️ **`modules/api-gateway/`** - Remplacé par ALB (V1 uniquement)
- ⚠️ **`modules/frontend/`** - Remplacé par ECS Fargate + ALB (V1 uniquement)
- ⚠️ **`modules/s3-static-site/`** - Remplacé par ECS Fargate (V1 uniquement)
- ⚠️ **`modules/cloudfront/`** - Remplacé par `modules/cloudfront-v2/` (V1 uniquement)

**Note :** Les modules V1 sont conservés uniquement pour l'environnement `prod` qui n'a pas encore été migré vers V2.

### CI/CD - GitHub Actions

#### `terraform-shared.yml`
- **Déclencheurs :**
  - Pull Request vers `main` → `terraform plan` uniquement
  - Push vers `main` → `terraform plan` + `apply` automatique
- **Fichiers surveillés :** `envs/shared/**`, `modules/shared/**`
- **Rôle :** Infrastructure de base (VPC, Route53, SES, ACM)

#### `terraform-dev-v2.yml` ⭐ V2 (Infra only)
- **Déclencheurs :**
  - Pull Request vers `main` : Plan uniquement (pas d'apply)
  - Push vers `main` : Plan + Apply automatique
  - Workflow Dispatch : Plan uniquement (manuel)
- **Fichiers surveillés :** `envs/dev-v2/**`, `modules/**`
- **Caractéristiques :** 
  - Gère **uniquement l'infrastructure** (ECS, ALB, CloudFront, RDS, ECR, SSM, IAM, VPC, etc.)
  - **Ne déploie pas le code applicatif** (fait par les scripts `deploy-api.sh` et `deploy-web.sh` dans les repos `kambriq-api` et `kambriq-web`)
  - Plan sauvegardé comme artifact

#### `terraform-prod-optimized.yml` ⚠️ V1 (À migrer)
- **Déclencheurs :**
  - Workflow Dispatch uniquement (manuel)
- **Fichiers surveillés :** `envs/prod/**`, `modules/**`
- **Sécurité :** 
  - Protection via GitHub Environment `production` (approbation manuelle possible)
  - Plan sauvegardé comme artifact (rétention 30 jours)
  - Gère **uniquement l'infrastructure** (Lambda, API Gateway, RDS, S3, CloudFront, SSM, IAM, VPC, etc.)
  - **Ne déploie pas le code applicatif** (fait par les scripts `deploy-api.sh` et `deploy-web.sh` dans les repos `kambriq-api` et `kambriq-web`)

### Backend Terraform
- **Type :** S3 backend
- **Bucket :** `kloudnat-infra-shared-store`
- **Région :** `eu-central-1`
- **State files :**
  - `kambriq/shared/terraform.tfstate`
  - `kambriq/dev-v2/terraform.tfstate`
  - `kambriq/prod/terraform.tfstate` (V1)
- **Remote State :** `dev-v2` et `prod` consomment les outputs de `shared` via `terraform_remote_state`

### Gestion des Secrets
- **⚠️ IMPORTANT :** Terraform gère **une partie** de la configuration runtime dans SSM (paramètres applicatifs). Certains secrets/valeurs sensibles peuvent nécessiter une **mise à jour manuelle** selon les environnements.
- **Stockage :** SSM Parameter Store
- **Script :** `scripts/generate-and-store-secrets.sh`
- **SSM (créés par Terraform via `modules/ssm-app-parameters/`) :**
  - `/kambriq/{dev|prod}/db/url` (SecureString)
  - `/kambriq/{dev|prod}/api/JWT_SECRET` (SecureString, valeur ignorée par Terraform après création pour permettre mise à jour manuelle)
  - `/kambriq/{dev|prod}/api/SES_FROM_EMAIL` (String)

### Ordre de déploiement obligatoire
1. **Shared** → Déployer en premier
2. **Dev-v2** → Dépend de Shared
3. **Prod** → Dépend de Shared (V1, à migrer vers V2)

---

## 💻 Repository 2 : `kambriq-api`

### Description
Backend API KAMBRIQ v3.0 - FastAPI avec architecture DDD (Domain-Driven Design).

**⚠️ IMPORTANT :** Ce repository est **complètement nouveau** et **refait from scratch**. Aucun lien avec l'ancien code monorepo `kambriq`.

### Technologies
- FastAPI (Python 3.11+)
- SQLAlchemy ORM pour PostgreSQL
- Alembic pour migrations
- Pydantic pour validation
- JWT authentication (HttpOnly cookies)
- Architecture DDD (Domain-Driven Design)

### Structure
```
kambriq-api/
├── src/
│   ├── domain/          # Entities, repositories (interfaces)
│   ├── application/     # Use cases, DTOs
│   ├── infrastructure/  # Repositories implémentations, external services
│   └── presentation/    # FastAPI routers, guards, filters
├── alembic/             # Alembic migrations
├── tests/               # Tests (unit, integration, e2e)
├── scripts/             # Scripts de déploiement
│   ├── deploy-api.sh    # Script de déploiement
│   └── run-tests.sh     # Script de tests
├── requirements.txt     # Python dependencies
└── Dockerfile           # Multi-stage Docker build
```

### Déploiement
- **Local :** `uvicorn src.main:app --reload --port 8000`
- **Docker :** Image Docker multi-stage, port 8000
- **ECS Fargate :** Container sur ECS Service, port 8000

### Scripts principaux
- `./scripts/deploy-api.sh [dev|prod]` - Déploiement vers ECS
- `./scripts/run-tests.sh [unit|integration|e2e|all]` - Lance les tests
- `alembic upgrade head` - Applique les migrations
- `pytest` - Lance les tests

---

## 🌐 Repository 3 : `kambriq-web`

### Description
Frontend KAMBRIQ v3.0 - Next.js 16 avec React 19.

**⚠️ IMPORTANT :** Ce repository est **complètement nouveau** et **refait from scratch**. Aucun lien avec l'ancien code monorepo `kambriq`.

### Technologies
- Next.js 16 (App Router, standalone mode)
- React 19
- TypeScript
- Tailwind CSS
- Pas de NextAuth (JWT avec cookies HttpOnly côté API)

### Structure
```
kambriq-web/
├── app/                 # Next.js App Router
├── src/                 # Code source (components, lib, etc.)
├── public/              # Assets statiques
├── scripts/             # Scripts de déploiement
│   ├── deploy-web.sh    # Script de déploiement
│   └── run-tests.sh     # Script de tests
├── e2e/                 # Tests E2E (Playwright)
└── package.json         # Node.js dependencies
```

### Déploiement
- **Local :** `pnpm dev` (http://localhost:3000)
- **Docker :** Image Docker multi-stage, port 3000
- **ECS Fargate :** Container sur ECS Service, port 3000

### Scripts principaux
- `./scripts/deploy-web.sh [dev|prod]` - Déploiement vers ECS
- `./scripts/run-tests.sh [lint|types|e2e|all]` - Lance les tests
- `pnpm dev` - Serveur de développement
- `pnpm build` - Build Next.js (standalone mode)
- `pnpm lint` - Lint du code

---

## 🔗 Intégration entre les Repos

### 1. Séparation des Responsabilités

**Repository `kambriq-infra` :**
- Gère **uniquement l'infrastructure** via Terraform
- Crée et configure les ressources AWS (ECS, ALB, CloudFront, RDS, S3, SSM, IAM, VPC, etc.)
- Ne déploie **pas** le code applicatif

**Repository `kambriq-api` :**
- Gère le code backend API (FastAPI)
- Déploie via script `scripts/deploy-api.sh [dev|prod]`
- Effectue : build Docker, push ECR, update ECS service API

**Repository `kambriq-web` :**
- Gère le code frontend (Next.js)
- Déploie via script `scripts/deploy-web.sh [dev|prod]`
- Effectue : build Docker, push ECR, update ECS service Web

### 2. Flux de Déploiement

**Infrastructure (repo `kambriq-infra`) :**
1. Modifier le code Terraform si nécessaire
2. Exécuter `terraform-dev-v2.yml` pour mettre à jour l'infrastructure
3. Terraform crée/modifie les ressources AWS (ECS Cluster, Services, ALB, CloudFront, RDS, etc.)

**Application (repos `kambriq-api` et `kambriq-web`) :**
1. Modifier le code API ou Web dans le repository correspondant
2. Exécuter les scripts de déploiement :
   - `kambriq-api/scripts/deploy-api.sh [dev|prod]`
   - `kambriq-web/scripts/deploy-web.sh [dev|prod]`
3. Les scripts effectuent directement :
   - Build Docker image
   - Push vers ECR
   - Update ECS service (force new deployment)

### 3. Terraform Outputs → Variables d'environnement applicatif

**Mapping des outputs :**

| Terraform Output | Variable d'environnement | Usage |
|-----------------|---------------------------|-------|
| `alb_dns_name` | `NEXT_PUBLIC_API_BASE_URL` | API endpoint pour frontend |
| `cloudfront_domain` | `NEXT_PUBLIC_SITE_URL` | Site URL pour metadata |
| `rds_endpoint` | `DATABASE_URL` | Database connection string (via SSM) |
| `ecr_api_repo_uri` | - | URI pour push Docker image API |
| `ecr_web_repo_uri` | - | URI pour push Docker image Web |

### 4. Secrets Management

**Structure SSM Parameter Store :**
```
/kambriq/{dev|prod}/{db|api}/{parameter_name}
```

**Secrets API (stockés dans SSM) :**
- `/kambriq/dev/db/url` (requis) - Database connection string
- `/kambriq/dev/api/JWT_SECRET` (requis) - JWT secret
- `/kambriq/dev/api/SES_FROM_EMAIL` (requis) - Email expéditeur SES

**Chargement au runtime :**
- **API (ECS)** : Lit depuis SSM via variables d'environnement (secrets injectés par ECS)
- **Web (ECS)** : Variables d'environnement publiques (`NEXT_PUBLIC_*`)
- **Local** : Utilise `.env` (fichier local, non commité)

**GitHub Secrets :**
- Ne contiennent que des credentials techniques CI/CD (compte IAM, noms ECS, buckets, IDs CloudFront)
- Ne contiennent **pas** les secrets métier (ceux-ci sont dans SSM)

### 5. CI/CD Coordination

**Flux de déploiement :**

1. **Application (repos `kambriq-api` et `kambriq-web`) :**
   - Scripts de déploiement : `deploy-api.sh` et `deploy-web.sh`
   - Build Docker images → Push ECR → Update ECS services

2. **Infrastructure (repo `kambriq-infra`) :**
   - Scripts Terraform (`scripts/deploy-terraform.sh`) : Gestion de l'infrastructure uniquement
   - Créent/modifient les ressources AWS (ECS, ALB, CloudFront, RDS, S3, SSM, IAM, VPC, etc.)
   - Génèrent les outputs nécessaires (noms ECS, buckets, IDs CloudFront, etc.)

**Ordre recommandé :**
1. Déployer infrastructure `shared` → `dev-v2` → `prod-v2` (quand migré)
2. Créer les secrets dans SSM Parameter Store
3. Déployer application via scripts `deploy-api.sh` et `deploy-web.sh`

---

## 📊 Architecture Complète V2

```
┌─────────────────────────────────────────────────────────────┐
│                    KAMBRIQ Platform v2.0                     │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Frontend (Next.js 16 - Standalone)                   │   │
│  │  - ECS Fargate Service (port 3000)                   │   │
│  │  - Docker Image (ECR)                                 │   │
│  │  - Domain: dev.kambriq.com (dev) / kambriq.com (prod)│   │
│  └──────────────────────────────────────────────────────┘   │
│                          ↕ HTTP                              │
│  ┌──────────────────────────────────────────────────────┐
│  │  CloudFront Distribution                                  │   │
│  │  - Origin: ALB (HTTPS)                                  │   │
│  │  - Behaviors: /api/* (no cache), /* (cache static)     │   │
│  └──────────────────────────────────────────────────────┘   │
│                          ↕ HTTP                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  ALB (Application Load Balancer)                      │   │
│  │  - Routing Rules:                                      │   │
│  │    /api/* → FastAPI Target Group (port 8000)         │   │
│  │    /* → Next.js Target Group (port 3000)             │   │
│  └──────────────────────────────────────────────────────┘   │
│                          ↕ HTTP                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Backend (FastAPI)                                     │   │
│  │  - ECS Fargate Service (port 8000)                   │   │
│  │  - Docker Image (ECR)                                 │   │
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
│  │  - ECR Repositories (kambriq-api-{env}, kambriq-web-{env})│
│  │  - SES (Email: noreply@kambriq.com)                  │   │
│  │  - Route53 (DNS: kambriq.com)                        │   │
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
/kambriq/{environment}/{service}/{parameter_name}
```

**Secrets requis :**

**Dev :**
- `/kambriq/dev/db/url` - Database connection string
- `/kambriq/dev/api/JWT_SECRET` - Clé secrète JWT

**Prod :**
- `/kambriq/prod/db/url` - Database connection string
- `/kambriq/prod/api/JWT_SECRET` - Clé secrète JWT

**Script de génération :**
```bash
./scripts/generate-and-store-secrets.sh [dev|prod|all]
```

**⚠️ IMPORTANT :**
- Les secrets ne sont **jamais** dans Git ou Terraform outputs
- Les secrets sont stockés dans SSM Parameter Store
- ECS récupère les secrets via variables d'environnement (secrets injectés par ECS Task Definition)

---

## 🚀 Flux de Déploiement Complet

### 1. Infrastructure (repo `kambriq-infra`)

**Ordre obligatoire :**

```bash
# 1. Déployer shared (EN PREMIER)
cd kambriq-infra/envs/shared
terraform init
terraform plan
terraform apply

# 2. Configurer manuellement (après shared) :
# - Route53 hosted zone (récupérer zone_id)
# - SES domain/email identities (récupérer ARNs)
# - ACM certificates (récupérer ARNs)

# 3. Déployer dev-v2
cd ../dev-v2
terraform init
terraform plan  # Lit les outputs de shared via remote_state
terraform apply

# 4. Déployer prod-v2 (quand migré)
cd ../prod-v2
terraform init
terraform plan  # Lit les outputs de shared via remote_state
terraform apply
```

### 2. Secrets (SSM Parameter Store)

```bash
# Générer et stocker les secrets
cd kambriq-infra
./scripts/generate-and-store-secrets.sh all
```

### 3. Application (repos `kambriq-api` et `kambriq-web`)

**Déploiement via scripts :**
- Utiliser les scripts de déploiement dans chaque repository
- Build Docker images → Push ECR → Update ECS services

**Déploiement API :**
```bash
cd kambriq-api
./scripts/deploy-api.sh [dev|prod]
```

**Déploiement Web :**
```bash
cd kambriq-web
./scripts/deploy-web.sh [dev|prod]
```

---

## 📝 Technologies Principales

| Composant | Technologies |
|-----------|-------------|
| **Infrastructure** | Terraform 1.5.0+, AWS Provider ~> 5.0 |
| **Frontend** | Next.js 16 (standalone), React 19, Tailwind CSS 4, TypeScript |
| **Backend** | FastAPI (Python 3.11), SQLAlchemy, Alembic, PostgreSQL 15 |
| **Runtime** | Docker, ECS Fargate |
| **Package Manager** | pnpm 9.x (Web), pip (API) |
| **Docker** | Multi-stage builds, ECR |
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

4. **ACM Certificate** pour ALB (eu-central-1)
   - Certificat wildcard `*.kambriq.com` ou spécifique
   - Récupérer l'ARN
   - Ajouter dans `envs/shared/terraform.tfvars`

5. **ACM Certificate** pour CloudFront (us-east-1)
   - Certificat wildcard `*.kambriq.com` ou spécifique
   - Récupérer l'ARN
   - Ajouter dans `envs/dev-v2/terraform.tfvars` et `envs/prod-v2/terraform.tfvars`

**⚠️ CRITIQUE :** Sans ces configurations manuelles, les déploiements échoueront ou les ressources ne seront pas complètes.

### Ordre de Déploiement

**IMPORTANT :** Le stack `shared` doit être déployé **EN PREMIER** avant `dev-v2` et `prod-v2`.

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

### Repo Infrastructure (`kambriq-infra`)
- `README.md` - Vue d'ensemble
- `docs/architecture/ARCHITECTURE_V2_DETAILED.md` - Architecture détaillée V2
- `docs/architecture/ECS_FARGATE_CTO_CLARIFICATION.md` - Clarification ECS Fargate
- `docs/architecture/ECS_V2_ARCHITECTURE_SUMMARY.md` - Résumé architecture ECS V2
- `docs/setup/TERRAFORM_USAGE.md` - Guide d'usage Terraform
- `docs/integration/APP_INTEGRATION.md` - Guide d'intégration avec l'application
- `docs/setup/ACM_SES_MANUAL_SETUP.md` - Configuration manuelle SES/ACM
- `docs/setup/ROUTE53_DNS_SETUP.md` - Configuration DNS Route53

### Repo API (`kambriq-api`)
- `README.md` - Vue d'ensemble backend API
- `scripts/deploy-api.sh` - Script de déploiement
- `scripts/run-tests.sh` - Script de tests

### Repo Web (`kambriq-web`)
- `README.md` - Vue d'ensemble frontend
- `scripts/deploy-web.sh` - Script de déploiement
- `scripts/run-tests.sh` - Script de tests

---

## 💰 Optimisations Coûts

**Décisions prises pour réduire les coûts :**
- ✅ **1 seul NAT Gateway** (au lieu de 2) - Réduction ~$32/mois
- ✅ **RDS t4g.micro** - Instance la plus petite
- ✅ **20GB storage** - Minimum pour RDS
- ✅ **Backup retention 7j (dev)** - Minimum pour dev
- ✅ **ECS Fargate** - Pay-per-use (pas de coûts fixes pour instances)

**Coûts estimés MVP :**
- RDS t4g.micro : ~$15-20/mois
- ECS Fargate : Pay-per-use (gratuit jusqu'à 750h/mois)
- ALB : ~$16/mois
- CloudFront : Pay-per-use (gratuit jusqu'à 1To/mois)
- S3 : ~$0.023/Go/mois
- SES : Gratuit jusqu'à 62,000 emails/mois
- **Total estimé : ~$30-50/mois** (hors trafic)

---

## 🔄 Workflows GitHub Actions - Résumé

### Infrastructure (`kambriq-infra`)

| Workflow | Déclencheur | Actions |
|----------|-------------|---------|
| `terraform-shared.yml` | PR vers `main` | `terraform plan` (commentaire PR) |
| `terraform-shared.yml` | Push vers `main` | `terraform plan` + `apply` |
| `scripts/terraform-deploy.sh` ⭐ V2 | Script manuel | Infrastructure DEV/PROD V2 (ne déploie pas le code applicatif) |
| `terraform-prod-optimized.yml` ⚠️ V1 | Workflow Dispatch | Infrastructure PROD V1 uniquement (ne déploie pas le code applicatif) + protection environnement `production` |

### Application (`kambriq-api` et `kambriq-web`)

**Déploiement :**
- Scripts de déploiement dans chaque repository : `deploy-api.sh` et `deploy-web.sh`
- Build Docker images → Push ECR → Update ECS services

---

## ✅ Checklist de Déploiement Initial

### Infrastructure
- [ ] Déployer stack `shared`
- [ ] Configurer Route53 hosted zone (manuel)
- [ ] Configurer SES identities (manuel)
- [ ] Configurer ACM certificates (manuel)
- [ ] Déployer stack `dev-v2`
- [ ] Déployer stack `prod-v2` (quand migré)

### Secrets
- [ ] Générer secrets dev (`generate-and-store-secrets.sh dev`)
- [ ] Générer secrets prod (`generate-and-store-secrets.sh prod`)
- [ ] Vérifier que les secrets sont dans SSM Parameter Store

### Application
- [ ] Configurer secrets GitHub Actions (AWS credentials pour scripts de déploiement)
- [ ] Tester déploiement API DEV (`kambriq-api/scripts/deploy-api.sh dev`)
- [ ] Tester déploiement Web DEV (`kambriq-web/scripts/deploy-web.sh dev`)
- [ ] Tester déploiement API PROD (`kambriq-api/scripts/deploy-api.sh prod`)
- [ ] Tester déploiement Web PROD (`kambriq-web/scripts/deploy-web.sh prod`)
- [ ] Vérifier que l'application fonctionne avec l'infrastructure

### Intégration Infrastructure/Application
- [ ] Vérifier que l'infrastructure est déployée (via `scripts/deploy-terraform.sh`)
- [ ] Vérifier que les ECS services existent (créés par Terraform)
- [ ] Tester déploiement du code applicatif (via `deploy-api.sh` et `deploy-web.sh`)
- [ ] Vérifier que les containers ECS utilisent le nouveau code
- [ ] Vérifier que les health checks passent

---

**Dernière mise à jour :** 2026-01-13  
**Version :** 5.0 (Architecture 3 repos séparés - kambriq-infra, kambriq-api, kambriq-web)  
**Maintenu par :** Équipe Infrastructure KAMBRIQ
