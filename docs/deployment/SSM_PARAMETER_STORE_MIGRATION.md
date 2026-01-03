# Migration Terraform vers SSM Parameter Store

**Date :** 2026-01-03  
**Objectif :** Utiliser SSM Parameter Store comme source unique de vérité pour tous les secrets

---

## ✅ Modifications Effectuées

### 1. `envs/dev-v2/main.tf`

**Avant :**
```hcl
module "rds_postgres" {
  # ...
  db_username = var.db_username
  db_password = var.db_password
}
```

**Après :**
```hcl
# SSM Parameter Store - Secrets
data "aws_ssm_parameter" "db_password" {
  name = "/kambriq/${local.env}/db/password"
}

locals {
  db_username = "kambriq_admin"
}

module "rds_postgres" {
  # ...
  db_username = local.db_username
  db_password = data.aws_ssm_parameter.db_password.value
}
```

### 2. `envs/dev-v2/variables.tf`

**Supprimé :**
- `variable "db_username"` (sensitive)
- `variable "db_password"` (sensitive)

**Ajouté :**
- Documentation expliquant que les secrets proviennent de SSM Parameter Store

### 3. `envs/dev-v2/terraform.tfvars`

**Supprimé :**
- `db_username = "kambriq_admin"`
- `db_password = "CHANGE_ME_SECURE_PASSWORD"`

**Ajouté :**
- Documentation complète sur l'utilisation de SSM Parameter Store
- Instructions pour créer les secrets avant le déploiement

### 4. `scripts/terraform-deploy-dev-v2.sh`

**Ajouté :**
- Vérification automatique que `/kambriq/dev/db/password` existe dans SSM
- Message d'erreur avec instructions si le secret est manquant

---

## 🔐 Configuration SSM Parameter Store

### Paramètres Requis

| Paramètre | Type | Description |
|-----------|------|-------------|
| `/kambriq/dev/db/password` | SecureString | Mot de passe de la base de données RDS |
| `/kambriq/dev/api/jwt_secret` | SecureString | Secret JWT pour l'authentification API |

### ARN du Paramètre

```
arn:aws:ssm:eu-central-1:051551940370:parameter/kambriq/dev/db/password
```

---

## 📋 Ordre de Déploiement

### Étape 1 : Créer les Secrets SSM

```bash
cd kambriq-aws-iac-terraform
./scripts/generate-and-store-secrets.sh dev
```

**Ou manuellement :**
```bash
aws ssm put-parameter \
  --name /kambriq/dev/db/password \
  --value "YOUR_STRONG_PASSWORD" \
  --type SecureString \
  --region eu-central-1
```

### Étape 2 : Déployer Terraform

```bash
./scripts/terraform-deploy-dev-v2.sh
```

Le script vérifiera automatiquement que les secrets existent avant de déployer.

---

## ⚠️ Points Importants

1. **Source Unique de Vérité** : SSM Parameter Store est maintenant la seule source de vérité pour tous les secrets
2. **Pas de Secrets dans Terraform** : Aucun secret n'est stocké dans les fichiers Terraform (`.tfvars`, variables, etc.)
3. **Création Préalable** : Les secrets DOIVENT être créés AVANT le déploiement Terraform
4. **Vérification Automatique** : Le script de déploiement vérifie automatiquement l'existence des secrets

---

## 🔄 Migration depuis l'Ancienne Configuration

Si vous avez déjà déployé avec des variables Terraform :

1. **Créer les secrets dans SSM :**
   ```bash
   ./scripts/generate-and-store-secrets.sh dev
   ```

2. **Mettre à jour Terraform :**
   ```bash
   cd envs/dev-v2
   terraform init
   terraform plan  # Vérifier que tout est OK
   terraform apply
   ```

3. **Vérifier que RDS utilise le nouveau mot de passe :**
   - Terraform mettra à jour RDS avec le mot de passe depuis SSM
   - Aucune interruption de service (RDS peut changer le mot de passe sans redémarrage)

---

## 📚 Références

- [AWS SSM Parameter Store Documentation](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html)
- Script de génération : `scripts/generate-and-store-secrets.sh`
- Script de déploiement : `scripts/terraform-deploy-dev-v2.sh`

---

*Dernière mise à jour : 2026-01-03*
