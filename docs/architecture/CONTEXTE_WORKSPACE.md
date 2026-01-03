# Contexte du Workspace KAMBRIQ

**Date de création :** 2025-01-27  
**Dernière mise à jour :** 2025-01-XX  
**Version :** 4.0 (Migration V2 complétée - ECS Fargate + FastAPI + Next.js)

---

## 📋 Vue d'ensemble

Le workspace KAMBRIQ contient **2 repositories distincts** qui travaillent ensemble pour déployer une plateforme complète sur AWS :

1. **`kambriq-aws-iac-terraform`** - Infrastructure as Code (Terraform)
2. **`kambriq`** - Application monorepo (API + Web)

---

## 🏗️ Repository 1 : `kambriq-aws-iac-terraform`

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

**✅ Migration V1 → V2 complétée (2025-01-XX) :**
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
- ✅ ECR : Repositories pour images Docker (kambriq-api-dev, kambriq-web-dev)
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
  - **Ne déploie pas le code applicatif** (fait par `deploy-v2-dev.yml` dans le repo `kambriq`)
  - Plan sauvegardé comme artifact

#### `terraform-prod-optimized.yml` ⚠️ V1 (À migrer)
- **Déclencheurs :**
  - Workflow Dispatch uniquement (manuel)
- **Fichiers surveillés :** `envs/prod/**`, `modules/**`
- **Sécurité :** 
  - Protection via GitHub Environment `production` (approbation manuelle possible)
  - Plan sauvegardé comme artifact (rétention 30 jours)
  - Gère **uniquement l'infrastructure** (Lambda, API Gateway, RDS, S3, CloudFront, SSM, IAM, VPC, etc.)
  - **Ne déploie pas le code applicatif** (fait par `deploy-app-prod-optimized.yml` dans le repo `kambriq`)

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

## 💻 Repository 2 : `kambriq`

### Description
Monorepo contenant l'application KAMBRIQ v2.0 avec backend et frontend.

### Structure
```
kambriq/
├── apps/
│   ├── api/        # Backend FastAPI + SQLAlchemy
│   └── web/        # Frontend Next.js (standalone)
├── docs/           # Documentation additionnelle
└── scripts/        # Scripts utilitaires
```

### API (`apps/api/`) - Backend FastAPI

**Technologies :**
- FastAPI (Python 3.11)
- SQLAlchemy ORM pour PostgreSQL
- Alembic pour migrations
- Pydantic pour validation
- JWT authentication (HttpOnly cookies)

**Structure :**
```
apps/api/
├── app/
│   ├── main.py           # Application FastAPI
│   ├── models/           # SQLAlchemy models
│   ├── schemas/          # Pydantic schemas
│   ├── routers/          # API routes
│   ├── services/         # Business logic
│   └── core/             # Configuration, security, database
├── alembic/              # Alembic migrations
├── requirements.txt      # Python dependencies
└── Dockerfile           # Multi-stage Docker build
```

**Déploiement :**
- **Local :** `uvicorn app.main:app --reload --port 8000`
- **Docker :** Image Docker multi-stage, port 8000
- **ECS Fargate :** Container sur ECS Service, port 8000

