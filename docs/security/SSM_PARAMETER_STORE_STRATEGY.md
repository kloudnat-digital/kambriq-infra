# SSM Parameter Store - Stratégie de Gestion des Secrets

**Date de création :** 2026-01-10  
**Version :** 1.0  
**Niveau :** CTO-GRADE  
**Status :** ✅ **APPROUVÉ - SOURCE UNIQUE DE VÉRITÉ**

---

## 🎯 Principe Fondamental

**AWS SSM Parameter Store est la SEULE source de vérité pour toutes les valeurs sensibles et de configuration runtime.**

Aucune valeur sensible ne doit être :
- ❌ Hardcodée dans le code Terraform
- ❌ Stockée dans `terraform.tfvars` (même si ignoré par Git)
- ❌ Passée via variables d'environnement Terraform (`TF_VAR_*`)
- ❌ Stockée dans GitHub Secrets (sauf credentials techniques CI/CD)
- ❌ Stockée dans des fichiers de configuration locaux commités

**✅ TOUTES les valeurs sensibles DOIVENT être stockées dans SSM Parameter Store.**

---

## 📋 Structure de Nommage SSM

### Convention de Nommage

```
/kambriq/{environment}/{service}/{parameter_name}
```

**Exemples :**
- `/kambriq/dev/db/password` - Mot de passe RDS (dev)
- `/kambriq/dev/db/url` - URL complète de connexion PostgreSQL (dev)
- `/kambriq/dev/api/JWT_SECRET` - Secret JWT pour l'API (dev)
- `/kambriq/dev/api/DATABASE_URL` - URL de connexion PostgreSQL (dev)
- `/kambriq/dev/api/SES_FROM_EMAIL` - Email expéditeur SES (dev)
- `/kambriq/prod/db/password` - Mot de passe RDS (prod)
- `/kambriq/prod/api/JWT_SECRET` - Secret JWT pour l'API (prod)

### Types de Paramètres

| Type | Usage | Exemples |
|------|-------|----------|
| **SecureString** | Secrets sensibles (mots de passe, clés JWT) | `/kambriq/{env}/db/password`, `/kambriq/{env}/api/JWT_SECRET` |
| **String** | Configuration non-sensible | `/kambriq/{env}/api/FRONTEND_URL`, `/kambriq/{env}/api/SES_FROM_EMAIL` |

---

## 🔐 Secrets Gérés par SSM

### Secrets Requis (Créés Manuellement AVANT Terraform)

Ces secrets **DOIVENT** être créés manuellement avant le premier `terraform apply` :

#### 1. Mot de Passe RDS

**Path :** `/kambriq/{env}/db/password`  
**Type :** `SecureString`  
**Création :**

```bash
# Générer un mot de passe fort
PASSWORD=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-32)

# Stocker dans SSM
aws ssm put-parameter \
  --name "/kambriq/dev/db/password" \
  --value "$PASSWORD" \
  --type SecureString \
  --description "Database master password for KAMBRIQ DEV environment" \
  --region eu-central-1 \
  --tags "Key=Environment,Value=dev" "Key=ManagedBy,Value=Manual"
```

**⚠️ CRITIQUE :** Ce secret est lu par Terraform via `data.aws_ssm_parameter` dans `envs/dev-v2/main.tf` et utilisé pour créer l'instance RDS.

#### 2. Secret JWT (Optionnel - Peut être créé par Terraform)

**Path :** `/kambriq/{env}/api/jwt_secret` (legacy) ou `/kambriq/{env}/api/JWT_SECRET` (nouveau)  
**Type :** `SecureString`  
**Création :**

```bash
# Générer un secret JWT fort (64 caractères)
JWT_SECRET=$(openssl rand -base64 48 | tr -d "=+/" | cut -c1-64)

# Stocker dans SSM
aws ssm put-parameter \
  --name "/kambriq/dev/api/jwt_secret" \
  --value "$JWT_SECRET" \
  --type SecureString \
  --description "JWT secret key for KAMBRIQ DEV API authentication" \
  --region eu-central-1 \
  --tags "Key=Environment,Value=dev" "Key=ManagedBy,Value=Manual"
```

**Note :** Si ce secret n'existe pas, Terraform le créera avec un placeholder que vous devrez mettre à jour manuellement.

