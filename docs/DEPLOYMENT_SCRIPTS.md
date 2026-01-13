# Scripts de Déploiement - KAMBRIQ v3.0

**Date de création :** 2026-01-10  
**Dernière mise à jour :** 2026-01-10

---

## 📋 Vue d'ensemble

Ce document décrit les scripts de déploiement disponibles pour déployer l'infrastructure et les applications KAMBRIQ depuis le local.

---

## 🏗️ Scripts Terraform

### `scripts/deploy-terraform.sh`

**Description :** Déploie l'infrastructure Terraform depuis le local.

**Usage :**
```bash
cd kambriq-aws-iac-terraform
./scripts/deploy-terraform.sh [shared|dev-v2|prod|all]
```

**Exemples :**
```bash
# Déployer uniquement shared
./scripts/deploy-terraform.sh shared

# Déployer dev-v2 (nécessite shared déployé)
./scripts/deploy-terraform.sh dev-v2

# Déployer tous les stacks dans l'ordre
./scripts/deploy-terraform.sh all
```

**Fonctionnalités :**
- ✅ Vérifie les prérequis (AWS CLI, Terraform, credentials)
- ✅ Initialise Terraform automatiquement
- ✅ Affiche le plan avant application
- ✅ Demande confirmation avant apply
- ✅ Gère l'ordre de déploiement (shared → dev-v2 → prod)

**Prérequis :**
- AWS CLI installé et configuré
- Terraform installé
- AWS credentials configurées (`aws configure`)

---

## 💻 Scripts Backend (kambriq-api)

### `scripts/deploy-api.sh`

**Description :** Déploie l'API FastAPI vers ECS Fargate depuis le local.

**Usage :**
```bash
cd kambriq-api
./scripts/deploy-api.sh [dev|prod]
```

**Exemples :**
```bash
# Déployer vers dev
./scripts/deploy-api.sh dev

# Déployer vers prod
./scripts/deploy-api.sh prod
```

**Fonctionnalités :**
- ✅ Build l'image Docker
- ✅ Push vers ECR
- ✅ Update ECS service (force new deployment)
- ✅ Attend la stabilisation du service
- ✅ Affiche les informations de déploiement

**Prérequis :**
- AWS CLI installé et configuré
- Docker installé et démarré
- Repository ECR `kambriq-api` créé (via Terraform)
- Cluster ECS et service créés (via Terraform)

**Variables d'environnement :**
- `AWS_REGION` : Région AWS (défaut: `eu-central-1`)
- `IMAGE_TAG` : Tag de l'image Docker (défaut: `latest`)

### `scripts/run-tests.sh`

**Description :** Lance tous les tests (unitaires, intégration, E2E).

**Usage :**
```bash
cd kambriq-api
./scripts/run-tests.sh [unit|integration|e2e|all]
```

**Exemples :**
```bash
# Tests unitaires uniquement
./scripts/run-tests.sh unit

# Tests d'intégration uniquement
./scripts/run-tests.sh integration

# Tests E2E uniquement
./scripts/run-tests.sh e2e

# Tous les tests
./scripts/run-tests.sh all
```

**Fonctionnalités :**
- ✅ Détecte automatiquement Docker ou environnement local
- ✅ Lance les migrations si nécessaire
- ✅ Exécute les tests avec pytest
- ✅ Affiche les résultats détaillés

**Prérequis :**
- Python 3.11+ installé (si local)
- Docker et Docker Compose (si Docker)
- Dépendances installées (`pip install -r requirements.txt`)

---

## 🌐 Scripts Frontend (kambriq-web)

### `scripts/deploy-web.sh`

**Description :** Déploie le frontend Next.js vers ECS Fargate depuis le local.

**Usage :**
```bash
cd kambriq-web
./scripts/deploy-web.sh [dev|prod]
```

**Exemples :**
```bash
# Déployer vers dev
./scripts/deploy-web.sh dev

# Déployer vers prod
./scripts/deploy-web.sh prod
```

**Fonctionnalités :**
- ✅ Build l'image Docker
- ✅ Push vers ECR
- ✅ Update ECS service (force new deployment)
- ✅ Attend la stabilisation du service
- ✅ Affiche les informations de déploiement

**Prérequis :**
- AWS CLI installé et configuré
- Docker installé et démarré
- Repository ECR `kambriq-web` créé (via Terraform)
- Cluster ECS et service créés (via Terraform)

