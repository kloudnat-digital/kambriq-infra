# Statut de Déploiement - KAMBRIQ v3.0

**Date :** 2026-01-13  
**Status :** ✅ **INFRASTRUCTURE DÉPLOYÉE - PRÊT POUR APPLICATIONS**

---

## ✅ Infrastructure Déployée

### Stack Shared ✅

**Ressources créées :** 20 ressources

**Outputs :**
- VPC: `vpc-0b8f97775adf80c48` (10.0.0.0/16)
- 2 subnets publics (1 par AZ)
- 2 subnets privés (1 par AZ)
- 1 NAT Gateway unique: `nat-035806dc8ebfc5512` (optimisation coûts)
- Route53 zone: `kambriq.com` (Z00411721R2YKO3VFIPU4)
- ACM Certificate: `6f8bbf35-3058-4083-a8dd-f393d5012300`
- S3 Buckets: logs + artifacts

### Stack Dev-V2 ✅

**Ressources créées :** 27 ressources ajoutées, 1 modifiée, 1 supprimée

**Outputs :**
- RDS PostgreSQL: `kambriq-postgres-dev.ceqjohmcfzzp.eu-central-1.rds.amazonaws.com:5432`
- ECR API: `051551940370.dkr.ecr.eu-central-1.amazonaws.com/kambriq-api`
- ECR Web: `051551940370.dkr.ecr.eu-central-1.amazonaws.com/kambriq-web`
- ECS Cluster: `kambriq-dev-cluster`
- ECS Service API: `kambriq-dev-api`
- ECS Service Web: `kambriq-dev-web`
- ALB: `kambriq-dev-alb-2104799415.eu-central-1.elb.amazonaws.com`
- CloudFront: `E222RF7AAMDGC6` (dv4esw50nkgz5.cloudfront.net)

---

## 🔐 Paramètres SSM Parameter Store

**Total :** 27 paramètres créés

### Secrets Critiques (SecureString)

- ✅ `/kambriq/dev/db/password` - Mot de passe RDS
- ✅ `/kambriq/dev/api/DATABASE_URL` - URL complète PostgreSQL
- ✅ `/kambriq/dev/api/JWT_SECRET` - Secret JWT (depuis jwt_secret)
- ✅ `/kambriq/dev/api/jwt_secret` - Secret JWT (legacy, conservé)

### Configuration API (String)

- ✅ `/kambriq/dev/api/FRONTEND_URL` - `https://dev.kambriq.com`
- ✅ `/kambriq/dev/api/SES_FROM_EMAIL` - `noreply@kambriq.com`
- ✅ `/kambriq/dev/api/JWT_EXPIRES_IN` - `900`
- ✅ `/kambriq/dev/api/JWT_REFRESH_EXPIRES_IN` - `604800`
- ✅ `/kambriq/dev/api/JWT_ALGORITHM` - `HS256`
- ✅ `/kambriq/dev/api/COOKIE_SECURE` - `true`
- ✅ `/kambriq/dev/api/COOKIE_SAME_SITE` - `strict`
- ✅ `/kambriq/dev/api/COOKIE_DOMAIN` - `.kambriq.com`
- ✅ Et 10 autres paramètres de configuration

### Configuration Web (String)

- ✅ `/kambriq/dev/web/NEXT_PUBLIC_SITE_URL` - `https://dev.kambriq.com`
- ✅ `/kambriq/dev/web/NEXT_PUBLIC_API_BASE_URL` - `https://api.dev.kambriq.com`
- ✅ `/kambriq/dev/web/API_BASE_URL` - `https://api.dev.kambriq.com`
- ✅ Et 5 autres paramètres de configuration

---

## ☸️ Services ECS

| Service | Status | Running | Desired | Notes |
|---------|--------|---------|---------|-------|
| `kambriq-dev-api` | ACTIVE | 0/2 | 2 | ⚠️ Pas d'image Docker encore |
| `kambriq-dev-web` | ACTIVE | 2/2 | 2 | ✅ Running (image placeholder) |

**Note :** Le service API a 0 tasks car aucune image Docker n'a été pushée vers ECR. Le service Web a 2 tasks avec une image placeholder.