### Secrets Créés Automatiquement par Terraform

Ces secrets sont créés automatiquement par Terraform via le module `ssm-app-parameters` :

#### 1. DATABASE_URL

**Path :** `/kambriq/{env}/api/DATABASE_URL`  
**Type :** `SecureString`  
**Valeur :** Construite automatiquement depuis les outputs RDS  
**Format :** `postgresql://{username}:{password}@{host}:{port}/{database}?schema=public`

**Création :** Automatique lors de `terraform apply` via le module `ssm-app-parameters`.

#### 2. JWT_SECRET (si n'existe pas)

**Path :** `/kambriq/{env}/api/JWT_SECRET`  
**Type :** `SecureString`  
**Valeur :** Lue depuis `/kambriq/{env}/api/jwt_secret` (legacy) ou placeholder

**Création :** Automatique lors de `terraform apply` si le secret legacy existe, sinon placeholder.

#### 3. FRONTEND_URL

**Path :** `/kambriq/{env}/api/FRONTEND_URL`  
**Type :** `String`  
**Valeur :** Depuis CloudFront output (ex: `https://dev.kambriq.com`)

**Création :** Automatique lors de `terraform apply`.

#### 4. SES_FROM_EMAIL

**Path :** `/kambriq/{env}/api/SES_FROM_EMAIL`  
**Type :** `String`  
**Valeur :** Depuis variable Terraform (ex: `noreply@kambriq.com`)

**Création :** Automatique lors de `terraform apply`.

---

## 🔄 Flux de Lecture des Secrets

### 1. Terraform (Infrastructure)

**Lecture depuis SSM :**

```hcl
# Dans envs/dev-v2/main.tf
data "aws_ssm_parameter" "db_password" {
  name = "/kambriq/${local.env}/db/password"
}

# Utilisation dans module RDS
module "rds_postgres" {
  # ...
  db_password = data.aws_ssm_parameter.db_password.value
}
```

**⚠️ IMPORTANT :** Terraform lit depuis SSM, mais ne stocke JAMAIS de secrets dans :
- Terraform state (sauf si nécessaire pour RDS, mais marqué `sensitive = true`)
- Terraform outputs
- Logs Terraform

### 2. ECS Tasks (Runtime Application)

**Injection via ECS Task Definition :**

```hcl
# Dans modules/ecs-service/main.tf
secrets = {
  DATABASE_URL = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/kambriq/${local.env}/db/url"
  JWT_SECRET   = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/kambriq/${local.env}/api/JWT_SECRET"
}
```

**Permissions IAM :**

Les ECS tasks ont des IAM roles avec permissions SSM :

```hcl
# Dans modules/iam-roles-ecs/main.tf
policy {
  resources = [
    "arn:aws:ssm:${var.aws_region}:*:parameter/kambriq/${var.env}/api/*",
    "arn:aws:ssm:${var.aws_region}:*:parameter/kambriq/${var.env}/db/*"
  ]
  actions = [
    "ssm:GetParameter",
    "ssm:GetParameters",
    "ssm:GetParametersByPath"
  ]
}
```

**Lecture par l'application :**

L'application (FastAPI) lit automatiquement depuis les variables d'environnement injectées par ECS, qui sont elles-mêmes récupérées depuis SSM.

---

## 🛡️ Sécurité et Bonnes Pratiques

### 1. Rotation des Secrets

**Stratégie :**

- **RDS Password :** Rotation manuelle via AWS Console ou CLI
- **JWT Secret :** Rotation manuelle (créer nouveau secret, mettre à jour SSM, redéployer application)

**Commande de rotation :**

```bash
# 1. Générer nouveau secret
NEW_SECRET=$(openssl rand -base64 48 | tr -d "=+/" | cut -c1-64)

# 2. Mettre à jour dans SSM
aws ssm put-parameter \
  --name "/kambriq/dev/api/JWT_SECRET" \
  --value "$NEW_SECRET" \
  --type SecureString \
  --overwrite \
  --region eu-central-1

# 3. Redéployer l'application pour prendre en compte le nouveau secret
```

### 2. Audit et Monitoring

**Vérification des secrets :**

