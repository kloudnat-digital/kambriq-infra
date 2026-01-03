# Migration KAMBRIQ V1 → V2.0 - COMPLÉTÉE ✅

**Date de migration :** 2025-01-XX  
**Status :** ✅ **MIGRATION COMPLÉTÉE**

---

## Résumé de la Migration

L'ancienne stack V1 (Lambda + OpenNext + NestJS + API Gateway) a été **complètement supprimée** et remplacée par la nouvelle stack V2 (ECS Fargate + ALB + CloudFront + FastAPI + Next.js).

---

## ✅ Ce qui a été supprimé (V1)

### Infrastructure

- ✅ Lambda functions (API + SSR)
- ✅ API Gateway HTTP API
- ✅ OpenNext infrastructure (S3 static + Lambda SSR)
- ✅ Modules Terraform V1 (`lambda-api`, `api-gateway`, `frontend`)
- ✅ Stacks Terraform V1 (`envs/dev`, `envs/prod`)
- ✅ S3 buckets V1 (`kambriq-static-dev`, `kambriq-verify-store-dev`)
- ✅ ECR repositories V1 (Lambda container images)

### Application

- ✅ NestJS backend (remplacé par FastAPI)
- ✅ OpenNext build pipeline (remplacé par Next.js classic)
- ✅ Lambda handlers et adapters
- ✅ NextAuth (remplacé par auth backend pur)

### Documentation

- ✅ Documentation V1 obsolète supprimée ou mise à jour
- ✅ Références à Lambda/OpenNext/NestJS nettoyées

---

## ✅ Ce qui a été créé (V2)

### Infrastructure Terraform

- ✅ **Modules V2 créés :**
  - `modules/ecs-cluster/` - ECS Cluster + CloudWatch Logs
  - `modules/alb/` - Application Load Balancer avec routing rules
  - `modules/cloudfront-v2/` - CloudFront Distribution (ALB origin)
  - `modules/iam-roles-ecs/` - IAM Roles pour ECS tasks
  - `modules/ecs-service/` - ECS Task Definition + Service

- ✅ **Configurations V2 créées :**
  - `envs/dev-v2/` - Configuration complète pour DEV
  - `envs/prod-v2/` - À créer (structure prête)

### Application

- ✅ **FastAPI Backend (`apps/api/`):**
  - Architecture clean (infrastructure, application, presentation)
  - JWT auth (access token 15 min + refresh cookie 7 jours)
  - SQLAlchemy + Alembic
  - Health endpoint (`/api/health`)
  - Dockerfile multi-stage optimisé

- ✅ **Next.js Frontend (`apps/web/`):**
  - Next.js classic (standalone mode, no OpenNext)
  - Middleware minimal (host canonical enforcement)
  - Auth client avec refresh automatique
  - Health endpoint (`/health`)
  - Dockerfile multi-stage optimisé

### CI/CD

- ✅ **GitHub Actions V2:**
  - `deploy-v2-dev.yml` - Build, push ECR, deploy ECS, smoke tests
  - `terraform-validate-v2.yml` - Validation Terraform V2

### Documentation

- ✅ **Documentation V2 complète :**
  - `docs/ARCHITECTURE_V2.md` - Architecture V2
  - `docs/ARCHITECTURE_V2_DETAILED.md` - Architecture détaillée (899 lignes)
  - `docs/BOOTSTRAP_V2.md` - Guide bootstrap V2
  - `docs/V2_IMPLEMENTATION_COMPLETE.md` - Récapitulatif implémentation
  - `docs/MIGRATION_COMPLETE.md` - Ce document

---

## 📋 Checklist de Migration

### Infrastructure

- [x] ✅ Infrastructure V1 supprimée (Lambda, API Gateway, OpenNext)
- [x] ✅ Infrastructure shared supprimée (recréer si nécessaire)
- [x] ✅ Modules Terraform V2 créés
- [x] ✅ Configuration `envs/dev-v2/` créée
- [x] ✅ S3 buckets V1 vidés et supprimés
- [x] ✅ ECR repositories V1 vidés

### Application

- [x] ✅ FastAPI backend implémenté
- [x] ✅ Next.js classic frontend (no OpenNext)
- [x] ✅ Dockerfiles multi-stage créés
- [x] ✅ Auth JWT + refresh cookies implémenté
- [x] ✅ Health endpoints créés

### CI/CD

- [x] ✅ Workflows GitHub Actions V2 créés
- [x] ✅ Scripts de migration créés

### Documentation

- [x] ✅ Documentation V1 obsolète supprimée
- [x] ✅ Documentation V2 complète créée
- [x] ✅ README principal mis à jour

---

## 🚀 Prochaines Étapes

### 1. Recréer Infrastructure Shared

```bash
cd kambriq-aws-iac-terraform/envs/shared
terraform init
terraform apply
```

### 2. Déployer Infrastructure V2

```bash
cd kambriq-aws-iac-terraform/envs/dev-v2
terraform init
terraform apply
```

### 3. Build et Push Images Docker

```bash
# API
cd kambriq/apps/api
docker build -t <ecr-api-uri>:latest .
docker push <ecr-api-uri>:latest

# Web
cd kambriq/apps/web
docker build -t <ecr-web-uri>:latest .
docker push <ecr-web-uri>:latest
```

### 4. Activer Services ECS

```bash
aws ecs update-service \
  --cluster kambriq-dev-cluster \
  --service kambriq-dev-api \
  --desired-count 1

aws ecs update-service \
  --cluster kambriq-dev-cluster \
  --service kambriq-dev-web \
  --desired-count 1
```

### 5. Tests de Validation

```bash
curl https://dev.kambriq.com/api/health
curl https://dev.kambriq.com/health
```

---

## 📊 Comparaison V1 vs V2

| Aspect | V1 (Supprimé) | V2 (Actuel) |
|--------|---------------|-------------|
| **Backend** | Lambda + NestJS | ECS Fargate + FastAPI |
| **Frontend** | OpenNext + Lambda SSR | Next.js Classic + ECS |
| **API Gateway** | API Gateway HTTP API | ALB avec routing rules |
| **Coût** | ~$20-35/mois | ~$66-81/mois |
| **Performance** | Cold start | Pas de cold start |
| **Scalabilité** | Auto (Lambda) | Auto (ECS) |
| **Complexité** | Faible | Moyenne |
| **Flexibilité** | Limitée | Élevée |

---

## ⚠️ Points d'Attention

1. **Infrastructure Shared** : Doit être recréée avant de déployer V2
2. **Certificats ACM** : CloudFront nécessite un certificat dans `us-east-1` (déjà configuré)
3. **Secrets SSM** : Les secrets existants sont réutilisés (pas besoin de recréer)
4. **RDS** : L'instance RDS peut être réutilisée (même schéma)

---

## 📚 Documentation V2

- **Architecture :** [`docs/ARCHITECTURE_V2.md`](ARCHITECTURE_V2.md)
- **Architecture détaillée :** [`docs/ARCHITECTURE_V2_DETAILED.md`](ARCHITECTURE_V2_DETAILED.md)
- **Bootstrap :** [`docs/BOOTSTRAP_V2.md`](BOOTSTRAP_V2.md)
- **Implémentation :** [`docs/V2_IMPLEMENTATION_COMPLETE.md`](V2_IMPLEMENTATION_COMPLETE.md)

---

**Status :** ✅ **MIGRATION COMPLÉTÉE - PRÊT POUR DÉPLOIEMENT V2**

