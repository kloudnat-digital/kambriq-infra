# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2026-01-13] - Migration v3.0 - Architecture 3 repos séparés

### Removed
- **Stack PROD V1** : Suppression complète de `envs/prod/` (architecture Lambda obsolète)
- **Workflow PROD V1** : Suppression de `terraform-prod-optimized.yml` (workflow obsolète)
- **Références PROD V1** : Nettoyage de toutes les références à l'ancienne infrastructure PROD

### Added
- **Architecture v3.0** : Migration vers 3 repos séparés (kambriq-infra, kambriq-api, kambriq-web)
- **Script unifié de déploiement** : `scripts/deploy-terraform.sh` avec auto-approve et validation
- **Module SSM app parameters** : Création automatique des paramètres SSM pour applications
- **Documentation sécurité CTO-GRADE** : 
  - `docs/security/SSM_PARAMETER_STORE_STRATEGY.md` - Stratégie complète SSM
  - `docs/security/SECURITY_AUDIT_REPORT.md` - Audit sécurité complet
- **Documentation déploiement** :
  - `docs/DEPLOYMENT_SCRIPTS.md` - Guide scripts de déploiement
  - `docs/DEPLOYMENT_STATUS.md` - Statut déploiement
  - `docs/CLEANUP_COMPLETE.md` - Rapport de nettoyage

### Changed
- **CONTEXTE_WORKSPACE.md** : Mis à jour avec nouvelle structure (3 repos séparés)
- **Terraform dev-v2** : Ajout module SSM app parameters, correction référence DATABASE_URL
- **Scripts de déploiement** : Unification dans `deploy-terraform.sh` avec auto-approve
- **Workflows GitHub Actions** :
  - `terraform-dev-v2-optimized.yml` → `terraform-dev.yml` (renommé et simplifié)
  - Mis à jour avec commentaires v3.0
- **Documentation** : Nettoyage complet des références à l'ancien monorepo

### Removed
- **Workflows obsolètes** :
  - `terraform-dev-optimized.yml` (doublon)
  - `terraform-validate-v2.yml` (redondant)
  - `terraform-prod-optimized.yml` (PROD V1 obsolète)
- **Scripts obsolètes** :
  - `terraform-deploy-dev-v2.sh` (remplacé par `deploy-terraform.sh`)
  - `terraform-deploy-shared.sh` (remplacé par `deploy-terraform.sh`)
  - `validate-ecs-v2.sh` (validation via workflows)
- **Stacks obsolètes** :
  - `envs/prod/` (PROD V1 - architecture Lambda obsolète)
- **Documentation obsolète** :
  - `docs/archive/DEPLOYMENT_FIX_SUMMARY.md` (références ancien monorepo)
