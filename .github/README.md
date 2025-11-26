# GitHub Actions - Déploiement Infrastructure

Ce répertoire contient les workflows GitHub Actions pour déployer l'infrastructure Terraform.

## Workflows disponibles

- **`terraform-shared.yml`** : Déploie l'infrastructure partagée (VPC, Route53, SES, ACM)
- **`terraform-dev.yml`** : Déploie l'infrastructure de développement (RDS, Lambda, API Gateway, S3, CloudFront)
- **`terraform-prod.yml`** : Déploie l'infrastructure de production (même ressources que dev, avec sécurité renforcée)

## Configuration requise

### Secrets GitHub

Configurer les secrets suivants dans GitHub (Settings → Secrets and variables → Actions) :

#### Secrets globaux (utilisés par tous les environnements)
- `AWS_ACCESS_KEY_ID` : Clé d'accès AWS avec permissions pour créer les ressources
- `AWS_SECRET_ACCESS_KEY` : Clé secrète AWS
- `AWS_DEFAULT_REGION` : Région AWS (optionnel, défaut: `eu-central-1`)

#### Option : OIDC avec IAM Role (Recommandé)
- `AWS_ROLE_ARN` : ARN du rôle IAM pour l'authentification OIDC

**⚠️ Important** : Les secrets applicatifs (DB password, JWT secrets) ne sont **pas** stockés dans GitHub Secrets. Ils sont gérés via :
- **SSM Parameter Store** ou **AWS Secrets Manager** pour les secrets de production
- **Variables d'environnement Lambda** configurées directement (pas via Terraform variables)
- Les workflows Terraform ne gèrent que l'infrastructure, pas les secrets applicatifs

## Déclencheurs

### Workflow `terraform-shared.yml`
- **Pull Request vers `main`** : Exécute `terraform plan` et commente le PR
- **Push vers `main`** : Exécute `terraform plan` et `apply` automatiquement

### Workflow `terraform-dev.yml`
- **Push vers `develop`** : Exécute `terraform plan` et `apply` automatiquement
- **Workflow Dispatch** : Déclenchement manuel possible

### Workflow `terraform-prod.yml`
- **Workflow Dispatch** : Déclenchement manuel avec choix `plan` ou `apply`
- **Push vers tags `v*`** : Déclenchement automatique sur version tags (plan + apply)

## Déploiement manuel

### Pour la production :
1. Aller dans l'onglet "Actions" du repository
2. Sélectionner "Terraform - Prod Environment"
3. Cliquer sur "Run workflow"
4. Choisir `action = apply` dans le menu déroulant
5. Cliquer sur "Run workflow"

⚠️ **Note** : Pour la production, il est recommandé d'activer l'approbation manuelle dans GitHub (Settings → Environments → production).

## Permissions AWS requises

Le rôle/utilisateur AWS doit avoir les permissions pour :
- S3 (backend state, buckets)
- RDS (création de base de données)
- Lambda (création et gestion de fonctions)
- API Gateway (création d'APIs)
- CloudFront (création de distributions)
- SES (gestion d'identités)
- IAM (création de rôles et policies)
- VPC (gestion de security groups)
- CloudWatch Logs (pour Lambda)