**Scripts principaux :**
- `uvicorn app.main:app --reload` - Démarre en mode watch (http://localhost:8000)
- `alembic upgrade head` - Applique les migrations
- `alembic revision --autogenerate -m "Description"` - Crée une nouvelle migration
- `pytest` - Lance les tests

**Docker Image :**
- Build : `docker build -f apps/api/Dockerfile -t kambriq-api:latest .`
- Push ECR : Automatique via GitHub Actions workflow `deploy-v2-dev.yml`

### Web (`apps/web/`) - Frontend Next.js

**Technologies :**
- Next.js 16 (App Router, standalone mode)
- React 19
- TypeScript
- Tailwind CSS 4
- i18next & react-i18next (FR/EN)
- React Query (@tanstack/react-query)
- shadcn/ui

**Fonctionnalités :**
- **KAMBRIQ Lands** : Browse and purchase verified land titles in Cameroon
- **KAMBRIQ Verify** : Verify land title authenticity (48-72h service)
- **KBS (KAMBRIQ Business School)** : Certified training in Cameroonian land transactions
- **KAMNET** : Network of certified land agents

**Configuration Next.js :**
- **Mode :** Standalone (pour Docker/ECS)
- **Output :** `standalone` (pas d'OpenNext)
- **Port :** 3000
- **Image optimization :** Activée (pas de Lambda@Edge)

**Scripts principaux :**
- `pnpm dev` - Serveur de dev (http://localhost:3000)
- `pnpm build` - Build Next.js (standalone mode)
- `pnpm start` - Démarre le serveur Next.js en mode production
- `pnpm lint` - Lint du code
- `pnpm check-types` - Vérification TypeScript

**Docker Image :**
- Build : `docker build -f apps/web/Dockerfile -t kambriq-web:latest .`
- Push ECR : Automatique via GitHub Actions workflow `deploy-v2-dev.yml`

### CI/CD - GitHub Actions

#### `ci.yml` - CI Global
**Déclencheurs :**
- `push` et `pull_request` sur `develop` et `main`

**Actions :**
- **Job `api`** : Install, lint, test (pytest)
- **Job `web`** : Install, lint, check-types

**Rôle :** CI global pour validation du code avant merge

#### `deploy-v2-dev.yml` ⭐ V2 - Déploiement DEV
**Déclencheurs :**
- Push sur `main` ou `develop` (si fichiers modifiés dans `apps/`)
- `workflow_dispatch` (manuel)

**Jobs :**
1. `build-and-push-api` : Build et push image Docker API vers ECR
2. `build-and-push-web` : Build et push image Docker Web vers ECR
3. `deploy-ecs` : Update ECS services (force new deployment)
4. `smoke-tests` : Tests automatiques (health checks)

**Rôle :** Déploiement automatique vers ECS Fargate (dev)

#### `deploy-v2-prod.yml` ⭐ V2 - Déploiement PROD
**Déclencheurs :**
- `workflow_dispatch` avec confirmation manuelle (input: "deploy-prod")

**Jobs :**
- Identique à `deploy-v2-dev.yml` mais pour production
- Protection via GitHub Environment `production`

**Rôle :** Déploiement manuel vers ECS Fargate (prod)

### Scripts Utilitaires

#### Déploiement Local (Docker Compose)
```bash
# Démarrer tous les services (PostgreSQL + API + Web)
docker-compose -f docker-compose.local.yml up -d

# Voir les logs
docker-compose -f docker-compose.local.yml logs -f

# Arrêter
docker-compose -f docker-compose.local.yml down
```

**URLs locales :**
- Frontend : http://localhost:3000
- API : http://localhost:8000
- API Docs : http://localhost:8000/docs
- PostgreSQL : localhost:5432

---

## 🔗 Intégration entre les Repos

### 1. Séparation des Responsabilités

**Repository `kambriq-aws-iac-terraform` :**
- Gère **uniquement l'infrastructure** via Terraform
- Crée et configure les ressources AWS (ECS, ALB, CloudFront, RDS, S3, SSM, IAM, VPC, etc.)
- Ne déploie **pas** le code applicatif

**Repository `kambriq` :**
- Gère le code applicatif (API + Web)
- Déploie le code via les workflows `deploy-v2-dev.yml` et `deploy-v2-prod.yml`
- Effectue directement : build Docker, push ECR, update ECS services

### 2. Flux de Déploiement

**Infrastructure (repo `kambriq-aws-iac-terraform`) :**
1. Modifier le code Terraform si nécessaire
2. Exécuter `terraform-dev-v2.yml` pour mettre à jour l'infrastructure
3. Terraform crée/modifie les ressources AWS (ECS Cluster, Services, ALB, CloudFront, RDS, etc.)

**Application (repo `kambriq`) :**
1. Modifier le code API ou Web
2. Exécuter `deploy-v2-dev.yml` ou `deploy-v2-prod.yml` pour déployer le nouveau code
3. Les workflows effectuent directement :
   - Build Docker images (API + Web)
   - Push vers ECR
   - Update ECS services (force new deployment)
   - Smoke tests

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

1. **Application (repo `kambriq`) :**
   - Workflows `deploy-v2-dev.yml` et `deploy-v2-prod.yml` : Déploiement direct du code applicatif (API + Web)
   - Build Docker images → Push ECR → Update ECS services

2. **Infrastructure (repo `kambriq-aws-iac-terraform`) :**
   - Workflows Terraform (`terraform-dev-v2.yml`) : Gestion de l'infrastructure uniquement
   - Créent/modifient les ressources AWS (ECS, ALB, CloudFront, RDS, S3, SSM, IAM, VPC, etc.)
   - Génèrent les outputs nécessaires (noms ECS, buckets, IDs CloudFront, etc.)

**Ordre recommandé :**
1. Déployer infrastructure `shared` → `dev-v2` → `prod-v2` (quand migré)
2. Créer les secrets dans SSM Parameter Store
3. Déployer application via workflows `deploy-v2-dev.yml` / `deploy-v2-prod.yml`

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
cd kambriq-aws-iac-terraform
./scripts/generate-and-store-secrets.sh all
```

### 3. Application (repo `kambriq`)

**Déploiement automatique (GitHub Actions) :**
- Push sur `main` ou `develop` → Workflow `deploy-v2-dev.yml` se déclenche automatiquement
- Build Docker images → Push ECR → Update ECS services

**Déploiement manuel :**
```bash
# Build et push API
cd apps/api
docker build -f Dockerfile -t kambriq-api-dev:latest .
docker tag kambriq-api-dev:latest \
  051551940370.dkr.ecr.eu-central-1.amazonaws.com/kambriq-api-dev:latest
docker push \
  051551940370.dkr.ecr.eu-central-1.amazonaws.com/kambriq-api-dev:latest

# Build et push Web
cd ../web
docker build -f Dockerfile -t kambriq-web-dev:latest .
docker tag kambriq-web-dev:latest \
  051551940370.dkr.ecr.eu-central-1.amazonaws.com/kambriq-web-dev:latest
docker push \
  051551940370.dkr.ecr.eu-central-1.amazonaws.com/kambriq-web-dev:latest

# Update ECS services
aws ecs update-service \
  --cluster kambriq-dev-cluster \
  --service kambriq-dev-api \
  --force-new-deployment \
  --region eu-central-1

aws ecs update-service \
  --cluster kambriq-dev-cluster \
  --service kambriq-dev-web \
  --force-new-deployment \
  --region eu-central-1
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

### Repo Infrastructure (`kambriq-aws-iac-terraform`)
- `README.md` - Vue d'ensemble
- `docs/architecture/ARCHITECTURE_V2_DETAILED.md` - Architecture détaillée V2
- `docs/architecture/ECS_FARGATE_CTO_CLARIFICATION.md` - Clarification ECS Fargate
- `docs/architecture/ECS_V2_ARCHITECTURE_SUMMARY.md` - Résumé architecture ECS V2
- `docs/setup/TERRAFORM_USAGE.md` - Guide d'usage Terraform
- `docs/integration/APP_INTEGRATION.md` - Guide d'intégration avec l'application
- `docs/setup/ACM_SES_MANUAL_SETUP.md` - Configuration manuelle SES/ACM
- `docs/setup/ROUTE53_DNS_SETUP.md` - Configuration DNS Route53

### Repo Application (`kambriq`)
- `README.md` - Vue d'ensemble monorepo
- `docs/deployment/DEPLOYMENT_ENVIRONMENTS.md` - Guide déploiement multi-environnements
- `docs/deployment/QUICK_START.md` - Guide démarrage rapide
- `docs/deployment/PIPELINE_OVERVIEW_V2.md` - Vue d'ensemble CI/CD V2
- `docs/architecture/` - Guides d'architecture V2

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

### Infrastructure (`kambriq-aws-iac-terraform`)

| Workflow | Déclencheur | Actions |
|----------|-------------|---------|
| `terraform-shared.yml` | PR vers `main` | `terraform plan` (commentaire PR) |
| `terraform-shared.yml` | Push vers `main` | `terraform plan` + `apply` |
| `terraform-dev-v2.yml` ⭐ V2 | PR vers `main` (plan), Push `main` (plan+apply), Workflow Dispatch (plan) | Infrastructure DEV V2 uniquement (ne déploie pas le code applicatif) |
| `terraform-prod-optimized.yml` ⚠️ V1 | Workflow Dispatch | Infrastructure PROD V1 uniquement (ne déploie pas le code applicatif) + protection environnement `production` |

### Application (`kambriq`)

| Workflow | Déclencheur | Actions |
|----------|-------------|---------|
| `ci.yml` | Push/PR sur `develop`, `main` | Lint, test, check-types (API + Web) |
| `deploy-v2-dev.yml` ⭐ V2 | Push sur `main`/`develop` (auto), Workflow Dispatch (manuel) | Déploiement applicatif DEV V2 : build Docker, push ECR, update ECS services |
| `deploy-v2-prod.yml` ⭐ V2 | Workflow Dispatch avec confirmation | Déploiement applicatif PROD V2 : même logique que dev, avec protection `production` |

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
- [ ] Configurer secrets GitHub Actions (AWS credentials pour workflows applicatifs)
- [ ] Tester workflow `ci.yml` (lint, test, check-types)
- [ ] Tester déploiement applicatif DEV (workflow `deploy-v2-dev.yml`)
- [ ] Tester déploiement applicatif PROD (workflow `deploy-v2-prod.yml`)
- [ ] Vérifier que l'application fonctionne avec l'infrastructure

### Intégration Infrastructure/Application
- [ ] Vérifier que l'infrastructure est déployée (via `terraform-dev-v2.yml`)
- [ ] Vérifier que les ECS services existent (créés par Terraform)
- [ ] Tester déploiement du code applicatif (via `deploy-v2-dev.yml` / `deploy-v2-prod.yml`)
- [ ] Vérifier que les containers ECS utilisent le nouveau code
- [ ] Vérifier que les health checks passent

---

**Dernière mise à jour :** 2025-01-XX  
**Version :** 4.0 (Migration V2 complétée - ECS Fargate + FastAPI + Next.js)  
**Maintenu par :** Équipe Infrastructure KAMBRIQ
