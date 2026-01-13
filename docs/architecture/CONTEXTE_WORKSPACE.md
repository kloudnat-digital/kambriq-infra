# Contexte du Workspace KAMBRIQ

**Date de création :** 2025-01-27  
**Dernière mise à jour :** 2026-01-10  
**Version :** 5.0 (Refonte complète - 3 repos séparés)

---

## 📋 Vue d'ensemble

Le workspace KAMBRIQ contient **3 repositories distincts** qui travaillent ensemble pour déployer une plateforme complète sur AWS :

1. **`kambriq-aws-iac-terraform`** - Infrastructure as Code (Terraform)
2. **`kambriq-api`** - Backend API (FastAPI + SQLAlchemy + Alembic) - **Refait from scratch**
3. **`kambriq-web`** - Frontend (Next.js sans NextAuth) - **Refait from scratch**

**⚠️ IMPORTANT :** Les repos `kambriq-api` et `kambriq-web` sont **complètement nouveaux** et **refaits from scratch**. Aucun lien avec l'ancien code monorepo `kambriq`.

---

## 🏗️ Repository 1 : `kambriq-aws-iac-terraform`

### Description
Infrastructure AWS gérée via Terraform pour la plateforme KAMBRIQ v3.0.

### Architecture V3.0
**ECS Fargate + ALB + CloudFront** :
- **Frontend** : Next.js (standalone, ECS Fargate) - **Repo `kambriq-web`**
- **Backend** : FastAPI (ECS Fargate) - **Repo `kambriq-api`**
- **Load Balancing** : ALB avec routing rules (`/api/*` → FastAPI, `/*` → Next.js)
- **CDN** : CloudFront devant ALB
- **Base de données** : RDS PostgreSQL (t4g.micro)
- **Stockage** : S3 (médias/documents), ECR (images Docker)
- **Email** : SES (Simple Email Service)
- **Réseau** : VPC avec subnets publics/privés + NAT Gateway

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

#### 2. `envs/dev-v2/` - Environnement Développement V3.0 ⭐
**Ressources gérées :**
- ✅ RDS PostgreSQL : t4g.micro, 20GB gp3
- ✅ ECS Cluster : Fargate avec Container Insights
- ✅ ECS Service API : FastAPI (port 8000, 256 CPU, 512 MB)
  - **Autoscaling** : min 2, max 10 tasks, CPU > 60%
  - **Desired count** : 2 (élimination des cold starts)
  - **Image** : `kambriq-api` depuis ECR (repo `kambriq-api`)
- ✅ ECS Service Web : Next.js (port 3000, 256 CPU, 512 MB)
  - **Autoscaling** : min 2, max 10 tasks, CPU > 60%
  - **Desired count** : 2 (élimination des cold starts)
  - **Image** : `kambriq-web` depuis ECR (repo `kambriq-web`)
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

#### 3. `envs/prod/` - Environnement Production (À migrer vers V3.0)
**⚠️ Note :** L'environnement `prod` doit être migré vers V3.0 (ECS Fargate).

### Modules Terraform V3 (modules réutilisables)

**Modules Actifs V3 :**
1. **`modules/shared/`** - Infrastructure partagée (VPC, networking)
2. **`modules/rds-postgres/`** - Base de données PostgreSQL
3. **`modules/ecs-cluster/`** - ECS Cluster + Task Execution Role + CloudWatch Logs
4. **`modules/ecs-service/`** - ECS Task Definition + Service
5. **`modules/alb/`** - Application Load Balancer avec routing rules
6. **`modules/cloudfront-v2/`** - CloudFront Distribution (ALB origin)
7. **`modules/iam-roles-ecs/`** - IAM Roles pour ECS tasks (SSM, RDS)
8. **`modules/ecr-repository/`** - ECR repositories pour images Docker
9. **`modules/s3-media/`** - Bucket S3 médias/documents
10. **`modules/iam/`** - Rôles et policies IAM
11. **`modules/ssm-app-parameters/`** - SSM Parameter Store (secrets)

### Backend Terraform
- **Type :** S3 backend
- **Bucket :** `kloudnat-infra-shared-store`
- **Région :** `eu-central-1`
- **State files :**
  - `kambriq/shared/terraform.tfstate`
  - `kambriq/dev-v2/terraform.tfstate`
  - `kambriq/prod/terraform.tfstate` (V1, à migrer)
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
3. **Prod** → Dépend de Shared (V1, à migrer vers V3)

---

## 💻 Repository 2 : `kambriq-api`

