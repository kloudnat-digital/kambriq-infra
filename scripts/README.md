# Scripts Terraform KAMBRIQ v3.0

Scripts utilitaires pour le déploiement de l'infrastructure Terraform.

## 📋 Scripts Disponibles

### Déploiement Infrastructure

#### `deploy-terraform.sh` ⭐ **RECOMMANDÉ**

Script unifié pour déployer tous les stacks Terraform.

```bash
./scripts/deploy-terraform.sh [shared|dev-v2|prod|all]
```

**Fonctionnalités:**
- ✅ Validation automatique (`terraform validate`)
- ✅ Auto-approve (pas de confirmation interactive)
- ✅ Gestion d'erreurs complète
- ✅ Support de tous les stacks (shared, dev-v2, prod, all)

**Exemples:**
```bash
# Déployer shared uniquement
./scripts/deploy-terraform.sh shared

# Déployer dev-v2 uniquement
./scripts/deploy-terraform.sh dev-v2

# Déployer tous les stacks dans l'ordre
./scripts/deploy-terraform.sh all
```

**⚠️ Important:** Le stack shared doit être déployé **EN PREMIER** avant dev-v2 et prod.

---

### Gestion des Secrets

#### `generate-and-store-secrets.sh`

Génération et stockage des secrets dans AWS SSM Parameter Store.

```bash
./scripts/generate-and-store-secrets.sh [dev|prod|all]
```

**Actions:**
- Génère des secrets sécurisés (DB password, JWT secrets)
- Stocke dans SSM Parameter Store
- Structure: `/kambriq/{env}/{service}/{key}`

**⚠️ Sécurité:** Ne jamais commiter les secrets générés.

**Exemples:**
```bash
# Générer secrets pour dev
./scripts/generate-and-store-secrets.sh dev

# Générer secrets pour prod
./scripts/generate-and-store-secrets.sh prod

# Générer secrets pour tous les environnements
./scripts/generate-and-store-secrets.sh all
```

---

### Utilitaires

#### `check-terraform-state.sh`

Vérification de l'état Terraform dans S3.

```bash
./scripts/check-terraform-state.sh
```

**Actions:**
- Vérifie l'existence des state files dans S3
- Affiche les informations des stacks

---

#### `verify-bastion-rds-connection.sh`

Vérification de la connexion au RDS via bastion (si configuré).

```bash
./scripts/verify-bastion-rds-connection.sh
```

**Actions:**
- Vérifie la connexion SSH au bastion
- Teste la connexion PostgreSQL depuis le bastion
- Valide les credentials

---

### Scripts de Testing

#### `testing/infra-plan-dev.sh`

Génère un plan Terraform pour dev-v2 (testing).

```bash
./scripts/testing/infra-plan-dev.sh
```

#### `testing/infra-validate.sh`

Valide la configuration Terraform (testing).

```bash
./scripts/testing/infra-validate.sh
```

---

## 🚀 Ordre de Déploiement Recommandé

### 1. Stack Shared (OBLIGATOIRE EN PREMIER)

```bash
cd kambriq-aws-iac-terraform
./scripts/deploy-terraform.sh shared
```

**Après le déploiement, configurer manuellement:**
- Route53 hosted zone (récupérer zone_id)
- SES identities (récupérer ARNs)
- ACM certificates (récupérer ARNs)

### 2. Créer les Secrets SSM

```bash
./scripts/generate-and-store-secrets.sh dev
```

### 3. Stack Dev-V2

```bash
./scripts/deploy-terraform.sh dev-v2
```

### 4. Déployer les Applications

```bash
# Backend
cd ../kambriq-api
./scripts/deploy-api.sh dev

# Frontend
cd ../kambriq-web
./scripts/deploy-web.sh dev
```

---

## 📖 Documentation

- **[Guide Terraform](../docs/setup/TERRAFORM_USAGE.md)** - Guide complet d'utilisation
- **[Scripts de Déploiement](../docs/DEPLOYMENT_SCRIPTS.md)** - Documentation des scripts
- **[Architecture v3.0](../docs/architecture/CONTEXTE_WORKSPACE.md)** - Documentation architecture
- **[Intégration App](../docs/integration/APP_INTEGRATION.md)** - Intégration avec l'application

---

**Dernière mise à jour :** 2026-01-13  
**Version :** 3.0 (3 repos séparés)
