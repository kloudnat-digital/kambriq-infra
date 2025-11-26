# Guide des fichiers terraform.tfvars - KAMBRIQ

Ce document explique comment utiliser et compléter les fichiers `terraform.tfvars` pour chaque environnement.

## 📁 Emplacement des fichiers

Les fichiers `terraform.tfvars` sont situés dans :

- `envs/shared/terraform.tfvars` - Infrastructure partagée (VPC, Route53, SES, ACM)
- `envs/dev/terraform.tfvars` - Infrastructure de développement
- `envs/prod/terraform.tfvars` - Infrastructure de production

**⚠️ Important** : Ces fichiers sont ignorés par Git (`.gitignore`) car ils peuvent contenir des valeurs sensibles. Ne jamais les commiter.

## 🔐 Gestion des secrets

### Stratégie SSM Parameter Store

Les secrets (mots de passe DB, JWT secrets) sont **gérés via AWS SSM Parameter Store**, pas dans les fichiers `terraform.tfvars`.

Les modules Terraform récupèrent automatiquement les secrets depuis SSM via des data sources :

**DEV :**
- `/kambriq/dev/db/password` → Mot de passe de la base de données
- `/kambriq/dev/api/jwt_secret` → Secret JWT pour l'authentification

**PROD :**
- `/kambriq/prod/db/password` → Mot de passe de la base de données
- `/kambriq/prod/api/jwt_secret` → Secret JWT pour l'authentification

### Créer les secrets dans SSM

Avant de déployer l'infrastructure, créer les secrets dans SSM :

```bash
# DEV - Database password
aws ssm put-parameter \
  --name /kambriq/dev/db/password \
  --value "YOUR_STRONG_PASSWORD" \
  --type SecureString \
  --region eu-central-1

# DEV - JWT secret
aws ssm put-parameter \
  --name /kambriq/dev/api/jwt_secret \
  --value "YOUR_JWT_SECRET" \
  --type SecureString \
  --region eu-central-1

# PROD - Database password
aws ssm put-parameter \
  --name /kambriq/prod/db/password \
  --value "YOUR_STRONG_PASSWORD" \
  --type SecureString \
  --region eu-central-1

# PROD - JWT secret
aws ssm put-parameter \
  --name /kambriq/prod/api/jwt_secret \
  --value "YOUR_JWT_SECRET" \
  --type SecureString \
  --region eu-central-1
```

**⚠️ Production** : Pour la production, envisager d'utiliser AWS Secrets Manager au lieu de SSM Parameter Store pour une meilleure gestion des secrets.

## 📋 Configuration par environnement

### 1. Shared (`envs/shared/terraform.tfvars`)

Ce fichier est déjà configuré avec les valeurs par défaut. Aucune modification n'est nécessaire pour un déploiement standard.

**Variables configurées :**
- `aws_region` : Région AWS (eu-central-1)
- `vpc_cidr` : CIDR block pour la VPC (10.0.0.0/16)
- `domain_name` : Domaine principal (kambriq.com)
- `ses_from_email` : Email d'envoi SES (noreply@kambriq.com)
- `enable_s3_logs` : Activer le bucket S3 pour logs (true)
- `enable_s3_artifacts` : Activer le bucket S3 pour artifacts (true)

**Déploiement :**
```bash
cd envs/shared
terraform init
terraform plan
terraform apply
```

### 2. Dev (`envs/dev/terraform.tfvars`)

Ce fichier est déjà configuré avec les valeurs par défaut pour DEV.

**Note** : Les références VPC (vpc_id, subnet_ids) sont automatiquement récupérées depuis le stack `shared` via `terraform_remote_state` dans `main.tf`. Aucune configuration VPC n'est nécessaire dans ce fichier.

**Variables configurées :**
- `aws_region` : Région AWS (eu-central-1)
- Les secrets sont récupérés automatiquement depuis SSM (pas besoin de les définir)
- Les références VPC sont récupérées automatiquement depuis le stack shared

**Domaines personnalisés (optionnel) :**
- `cloudfront_domain` : Domaine CloudFront personnalisé (optionnel pour dev)
- `api_domain` : Domaine API Gateway personnalisé (optionnel pour dev)

**Déploiement :**
```bash
cd envs/dev
terraform init
terraform plan
terraform apply
```

### 3. Prod (`envs/prod/terraform.tfvars`)

Ce fichier est déjà configuré avec les valeurs par défaut pour PROD.

**Note** : Les références VPC (vpc_id, subnet_ids) sont automatiquement récupérées depuis le stack `shared` via `terraform_remote_state` dans `main.tf`. Aucune configuration VPC n'est nécessaire dans ce fichier.

**Variables configurées :**
- `aws_region` : Région AWS (eu-central-1)
- `ses_domain` : Domaine SES (kambriq.com)
- `ses_from_email` : Email d'envoi (noreply@kambriq.com)
- Les secrets sont récupérés automatiquement depuis SSM (pas besoin de les définir)
- Les références VPC sont récupérées automatiquement depuis le stack shared

**Domaines personnalisés (recommandé pour PROD) :**
- `cloudfront_domain` : Domaine CloudFront personnalisé (ex: app.kambriq.com)
- `api_domain` : Domaine API Gateway personnalisé (ex: api.kambriq.com)

**Déploiement :**
```bash
cd envs/prod
terraform init
terraform plan  # Toujours revoir le plan en production
terraform apply
```

## 🔄 Ordre de déploiement

**IMPORTANT** : Déployer les stacks dans cet ordre :

1. **Shared** (une seule fois)
   ```bash
   cd envs/shared
   terraform init && terraform plan && terraform apply
   ```

2. **Dev** (après shared)
   ```bash
   cd envs/dev
   # Les références VPC sont automatiquement récupérées depuis shared
   terraform init && terraform plan && terraform apply
   ```

3. **Prod** (après shared)
   ```bash
   cd envs/prod
   # Les références VPC sont automatiquement récupérées depuis shared
   terraform init && terraform plan && terraform apply
   ```

## ✅ Vérifications

### Vérifier que les secrets SSM existent

```bash
# DEV
aws ssm get-parameter --name /kambriq/dev/db/password --with-decryption --region eu-central-1
aws ssm get-parameter --name /kambriq/dev/api/jwt_secret --with-decryption --region eu-central-1

# PROD
aws ssm get-parameter --name /kambriq/prod/db/password --with-decryption --region eu-central-1
aws ssm get-parameter --name /kambriq/prod/api/jwt_secret --with-decryption --region eu-central-1
```

### Vérifier que terraform plan fonctionne

```bash
cd envs/dev  # ou envs/prod
terraform init
terraform plan
```

Si des erreurs apparaissent concernant des variables manquantes, vérifier que :
- Les secrets SSM existent (voir ci-dessus)
- Le stack `shared` est déployé (les références VPC sont récupérées automatiquement)

## 🔗 Liens utiles

- [Guide d'usage Terraform](./setup/TERRAFORM_USAGE.md)
- [Documentation infrastructure](../README.md)
- [Variables d'environnement applicatif](../../kambriq/docs/configuration/ENVIRONMENT_VARIABLES.md)