### Description
Backend API pour KAMBRIQ, implémenté avec **FastAPI** et architecture **DDD (Domain-Driven Design)**.

**⚠️ NOUVEAU :** Ce repository est **complètement refait from scratch**. Aucun lien avec l'ancien code monorepo.

### Technologies
- **FastAPI** (Python 3.11+)
- **SQLAlchemy** ORM pour PostgreSQL
- **Alembic** pour migrations
- **Pydantic** pour validation
- **JWT authentication** (HttpOnly cookies)
- **bcrypt** pour hashage de mots de passe
- **Architecture DDD** : Domain, Application, Infrastructure, Presentation

### Structure
```
kambriq-api/
├── main.py                 # Point d'entrée FastAPI
├── Dockerfile              # Image Docker pour l'API
├── docker-compose.yml      # Configuration Docker Compose (local)
├── alembic/                # Migrations Alembic
│   └── versions/          # Fichiers de migration
├── scripts/                # Scripts utilitaires
│   └── seed_db.py          # Script de seeding
├── src/
│   ├── domain/             # Couche domaine
│   │   ├── entities/       # Entités métier (User, Role, Permission, etc.)
│   │   ├── repositories/   # Interfaces des repositories
│   │   ├── services/       # Interfaces des services (JWT, Password Hasher)
│   │   ├── exceptions/     # Exceptions métier
│   │   ├── enums/          # Énumérations
│   │   └── constants/      # Constantes
│   ├── application/        # Couche application
│   │   ├── dto/            # Data Transfer Objects (SigninDTO, SignupDTO, etc.)
│   │   └── use_cases/      # Use cases (SigninUseCase, SignupUseCase, etc.)
│   ├── infrastructure/     # Couche infrastructure
│   │   ├── database/       # Modèles SQLAlchemy, migrations, seeds
│   │   ├── repositories/   # Implémentations SQLAlchemy
│   │   ├── security/       # Sécurité (JWT, bcrypt)
│   │   └── dependencies.py # Injection de dépendances
│   └── presentation/       # Couche présentation
│       ├── routers/        # Routers FastAPI
│       ├── guards/         # Guards d'authentification
│       └── filters/        # Filtres d'exceptions
└── tests/                  # Tests (unitaires, intégration, E2E)
    ├── domain/
    ├── application/
    ├── infrastructure/
    └── e2e/
```

### Endpoints API

**Authentification :**
- `POST /api/v1/auth/signup` - Inscription d'un nouvel utilisateur
- `POST /api/v1/auth/signin` - Authentification (retourne access token + refresh token en cookie)
- `POST /api/v1/auth/logout` - Déconnexion (révocation du refresh token)
- `POST /api/v1/auth/resetpassword/request` - Demande de réinitialisation de mot de passe
- `POST /api/v1/auth/resetpassword/confirm` - Confirmation de réinitialisation avec token
- `GET /api/v1/auth/me` - Profil utilisateur actuel (protégé par Bearer token)
- `POST /api/v1/auth/refresh` - Rafraîchir le token d'accès

**Health :**
- `GET /` - Root endpoint
- `GET /health` - Health check (API + Database connectivity)

### Déploiement

**Local :**
```bash
# Installation
pip install -r requirements.txt
# ou
poetry install

# Configuration
cp .env.example .env
# Éditer .env avec les bonnes valeurs

# Migrations
alembic upgrade head

# Seed
python scripts/seed_db.py

# Démarrage
uvicorn main:app --reload --host 0.0.0.0 --port 3001
```

**Docker :**
```bash
docker-compose up -d
docker-compose exec api alembic upgrade head
docker-compose exec api python scripts/seed_db.py
```

**ECS Fargate :**
- Image Docker : `kambriq-api:latest` (ECR)
- Port : 8000
- Health check : `/health`

### Tests

```bash
# Tous les tests
pytest

# Tests unitaires
pytest tests/domain/ tests/application/ tests/infrastructure/security/

# Tests d'intégration
pytest tests/infrastructure/database/ tests/presentation/routers/

# Tests E2E
pytest tests/e2e/ -v
```

---

## 🌐 Repository 3 : `kambriq-web`

### Description
Frontend pour KAMBRIQ, implémenté avec **Next.js 16** (App Router, standalone mode).

**⚠️ NOUVEAU :** Ce repository est **complètement refait from scratch**. Aucun lien avec l'ancien code monorepo. **Pas de NextAuth** - authentification gérée via JWT et cookies HttpOnly.

