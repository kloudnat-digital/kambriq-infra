# Nettoyage Terraform V1 - Rapport

**Date :** 2025-01-XX  
**Status :** ✅ **NETTOYAGE COMPLÉTÉ**

---

## Modules V1 Supprimés

Les modules Terraform V1 suivants ont été supprimés car obsolètes :

1. ✅ `modules/lambda-api/` - Lambda API (NestJS)
2. ✅ `modules/api-gateway/` - API Gateway HTTP API
3. ✅ `modules/frontend/` - Frontend OpenNext (S3 + CloudFront + Lambda SSR)
4. ✅ `modules/cloudfront/` - CloudFront V1 (remplacé par `cloudfront-v2/`)
5. ✅ `modules/s3-static-site/` - S3 static site (V1)

**Raison :** Ces modules étaient utilisés pour l'architecture V1 (Lambda + OpenNext + NestJS) qui a été supprimée et remplacée par V2 (ECS Fargate + FastAPI + Next.js + ALB).

---

## Configurations Environnements

### ✅ `envs/dev/` → `legacy/envs/dev-v1/`

**Action :** Déplacé vers `legacy/envs/dev-v1/`

**Raison :** L'infrastructure V1 dev a été détruite. La nouvelle configuration V2 se trouve dans `envs/dev-v2/`.

**Status :** Infrastructure V1 détruite le 2025-12-31

### ⚠️ `envs/prod/` - À Migrer

**Status :** Utilise encore les modules V1

**Action requise :**
1. Créer `envs/prod-v2/` avec la configuration V2 (basée sur `envs/dev-v2/`)
2. Migrer l'infrastructure prod vers V2
3. Supprimer `envs/prod/` une fois la migration complétée

**Note :** Un fichier `README.md` a été ajouté dans `envs/prod/` pour documenter ce statut.

### ✅ `envs/dev-v2/` - Configuration V2

**Status :** Configuration V2 active pour dev

**Modules utilisés :**
- `modules/alb/` - Application Load Balancer
- `modules/ecs-cluster/` - ECS Cluster
- `modules/ecs-service/` - ECS Service
- `modules/cloudfront-v2/` - CloudFront V2
- `modules/ecr-repository/` - ECR repositories
- `modules/rds-postgres/` - RDS PostgreSQL
- `modules/iam-roles-ecs/` - IAM roles ECS

---

## Scripts Déplacés

Les scripts suivants liés à V1 ont été déplacés vers `legacy/` :

1. ✅ `scripts/deploy-nextauth-fix.sh` - NextAuth fix (V1)
2. ✅ `scripts/fix-nextauth-routing.sh` - NextAuth routing (V1)
3. ✅ `scripts/setup-nextauth-ssm.sh` - NextAuth SSM (V1)

**Raison :** Ces scripts concernaient l'architecture V1 (NextAuth n'est plus utilisé en V2, remplacé par FastAPI JWT).

---

## Modules Conservés (Réutilisés V2)

Les modules suivants sont conservés car réutilisés en V2 :

- ✅ `modules/shared/` - VPC, subnets, NAT Gateway (réutilisé)
- ✅ `modules/rds-postgres/` - RDS PostgreSQL (réutilisé)
- ✅ `modules/ecr-repository/` - ECR repositories (réutilisé)
- ✅ `modules/s3-media/` - S3 media bucket (réutilisé)
- ✅ `modules/bastion/` - Bastion host (réutilisé)
- ✅ `modules/ssm-app-parameters/` - SSM parameters (réutilisé)
- ✅ `modules/iam/` - IAM roles (partiellement réutilisé)

---

## Modules V2 Créés

Les modules suivants ont été créés pour V2 :

- ✅ `modules/alb/` - Application Load Balancer
- ✅ `modules/ecs-cluster/` - ECS Cluster
- ✅ `modules/ecs-service/` - ECS Service
- ✅ `modules/cloudfront-v2/` - CloudFront V2 (ALB origin)
- ✅ `modules/iam-roles-ecs/` - IAM roles pour ECS tasks

---

## Structure Finale

```
kambriq-aws-iac-terraform/
├── modules/
│   ├── alb/                    # ✅ V2
│   ├── cloudfront-v2/          # ✅ V2
│   ├── ecs-cluster/            # ✅ V2
│   ├── ecs-service/            # ✅ V2
│   ├── ecr-repository/         # ✅ Réutilisé
│   ├── rds-postgres/           # ✅ Réutilisé
│   ├── shared/                 # ✅ Réutilisé
│   ├── s3-media/               # ✅ Réutilisé
│   ├── bastion/                # ✅ Réutilisé
│   ├── iam/                    # ✅ Réutilisé
│   ├── iam-roles-ecs/          # ✅ V2
│   └── ssm-app-parameters/     # ✅ Réutilisé
├── envs/
│   ├── dev-v2/                 # ✅ Configuration V2 dev
│   ├── prod/                    # ⚠️ V1 (à migrer)
│   └── shared/                  # ✅ Infrastructure partagée
└── legacy/
    ├── envs/
    │   └── dev-v1/              # ✅ Configuration V1 dev (obsolète)
    └── scripts/                 # ✅ Scripts V1 obsolètes
```

---

## Checklist

- [x] ✅ Modules V1 supprimés
- [x] ✅ `envs/dev/` déplacé vers `legacy/envs/dev-v1/`
- [x] ✅ Scripts V1 déplacés vers `legacy/`
- [x] ✅ README ajouté dans `envs/prod/` pour documenter le statut
- [x] ✅ README ajouté dans `legacy/envs/dev-v1/`
- [x] ✅ Document de nettoyage créé

---

## Prochaines Étapes

1. **Migrer prod vers V2 :**
   - Créer `envs/prod-v2/` basé sur `envs/dev-v2/`
   - Déployer infrastructure V2 prod
   - Migrer données si nécessaire
   - Supprimer `envs/prod/` (V1)

2. **Nettoyer scripts obsolètes :**
   - Vérifier autres scripts dans `scripts/` qui pourraient être obsolètes
   - Déplacer vers `legacy/` si nécessaire

---

**Status :** ✅ **NETTOYAGE TERRAFORM V1 COMPLÉTÉ**

