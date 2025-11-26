# Génération et stockage des secrets - KAMBRIQ

Ce guide explique comment générer et stocker les secrets nécessaires pour déployer l'infrastructure KAMBRIQ.

## 🔐 Secrets requis

Pour chaque environnement (dev, prod), deux secrets sont nécessaires :

1. **Mot de passe de la base de données** (`/kambriq/{env}/db/password`)
   - Utilisé pour l'authentification PostgreSQL RDS
   - Minimum 16 caractères recommandé
   - Doit contenir majuscules, minuscules, chiffres et symboles

2. **Secret JWT** (`/kambriq/{env}/api/jwt_secret`)
   - Utilisé pour signer et vérifier les tokens JWT
   - Minimum 32 caractères recommandé
   - Doit être aléatoire et imprévisible

## 🚀 Méthode 1 : Script automatique (Recommandé)

Un script est fourni pour générer et stocker automatiquement les secrets :

```bash
# Générer les secrets pour DEV uniquement
./scripts/generate-and-store-secrets.sh dev

# Générer les secrets pour PROD uniquement
./scripts/generate-and-store-secrets.sh prod

# Générer les secrets pour DEV et PROD
./scripts/generate-and-store-secrets.sh all
```

**⚠️ Important** : Le script affiche les secrets générés une seule fois. Sauvegardez-les dans un gestionnaire de secrets (1Password, LastPass, etc.).

## 📝 Méthode 2 : Commandes manuelles

### Générer les secrets

#### Option A : OpenSSL (Linux/Mac)

```bash
# Générer un mot de passe DB fort (32 caractères)
openssl rand -base64 24 | tr -d "=+/" | cut -c1-32

# Générer un secret JWT (64 caractères)
openssl rand -base64 48 | tr -d "=+/" | cut -c1-64
```

#### Option B : Python

```bash
# Générer un mot de passe DB
python3 -c "import secrets; print(secrets.token_urlsafe(32))"

# Générer un secret JWT
python3 -c "import secrets; print(secrets.token_urlsafe(64))"
```

#### Option C : Node.js

```bash
# Générer un mot de passe DB
node -e "console.log(require('crypto').randomBytes(32).toString('base64'))"

# Générer un secret JWT
node -e "console.log(require('crypto').randomBytes(64).toString('base64'))"
```

### Stocker les secrets dans SSM Parameter Store

#### DEV - Database Password

```bash
aws ssm put-parameter \
  --name /kambriq/dev/db/password \
  --value "VOTRE_MOT_DE_PASSE_GENERE" \
  --type SecureString \
  --description "Database master password for KAMBRIQ DEV environment" \
  --region eu-central-1 \
  --tags "Key=Environment,Value=dev" "Key=ManagedBy,Value=Terraform"
```

#### DEV - JWT Secret

```bash
aws ssm put-parameter \
  --name /kambriq/dev/api/jwt_secret \
  --value "VOTRE_JWT_SECRET_GENERE" \
  --type SecureString \
  --description "JWT secret key for KAMBRIQ DEV API authentication" \
  --region eu-central-1 \
  --tags "Key=Environment,Value=dev" "Key=ManagedBy,Value=Terraform"
```

#### PROD - Database Password

```bash
aws ssm put-parameter \
  --name /kambriq/prod/db/password \
  --value "VOTRE_MOT_DE_PASSE_GENERE" \
  --type SecureString \
  --description "Database master password for KAMBRIQ PROD environment" \
  --region eu-central-1 \
  --tags "Key=Environment,Value=prod" "Key=ManagedBy,Value=Terraform"
```

#### PROD - JWT Secret

```bash
aws ssm put-parameter \
  --name /kambriq/prod/api/jwt_secret \
  --value "VOTRE_JWT_SECRET_GENERE" \
  --type SecureString \
  --description "JWT secret key for KAMBRIQ PROD API authentication" \
  --region eu-central-1 \
  --tags "Key=Environment,Value=prod" "Key=ManagedBy,Value=Terraform"
```

## ✅ Vérifier que les secrets existent

### Vérifier un secret (sans afficher la valeur)

```bash
# DEV - Database password
aws ssm get-parameter --name /kambriq/dev/db/password --region eu-central-1

# DEV - JWT secret
aws ssm get-parameter --name /kambriq/dev/api/jwt_secret --region eu-central-1

# PROD - Database password
aws ssm get-parameter --name /kambriq/prod/db/password --region eu-central-1

# PROD - JWT secret
aws ssm get-parameter --name /kambriq/prod/api/jwt_secret --region eu-central-1
```

### Vérifier et afficher la valeur (décryptée)

```bash
# DEV - Database password
aws ssm get-parameter \
  --name /kambriq/dev/db/password \
  --with-decryption \
  --region eu-central-1 \
  --query 'Parameter.Value' \
  --output text

# DEV - JWT secret
aws ssm get-parameter \
  --name /kambriq/dev/api/jwt_secret \
  --with-decryption \
  --region eu-central-1 \
  --query 'Parameter.Value' \
  --output text
```

## 🔄 Mettre à jour un secret existant

Si vous devez mettre à jour un secret existant :

```bash
aws ssm put-parameter \
  --name /kambriq/dev/db/password \
  --value "NOUVEAU_MOT_DE_PASSE" \
  --type SecureString \
  --overwrite \
  --region eu-central-1
```

**⚠️ Attention** : Mettre à jour le mot de passe DB nécessite également de mettre à jour la base de données RDS et les variables d'environnement Lambda.

## 🗑️ Supprimer un secret (si nécessaire)

```bash
aws ssm delete-parameter \
  --name /kambriq/dev/db/password \
  --region eu-central-1
```

**⚠️ Ne supprimez jamais un secret en production sans avoir un plan de remplacement.**

## 📋 Checklist de déploiement

Avant de déployer l'infrastructure, vérifier que :

- [ ] Les secrets DEV sont créés dans SSM
  - [ ] `/kambriq/dev/db/password`
  - [ ] `/kambriq/dev/api/jwt_secret`
- [ ] Les secrets PROD sont créés dans SSM
  - [ ] `/kambriq/prod/db/password`
  - [ ] `/kambriq/prod/api/jwt_secret`
- [ ] Les secrets sont sauvegardés dans un gestionnaire de secrets
- [ ] Les permissions AWS sont configurées pour accéder à SSM

## 🔗 Liens utiles

- [Guide terraform.tfvars](./TERRAFORM_TFVARS_GUIDE.md)
- [Documentation AWS SSM Parameter Store](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html)
- [Documentation AWS Secrets Manager](https://docs.aws.amazon.com/secretsmanager/)