**Variables d'environnement :**
- `AWS_REGION` : Région AWS (défaut: `eu-central-1`)
- `IMAGE_TAG` : Tag de l'image Docker (défaut: `latest`)

### `scripts/run-tests.sh`

**Description :** Lance tous les tests (lint, type-check, E2E).

**Usage :**
```bash
cd kambriq-web
./scripts/run-tests.sh [lint|types|e2e|all]
```

**Exemples :**
```bash
# Lint uniquement
./scripts/run-tests.sh lint

# Vérification des types uniquement
./scripts/run-tests.sh types

# Tests E2E uniquement
./scripts/run-tests.sh e2e

# Tous les tests
./scripts/run-tests.sh all
```

**Fonctionnalités :**
- ✅ Installe les dépendances si nécessaire
- ✅ Lance ESLint
- ✅ Vérifie les types TypeScript
- ✅ Exécute les tests Playwright (E2E)

**Prérequis :**
- Node.js installé
- npm installé
- Dépendances installées (`npm install --legacy-peer-deps`)

---

## 🚀 Workflow de Déploiement Complet

### 1. Infrastructure (Première fois)

```bash
# 1. Déployer shared
cd kambriq-aws-iac-terraform
./scripts/deploy-terraform.sh shared

# 2. Configurer manuellement (après shared) :
# - Route53 hosted zone (récupérer zone_id)
# - SES identities (récupérer ARNs)
# - ACM certificates (récupérer ARNs)

# 3. Déployer dev-v2
./scripts/deploy-terraform.sh dev-v2

# 4. Générer les secrets
./scripts/generate-and-store-secrets.sh dev
```

### 2. Application Backend

```bash
# Déployer l'API
cd kambriq-api
./scripts/deploy-api.sh dev
```

### 3. Application Frontend

```bash
# Déployer le frontend
cd kambriq-web
./scripts/deploy-web.sh dev
```

### 4. Tests

```bash
# Tests backend
cd kambriq-api
./scripts/run-tests.sh all

# Tests frontend
cd kambriq-web
./scripts/run-tests.sh all
```

---

## 📝 Notes Importantes

### Ordre de Déploiement

**IMPORTANT :** L'infrastructure doit être déployée **AVANT** les applications.

1. **Infrastructure** : `deploy-terraform.sh shared` → `deploy-terraform.sh dev-v2`
2. **Secrets** : `generate-and-store-secrets.sh dev`
3. **Applications** : `deploy-api.sh dev` → `deploy-web.sh dev`

### Variables d'Environnement

Les scripts utilisent des valeurs par défaut mais peuvent être surchargées :

```bash
# Exemple : Déployer avec un tag spécifique
IMAGE_TAG=v1.0.0 ./scripts/deploy-api.sh dev
AWS_REGION=us-east-1 ./scripts/deploy-api.sh dev
```

### Logs et Debugging

**Vérifier les logs ECS :**
```bash
# API
aws logs tail /ecs/kambriq-dev-api --follow --region eu-central-1

# Web
aws logs tail /ecs/kambriq-dev-web --follow --region eu-central-1
```

**Vérifier l'état des services ECS :**
```bash
aws ecs describe-services \
  --cluster kambriq-dev-cluster \
  --services kambriq-dev-api kambriq-dev-web \
  --region eu-central-1 \
  --query 'services[].[serviceName,status,runningCount,desiredCount]' \
  --output table
```

---

## 🔧 Troubleshooting

### Erreur : "Repository ECR n'existe pas"

**Solution :** Déployez d'abord l'infrastructure avec Terraform :
```bash
cd kambriq-aws-iac-terraform
./scripts/deploy-terraform.sh dev-v2
```

### Erreur : "Cluster ECS n'existe pas"

**Solution :** Déployez d'abord l'infrastructure avec Terraform.

### Erreur : "Docker daemon not running"

**Solution :** Démarrez Docker Desktop ou le daemon Docker.

### Erreur : "AWS credentials non configurées"

**Solution :** Configurez les credentials AWS :
```bash
aws configure
```

### Erreur : "Tests échouent"

**Solution :** 
- Vérifiez que la base de données est accessible
- Vérifiez que les migrations sont appliquées
- Vérifiez les variables d'environnement dans `.env`

---

**Dernière mise à jour :** 2026-01-10
