# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2025-12-07] - Refonte du pipeline CI/CD

### Changed
- **BREAKING** : Séparation complète des responsabilités infrastructure et applicatif
  - Terraform gère **uniquement l'infrastructure** (Lambda, API Gateway, RDS, S3, CloudFront, SSM, IAM, VPC, etc.)
  - Les déploiements applicatifs (mise à jour du code API + Web) sont désormais gérés exclusivement par les workflows `deploy-app-dev.yml` et `deploy-app-prod.yml` dans le repository `kambriq`
  - Les workflows Terraform (`terraform-dev.yml`, `terraform-prod.yml`) ne gèrent plus le déploiement du code applicatif
  - Suppression des inputs `api_s3_key` et `web_s3_key` des workflows Terraform (plus nécessaires)
- **BREAKING** : Standardisation de la gestion des secrets sur AWS SSM Parameter Store
  - Structure de paths : `/kambriq/dev/api/...`, `/kambriq/dev/web/...`, `/kambriq/prod/api/...`, `/kambriq/prod/web/...`
  - Secrets applicatifs (DATABASE_URL, JWT_SECRET, FRONTEND_URL, SES_FROM_EMAIL) stockés dans SSM
  - GitHub Secrets ne contiennent que des credentials techniques CI/CD (compte IAM, noms de Lambdas, buckets, IDs CloudFront)
  - Terraform configure uniquement l'infrastructure, les secrets applicatifs sont lus depuis SSM au runtime par l'application

### Changed (Workflows)
- `terraform-dev.yml` : Simplifié pour ne gérer que l'infrastructure
  - Déclenchement : Pull Request (plan uniquement), Push sur `develop` (plan + apply), Workflow Dispatch (plan uniquement)
  - Suppression des inputs `api_s3_key` et `web_s3_key`
  - Suppression des variables `TF_VAR_api_bundle_s3_key` et `TF_VAR_ssr_bundle_s3_key`
- `terraform-prod.yml` : Simplifié pour ne gérer que l'infrastructure
  - Déclenchement : Workflow Dispatch uniquement (manuel)
  - Protection via GitHub Environment `production`
  - Suppression des inputs `api_s3_key` et `web_s3_key`
  - Suppression des variables `TF_VAR_api_bundle_s3_key` et `TF_VAR_ssr_bundle_s3_key`

### Removed
- Références aux anciens mécanismes de déploiement applicatif via Terraform
- Inputs workflow pour artefacts S3 applicatifs (plus nécessaires)
- Variables Terraform liées aux bundles applicatifs

## [Unreleased]

### Added
- Infrastructure Terraform modulaire pour KAMBRIQ sur AWS
- Modules réutilisables (frontend, lambda-api, rds-postgres, api-gateway, iam, etc.)
- Stacks séparés (shared, dev, prod)
- Workflows GitHub Actions pour déploiement infrastructure
