# GitHub Actions - Déploiement Infrastructure

Ce répertoire contient les workflows GitHub Actions pour déployer l'infrastructure Terraform.

## Workflows disponibles

**⚠️ Important** : Ces workflows gèrent **uniquement l'infrastructure** (création/modification des ressources AWS). Ils ne déploient **pas** le code applicatif. Les déploiements applicatifs sont effectués par les scripts `deploy-api.sh` et `deploy-web.sh` dans les repositories `kambriq-api` et `kambriq-web`.

- **`terraform-shared.yml`** : Déploie l'infrastructure partagée (VPC, Route53, SES, ACM)
- **`terraform-dev.yml`** ⭐ : Gère l'infrastructure DEV (plan/apply avec outputs, format check, commentaires PR)

## Configuration requise

### Secrets GitHub

Configurer les secrets suivants dans GitHub (Settings → Secrets and variables → Actions) :

#### Secrets pour `terraform-dev.yml`
- `AWS_ACCESS_KEY_ID_DEV` : Clé d'accès AWS avec permissions pour créer les ressources
- `AWS_SECRET_ACCESS_KEY_DEV` : Clé secrète AWS
- `AWS_REGION_DEV` : Région AWS (optionnel, défaut: `eu-central-1`)

#### Option : OIDC avec IAM Role (Recommandé)
- `AWS_ROLE_ARN` : ARN du rôle IAM pour l'authentification OIDC

**⚠️ Important** : Les secrets applicatifs (DB password, JWT secrets) ne sont **pas** stockés dans GitHub Secrets. Ils sont gérés via :

- **SSM Parameter Store** : Source de vérité pour les secrets runtime dev (prod-v2 à créer)
  - Structure de paths : `/kambriq/dev/api/...`, `/kambriq/dev/web/...`, `/kambriq/prod/api/...`, `/kambriq/prod/web/...` (quand prod-v2 sera créé)
  - Secrets stockés : `DATABASE_URL`, `JWT_SECRET`, `FRONTEND_URL`, `SES_FROM_EMAIL`, etc.
  - L'API et le Web (SSR) lisent depuis SSM au runtime via `@aws-sdk/client-ssm`
- **Local (.env)** : Utilisé uniquement pour le développement local sur la machine du développeur
- **GitHub Secrets** : Ne contiennent que des credentials techniques CI/CD (compte IAM, noms de Lambdas, buckets, IDs CloudFront)
- Les workflows Terraform ne gèrent que l'infrastructure, pas les secrets applicatifs

## Déclencheurs

### Workflow `terraform-shared.yml`
- **Pull Request vers `main`** : Exécute `terraform plan` et commente le PR
- **Push vers `main`** : Exécute `terraform plan` et `apply` automatiquement

### Workflow `terraform-dev.yml` ⭐ (2026-01-13)
- **Pull Request** vers `develop` : Plan uniquement (pas d'apply) + commentaire PR
- **Push** vers `develop` : Plan + Apply automatique
- **Workflow Dispatch** : Plan/Apply avec input `skip_apply` (optionnel)
- **Optimisations** : Format check, outputs dans GitHub Step Summary, commentaires PR automatiques
- **⚠️ Important** : Gère uniquement l'infrastructure, ne déploie pas le code applicatif

## Déploiement manuel

### Pour déployer le code applicatif :
Les déploiements applicatifs (mise à jour du code API + Web) sont effectués via les scripts de déploiement dans les repositories `kambriq-api` et `kambriq-web` :
- `kambriq-api/scripts/deploy-api.sh dev` - Déploie l'API vers ECS
- `kambriq-web/scripts/deploy-web.sh dev` - Déploie le Web vers ECS

## Permissions AWS requises

Le rôle/utilisateur AWS doit avoir les permissions pour :
- S3 (backend state, buckets)
- RDS (création de base de données)
- ECS (création et gestion de clusters et services)
- ALB (Application Load Balancer)
- CloudFront (création de distributions)
- SES (gestion d'identités)
- IAM (création de rôles et policies)
- VPC (gestion de security groups)
- CloudWatch Logs (pour ECS)

