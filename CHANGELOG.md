# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
- Suppression des workflows non optimisés (`deploy-app-dev.yml`, `deploy-app-prod.yml`) dans le repo `kambriq`
- Suppression des scripts non optimisés (`deploy-dev.sh`, `deploy-prod.sh`, `deploy-dev-local.sh`) dans le repo `kambriq`

## [2025-12-07] - Refonte du pipeline CI/CD

### Changed
- **BREAKING** : Séparation complète des responsabilités infrastructure et applicatif
  - Terraform gère **uniquement l'infrastructure** (Lambda, API Gateway, RDS, S3, CloudFront, SSM, IAM, VPC, etc.)
  - Les déploiements applicatifs (mise à jour du code API + Web) sont désormais gérés exclusivement par les workflows optimisés `deploy-app-dev-optimized.yml` et `deploy-app-prod-optimized.yml` dans le repository `kambriq`
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