- **Références NextAuth** : Supprimées du module SSM (nouveau repo n'utilise pas NextAuth)

### Security
- **SSM Parameter Store** : Source unique de vérité pour tous les secrets
- **Audit sécurité** : Tous les secrets vérifiés dans SSM uniquement
- **Nettoyage** : Aucune référence obsolète, documentation sécurité complète

## [2026-01-03] - Migration V2 complétée et nettoyage

### Added
- **HTTPS sur ALB** : Configuration HTTPS avec certificat ACM pour l'ALB
- **Init Container ECS** : Support des migrations Alembic automatiques via init container
- **Scripts de déploiement** : Scripts automatisés pour déploiement Terraform (shared, dev-v2)
- **Documentation V2** : Architecture complète ECS Fargate documentée

### Changed
- **ALB Module** : Support conditionnel HTTPS (listener HTTPS si certificat présent)
- **ECS Service Module** : Format environment variables corrigé (tableau de paires clé-valeur)
- **ECR Repository Module** : Utilisation de data source pour référencer repositories existants
- **CloudFront Module** : Correction des headers forwarded (retrait Cookie)
- **Secrets Management** : SSM Parameter Store comme source unique de vérité
- **Documentation** : Consolidation et nettoyage (~44% de réduction)

### Removed
- **Documentation obsolète** : Fichiers de migration, vérification temporaire, guides redondants
- **Scripts obsolètes** : Scripts utilitaires non essentiels

## [2025-12-15] - Optimisations CI/CD

### Added
- **Workflows Terraform optimisés** :
  - `terraform-dev-optimized.yml` : Plan/apply avec format check, outputs GitHub Step Summary, commentaires PR automatiques
  - `terraform-prod-optimized.yml` : Plan/apply avec format check, outputs GitHub Step Summary, input `skip_apply` optionnel
- **Optimisations cold start Lambda** :
  - Migrations Prisma désactivées au cold start (gérées manuellement depuis bastion)
  - Express piné à 4.18.1 (compatibilité NestJS)
- **Credentials optionnels** : S3, SES, OAuth utilisent IAM roles en Lambda (credentials explicites uniquement pour dev local)
- **Variables alignées** : `AWS_S3_BUCKET_NAME` (remplace `S3_MEDIA_BUCKET`) pour cohérence infra/app

### Changed
- Documentation mise à jour pour référencer les workflows optimisés
- Suppression des workflows non optimisés (remplacés par scripts de déploiement dans kambriq-api et kambriq-web)
- Suppression des scripts non optimisés (`deploy-dev.sh`, `deploy-prod.sh`, `deploy-dev-local.sh`) dans le repo `kambriq`

## [2025-12-07] - Refonte du pipeline CI/CD

### Changed
- **BREAKING** : Séparation complète des responsabilités infrastructure et applicatif
  - Terraform gère **uniquement l'infrastructure** (Lambda, API Gateway, RDS, S3, CloudFront, SSM, IAM, VPC, etc.)
  - Les déploiements applicatifs (mise à jour du code API + Web) sont désormais gérés exclusivement par les scripts `deploy-api.sh` et `deploy-web.sh` dans les repositories `kambriq-api` et `kambriq-web`
  - Les workflows Terraform optimisés (`terraform-dev-optimized.yml`, `terraform-prod-optimized.yml`) ne gèrent plus le déploiement du code applicatif
  - Suppression des inputs `api_s3_key` et `web_s3_key` des workflows Terraform (plus nécessaires)
- **BREAKING** : Standardisation de la gestion des secrets sur AWS SSM Parameter Store
  - Structure de paths : `/kambriq/dev/api/...`, `/kambriq/dev/web/...`, `/kambriq/prod/api/...`, `/kambriq/prod/web/...`
  - Secrets applicatifs (DATABASE_URL, JWT_SECRET, FRONTEND_URL, SES_FROM_EMAIL) stockés dans SSM
  - GitHub Secrets ne contiennent que des credentials techniques CI/CD (compte IAM, noms de Lambdas, buckets, IDs CloudFront)
  - Terraform configure uniquement l'infrastructure, les secrets applicatifs sont lus depuis SSM au runtime par l'application

### Changed (Workflows)
- `terraform-dev-optimized.yml` : Optimisé avec format check, outputs GitHub Step Summary, commentaires PR automatiques, input `skip_apply`
  - Déclenchement : Pull Request (plan avec commentaire), Push sur `develop` (plan + apply avec outputs), Workflow Dispatch (plan/apply avec `skip_apply`)
- `terraform-prod-optimized.yml` : Optimisé avec format check, outputs GitHub Step Summary, input `skip_apply`
  - Déclenchement : Workflow Dispatch uniquement (manuel) avec input `skip_apply` (optionnel)
  - Protection via GitHub Environment `production`

### Removed
- Workflows Terraform non optimisés (`terraform-dev.yml`, `terraform-prod.yml`) - remplacés par versions optimisées
- Références aux anciens mécanismes de déploiement applicatif via Terraform
- Inputs workflow pour artefacts S3 applicatifs (plus nécessaires)
- Variables Terraform liées aux bundles applicatifs

## [Unreleased]

### Added
- Infrastructure Terraform modulaire pour KAMBRIQ sur AWS
- Modules réutilisables (frontend, lambda-api, rds-postgres, api-gateway, iam, etc.)
- Stacks séparés (shared, dev, prod)
- Workflows GitHub Actions pour déploiement infrastructure

## [2025-12-XX] - Ajout des buckets Verify (DEV & PROD)

### Added
- **Buckets S3 Verify Store** : Ajout de deux buckets S3 dédiés au module Verify
  - DEV : `kambriq-verify-store-dev` (protégé contre la suppression avec `prevent_destroy = true`)
  - PROD : `kambriq-verify-store-prod` (protégé contre la suppression avec `prevent_destroy = true`)
  - Configuration : Versioning activé, chiffrement AES256, blocage d'accès public complet
  - Outputs : `verify_store_bucket_name` ajouté dans `envs/dev/outputs.tf` et `envs/prod/outputs.tf`