```bash
# Lister tous les secrets pour un environnement
aws ssm get-parameters-by-path \
  --path "/kambriq/dev/" \
  --recursive \
  --region eu-central-1 \
  --query 'Parameters[*].[Name,Type,LastModifiedDate]' \
  --output table

# Vérifier qu'un secret existe
aws ssm get-parameter \
  --name "/kambriq/dev/db/password" \
  --with-decryption \
  --region eu-central-1
```

**CloudWatch Logs :**

Toutes les tentatives d'accès SSM sont loggées dans CloudTrail.

### 3. Séparation des Environnements

**⚠️ CRITIQUE :** Ne JAMAIS réutiliser les mêmes secrets entre dev et prod.

- `/kambriq/dev/*` - Secrets DEV uniquement
- `/kambriq/prod/*` - Secrets PROD uniquement

### 4. Lifecycle Management

**Terraform Lifecycle :**

```hcl
# Dans modules/ssm-app-parameters/main.tf
lifecycle {
  ignore_changes = [value]
  # Permet les mises à jour manuelles sans que Terraform les écrase
}
```

**Avantages :**
- Permet la rotation manuelle des secrets
- Terraform ne régénère pas les secrets à chaque `apply`
- Sécurité renforcée

---

## 📝 Checklist de Vérification

### Avant Déploiement

- [ ] Secret `/kambriq/{env}/db/password` créé manuellement
- [ ] Secret `/kambriq/{env}/api/jwt_secret` créé manuellement (optionnel)
- [ ] Aucun secret hardcodé dans `terraform.tfvars`
- [ ] Aucun secret dans les variables Terraform (`TF_VAR_*`)
- [ ] Permissions IAM ECS configurées pour lire SSM

### Après Déploiement

- [ ] Vérifier que `/kambriq/{env}/api/DATABASE_URL` existe et est correct
- [ ] Vérifier que `/kambriq/{env}/api/JWT_SECRET` existe et n'est pas un placeholder
- [ ] Vérifier que les ECS tasks peuvent lire depuis SSM (logs CloudWatch)
- [ ] Vérifier que l'application démarre correctement avec les secrets SSM

### Audit Régulier

- [ ] Vérifier que tous les secrets sont dans SSM (pas dans terraform.tfvars)
- [ ] Vérifier les dates de dernière modification des secrets
- [ ] Planifier la rotation des secrets (tous les 90 jours recommandé)
- [ ] Vérifier les permissions IAM (principe du moindre privilège)

---

## 🚨 Problèmes Courants et Solutions

### Problème 1 : Secret manquant dans SSM

**Symptôme :** `terraform apply` échoue avec `ParameterNotFound`

**Solution :**

```bash
# Créer le secret manquant
./scripts/generate-and-store-secrets.sh dev
```

### Problème 2 : ECS task ne peut pas lire SSM

**Symptôme :** Application démarre mais ne peut pas se connecter à la DB

**Solution :**

1. Vérifier les permissions IAM du task role
2. Vérifier que le secret existe dans SSM
3. Vérifier les logs CloudWatch de l'application

### Problème 3 : Terraform écrase un secret mis à jour manuellement

**Symptôme :** Secret mis à jour manuellement est réécrasé par Terraform

**Solution :**

Le module `ssm-app-parameters` utilise `lifecycle { ignore_changes = [value] }` pour éviter ce problème. Si le problème persiste, vérifier que le lifecycle est bien configuré.

---

## 📚 Références

- [AWS SSM Parameter Store Documentation](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html)
- [Terraform AWS SSM Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter)
- [ECS Secrets Integration](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/specifying-sensitive-data-secrets.html)

---

## ✅ Validation CTO

**Approuvé par :** Architecture Team  
**Date d'approbation :** 2026-01-10  
**Révision :** 1.0  
**Status :** ✅ **PRODUCTION READY**

**Garanties :**
- ✅ Aucun secret hardcodé dans le code
- ✅ SSM Parameter Store comme source unique de vérité
- ✅ Séparation complète dev/prod
- ✅ Rotation des secrets supportée
- ✅ Audit et monitoring en place
- ✅ Documentation complète

---

**Dernière mise à jour :** 2026-01-10  
**Maintenu par :** Infrastructure & Security Team
