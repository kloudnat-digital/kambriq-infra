# Scripts Terraform KAMBRIQ

Scripts utilitaires pour le déploiement de l'infrastructure Terraform.

## 📋 Scripts Disponibles

### Déploiement Infrastructure

#### `terraform-deploy-shared.sh`

Déploiement du stack **shared** (VPC, Route53, SES, ACM, S3).

```bash
./scripts/terraform-deploy-shared.sh
```

**Actions:**
- Terraform init
- Terraform plan
- Terraform apply (avec confirmation)
- Validation des outputs

**⚠️ Important:** Le stack shared doit être déployé **EN PREMIER** avant dev-v2 et prod-v2.

---

#### `terraform-deploy-dev-v2.sh`

Déploiement du stack **dev-v2** (ECS, ALB, CloudFront, RDS, ECR, SSM, IAM).

```bash
./scripts/terraform-deploy-dev-v2.sh
```

**Actions:**
- Terraform init
- Terraform plan
- Terraform apply (avec confirmation)
- Validation des outputs

**Prérequis:**
- Stack shared déployé
- Variables `terraform.tfvars` configurées

---

### Validation

#### `validate-ecs-v2.sh`

Validation de l'architecture ECS V2.

```bash
./scripts/validate-ecs-v2.sh
```

**Vérifications:**
- ✅ Cluster ECS existe
- ✅ Services ECS (API + Web) existent
- ✅ Task definitions valides
- ✅ ALB configuré correctement
- ✅ Target groups configurés
- ✅ Health checks fonctionnels

---

### Utilitaires

#### `generate-and-store-secrets.sh`

Génération et stockage des secrets dans AWS SSM Parameter Store.

```bash
./scripts/generate-and-store-secrets.sh
```

**Actions:**
- Génère des secrets sécurisés (DB password, JWT secrets)
- Stocke dans SSM Parameter Store
- Structure: `/kambriq/{env}/{service}/{key}`

**⚠️ Sécurité:** Ne jamais commiter les secrets générés.

---

#### `verify-bastion-rds-connection.sh`

Vérification de la connexion au RDS via bastion.

```bash
./scripts/verify-bastion-rds-connection.sh
```

**Actions:**
- Vérifie la connexion SSH au bastion
- Teste la connexion PostgreSQL depuis le bastion
- Valide les credentials

---

## 🚀 Ordre de Déploiement

### 1. Stack Shared (OBLIGATOIRE EN PREMIER)

```bash
cd kambriq-aws-iac-terraform
./scripts/terraform-deploy-shared.sh
```

### 2. Stack Dev-V2

```bash
./scripts/terraform-deploy-dev-v2.sh
```

### 3. Validation

```bash
./scripts/validate-ecs-v2.sh
```

---

## 📖 Documentation

- **[Guide Terraform](../docs/setup/TERRAFORM_USAGE.md)** - Guide complet d'utilisation
- **[Architecture V2](../docs/architecture/)** - Documentation architecture
- **[Intégration App](../docs/integration/APP_INTEGRATION.md)** - Intégration avec l'application

---

*Dernière mise à jour : 2026-01-05*