---

## 📋 Prochaines Étapes

### 1. Déployer l'Application Backend

```bash
cd /Users/vmi/workspace/kambriq-api
./scripts/deploy-api.sh dev
```

**Actions :**
- Build l'image Docker FastAPI
- Push vers ECR (`kambriq-api`)
- Update ECS service `kambriq-dev-api`
- Les tasks ECS démarreront avec la nouvelle image

**Vérification :**
```bash
# Vérifier les logs
aws logs tail /ecs/kambriq-dev-api --follow --region eu-central-1

# Vérifier le health check
curl https://api.dev.kambriq.com/health
```

### 2. Déployer l'Application Frontend

```bash
cd /Users/vmi/workspace/kambriq-web
./scripts/deploy-web.sh dev
```

**Actions :**
- Build l'image Docker Next.js
- Push vers ECR (`kambriq-web`)
- Update ECS service `kambriq-dev-web`
- Les tasks ECS seront mises à jour avec la nouvelle image

**Vérification :**
```bash
# Vérifier les logs
aws logs tail /ecs/kambriq-dev-web --follow --region eu-central-1

# Vérifier le site
curl https://dev.kambriq.com
```

### 3. Vérifier le Déploiement Complet

**Endpoints :**
- Frontend : `https://dev.kambriq.com`
- API : `https://api.dev.kambriq.com`
- API Health : `https://api.dev.kambriq.com/health`
- API Docs : `https://api.dev.kambriq.com/api/docs`

**Vérifications :**
```bash
# Health check API
curl https://api.dev.kambriq.com/health

# Vérifier les services ECS
aws ecs describe-services \
  --cluster kambriq-dev-cluster \
  --services kambriq-dev-api kambriq-dev-web \
  --region eu-central-1 \
  --query 'services[*].[serviceName,status,runningCount,desiredCount]' \
  --output table

# Vérifier les targets ALB
aws elbv2 describe-target-health \
  --target-group-arn $(aws elbv2 describe-target-groups \
    --names kambriq-dev-api-tg \
    --region eu-central-1 \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text) \
  --region eu-central-1
```

---

## ✅ Checklist de Validation

### Infrastructure

- [x] ✅ Stack `shared` déployé
- [x] ✅ Stack `dev-v2` déployé
- [x] ✅ Secrets SSM créés (27 paramètres)
- [x] ✅ RDS PostgreSQL créé
- [x] ✅ ECS Cluster créé
- [x] ✅ ECS Services créés
- [x] ✅ ALB créé
- [x] ✅ CloudFront créé
- [x] ✅ ECR Repositories créés

### Applications

- [ ] ⏳ API déployée (à faire)
- [ ] ⏳ Web déployé (à faire)
- [ ] ⏳ Health checks passent
- [ ] ⏳ Applications accessibles via CloudFront

---

## 🔗 URLs de Déploiement

| Service | URL | Status |
|---------|-----|--------|
| Frontend | `https://dev.kambriq.com` | ⏳ À déployer |
| API | `https://api.dev.kambriq.com` | ⏳ À déployer |
| API Health | `https://api.dev.kambriq.com/health` | ⏳ À déployer |
| API Docs | `https://api.dev.kambriq.com/api/docs` | ⏳ À déployer |

---

## 📊 Coûts Estimés

**Infrastructure actuelle :**
- RDS t4g.micro : ~$15-20/mois
- ECS Fargate : Pay-per-use (gratuit jusqu'à 750h/mois)
- ALB : ~$16/mois
- CloudFront : Pay-per-use (gratuit jusqu'à 1To/mois)
- NAT Gateway : ~$32/mois (1 seul - optimisé)
- S3 : ~$0.023/Go/mois
- **Total estimé : ~$60-70/mois** (hors trafic)

---

## 🎯 Status Global

**Infrastructure :** ✅ **100% DÉPLOYÉE**  
**Applications :** ⏳ **EN ATTENTE DE DÉPLOIEMENT**

**Prochaine action :** Déployer les applications (API + Web)

---

**Dernière mise à jour :** 2026-01-13  
**Maintenu par :** Infrastructure Team