### Technologies
- **Next.js 16** (App Router, standalone mode)
- **React 19**
- **TypeScript**
- **Tailwind CSS 4**
- **i18next & react-i18next** (FR/EN)
- **React Query** (@tanstack/react-query)
- **shadcn/ui**
- **JWT authentication** (cookies HttpOnly, pas NextAuth)

### Structure
```
kambriq-web/
├── app/                    # Next.js App Router
│   ├── (routes)/           # Routes de l'application
│   └── api/                # API routes (si nécessaire)
├── src/
│   ├── components/         # Composants React
│   │   ├── ui/             # Composants UI (shadcn/ui)
│   │   └── ...             # Autres composants
│   ├── views/              # Pages/Vues
│   │   ├── account/        # Pages compte (signin, signup, dashboard)
│   │   ├── home/           # Page d'accueil
│   │   └── ...             # Autres pages
│   ├── hooks/              # React hooks
│   ├── lib/                # Utilitaires
│   ├── config/             # Configuration
│   ├── types/              # Types TypeScript
│   └── utils/              # Fonctions utilitaires
├── public/                 # Assets statiques
├── e2e/                    # Tests E2E (Playwright)
└── scripts/                # Scripts utilitaires
```

### Fonctionnalités
- **KAMBRIQ Lands** : Browse and purchase verified land titles in Cameroon
- **KAMBRIQ Verify** : Verify land title authenticity (48-72h service)
- **KBS (KAMBRIQ Business School)** : Certified training in Cameroonian land transactions
- **KAMNET** : Network of certified land agents

### Déploiement

**Local :**
```bash
# Installation
npm install
# ou
pnpm install

# Configuration
cp .env.example .env.local
# Éditer .env.local avec les bonnes valeurs

# Démarrage
npm run dev
# ou
pnpm dev
```

**Docker :**
```bash
docker-compose up -d
```

**ECS Fargate :**
- Image Docker : `kambriq-web:latest` (ECR)
- Port : 3000
- Health check : `/health` (si configuré)

### Tests

```bash
# Lint
npm run lint

# Type check
npm run check-types

# Tests E2E (Playwright)
npm run test:e2e
```

---

## 🔗 Intégration entre les Repos

### 1. Séparation des Responsabilités

**Repository `kambriq-aws-iac-terraform` :**
- Gère **uniquement l'infrastructure** via Terraform
- Crée et configure les ressources AWS (ECS, ALB, CloudFront, RDS, S3, SSM, IAM, VPC, etc.)
- Ne déploie **pas** le code applicatif

**Repository `kambriq-api` :**
- Gère le code backend (FastAPI)
- Build et push l'image Docker vers ECR
- Déploiement via scripts locaux ou CI/CD

**Repository `kambriq-web` :**
- Gère le code frontend (Next.js)
- Build et push l'image Docker vers ECR
- Déploiement via scripts locaux ou CI/CD

### 2. Flux de Déploiement

**Infrastructure (repo `kambriq-aws-iac-terraform`) :**
1. Modifier le code Terraform si nécessaire
2. Exécuter `scripts/deploy-terraform.sh` pour mettre à jour l'infrastructure
3. Terraform crée/modifie les ressources AWS (ECS Cluster, Services, ALB, CloudFront, RDS, etc.)

**Application Backend (repo `kambriq-api`) :**
1. Modifier le code API
2. Exécuter `scripts/deploy-api.sh` pour déployer le nouveau code
3. Le script effectue :
   - Build Docker image
   - Push vers ECR
   - Update ECS service (force new deployment)

**Application Frontend (repo `kambriq-web`) :**
1. Modifier le code Web
2. Exécuter `scripts/deploy-web.sh` pour déployer le nouveau code
3. Le script effectue :
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

---

## 📊 Architecture Complète V3

```
┌─────────────────────────────────────────────────────────────┐
│                    KAMBRIQ Platform v3.0                     │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Frontend (Next.js 16 - Standalone)                   │   │
│  │  - Repo: kambriq-web                                   │   │
│  │  - ECS Fargate Service (port 3000)                   │   │
│  │  - Docker Image (ECR: kambriq-web)                    │   │
│  │  - Domain: dev.kambriq.com (dev) / kambriq.com (prod)│   │
│  └──────────────────────────────────────────────────────┘   │
│                          ↕ HTTP                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  CloudFront Distribution                              │   │
│  │  - Origin: ALB (HTTPS)                                │   │
│  │  - Behaviors: /api/* (no cache), /* (cache static)   │   │
│  └──────────────────────────────────────────────────────┘   │
│                          ↕ HTTP                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  ALB (Application Load Balancer)                      │   │
│  │  - Routing Rules:                                     │   │
│  │    /api/* → FastAPI Target Group (port 8000)         │   │
│  │    /* → Next.js Target Group (port 3000)             │   │
│  └──────────────────────────────────────────────────────┘   │
│                          ↕ HTTP                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Backend (FastAPI)                                     │   │
│  │  - Repo: kambriq-api                                   │   │
│  │  - ECS Fargate Service (port 8000)                   │   │
│  │  - Docker Image (ECR: kambriq-api)                    │   │
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
│  │  - ECR Repositories (kambriq-api, kambriq-web)       │   │
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

## 🚀 Scripts de Déploiement

### Scripts Terraform

**`scripts/deploy-terraform.sh`** - Déploiement infrastructure depuis local
- Déploie les stacks Terraform (shared, dev-v2, prod)
- Gère l'ordre de déploiement automatiquement
- Vérifie les prérequis (AWS CLI, Terraform)

### Scripts Application

**`kambriq-api/scripts/deploy-api.sh`** - Déploiement backend depuis local
- Build Docker image
- Push vers ECR
- Update ECS service (force new deployment)
- Vérifie le déploiement

**`kambriq-web/scripts/deploy-web.sh`** - Déploiement frontend depuis local
- Build Docker image
- Push vers ECR
- Update ECS service (force new deployment)
- Vérifie le déploiement

---

## 📝 Technologies Principales

| Composant | Technologies |
|-----------|-------------|
| **Infrastructure** | Terraform 1.9.4+, AWS Provider ~> 5.0 |
| **Frontend** | Next.js 16 (standalone), React 19, Tailwind CSS 4, TypeScript |
| **Backend** | FastAPI (Python 3.11), SQLAlchemy, Alembic, PostgreSQL 15 |
| **Runtime** | Docker, ECS Fargate |
| **Package Manager** | npm/pnpm (Web), pip/poetry (API) |
| **Docker** | Multi-stage builds, ECR |
| **Cloud** | AWS (eu-central-1) |
| **Database** | PostgreSQL 15 (RDS) |

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
   - Ajouter dans `envs/dev-v2/terraform.tfvars`

**⚠️ CRITIQUE :** Sans ces configurations manuelles, les déploiements échoueront ou les ressources ne seront pas complètes.

### Ordre de Déploiement

**IMPORTANT :** Le stack `shared` doit être déployé **EN PREMIER** avant `dev-v2` et `prod`.

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
- `docs/architecture/CONTEXTE_WORKSPACE.md` - Ce document
- `docs/setup/TERRAFORM_USAGE.md` - Guide d'usage Terraform
- `docs/integration/APP_INTEGRATION.md` - Guide d'intégration avec l'application

### Repo Backend (`kambriq-api`)
- `README.md` - Vue d'ensemble et guide d'installation
- `docs/` - Documentation API (si disponible)

### Repo Frontend (`kambriq-web`)
- `README.md` - Vue d'ensemble et guide d'installation
- `docs/` - Documentation frontend (si disponible)

---

## ✅ Checklist de Déploiement Initial

### Infrastructure
- [ ] Déployer stack `shared`
- [ ] Configurer Route53 hosted zone (manuel)
- [ ] Configurer SES identities (manuel)
- [ ] Configurer ACM certificates (manuel)
- [ ] Déployer stack `dev-v2`
- [ ] Déployer stack `prod` (quand migré)

### Secrets
- [ ] Générer secrets dev (`generate-and-store-secrets.sh dev`)
- [ ] Générer secrets prod (`generate-and-store-secrets.sh prod`)
- [ ] Vérifier que les secrets sont dans SSM Parameter Store

### Application
- [ ] Tester déploiement backend DEV (`scripts/deploy-api.sh`)
- [ ] Tester déploiement frontend DEV (`scripts/deploy-web.sh`)
- [ ] Vérifier que l'application fonctionne avec l'infrastructure

### Tests
- [ ] Lancer tests backend (`kambriq-api`: `pytest`)
- [ ] Lancer tests frontend (`kambriq-web`: `npm run test:e2e`)
- [ ] Vérifier que tous les tests passent

---

**Dernière mise à jour :** 2026-01-10  
**Version :** 5.0 (Refonte complète - 3 repos séparés)  
**Maintenu par :** Équipe Infrastructure KAMBRIQ
