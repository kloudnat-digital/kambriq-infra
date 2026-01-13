# Setup Complet - KAMBRIQ v3.0

**Date :** 2026-01-10  
**Status :** ✅ **SETUP COMPLET**

---

## ✅ Actions Complétées

### 1. Mise à Jour du Contexte ✅

**Fichier :** `docs/architecture/CONTEXTE_WORKSPACE.md`

**Changements :**
- ✅ Document mis à jour avec la nouvelle structure (3 repos séparés)
- ✅ Description complète de chaque repository
- ✅ Architecture V3.0 documentée
- ✅ Flux de déploiement mis à jour

### 2. Mise à Jour Terraform ✅

**Fichier :** `envs/dev-v2/main.tf`

**Changements :**
- ✅ Port API corrigé : 8000 (au lieu de 3001)
- ✅ Health check API : `/health` (au lieu de `/api/health`)
- ✅ Secrets NextAuth retirés (pas utilisé dans le nouveau repo)
- ✅ Variables d'environnement API ajoutées : `FRONTEND_URL`, `CORS_ORIGINS`

**Fichier :** `kambriq-api/Dockerfile`

**Changements :**
- ✅ Port exposé : 8000 (au lieu de 3001)
- ✅ Health check : `http://localhost:8000/health`

**Fichier :** `kambriq-api/docker-compose.yml`

**Changements :**
- ✅ Port mappé : 8000:8000 (au lieu de 3001:3001)
- ✅ Commande : port 8000

### 3. Scripts de Déploiement Créés ✅

#### Infrastructure

**Fichier :** `kambriq-aws-iac-terraform/scripts/deploy-terraform.sh`

**Fonctionnalités :**
- ✅ Vérifie les prérequis (AWS CLI, Terraform, credentials)
- ✅ Initialise Terraform automatiquement
- ✅ Affiche le plan avant application
- ✅ Demande confirmation avant apply
- ✅ Gère l'ordre de déploiement (shared → dev-v2 → prod)

**Usage :**
```bash
cd kambriq-aws-iac-terraform
./scripts/deploy-terraform.sh [shared|dev-v2|prod|all]
```

#### Backend API

**Fichier :** `kambriq-api/scripts/deploy-api.sh`

**Fonctionnalités :**
- ✅ Build l'image Docker
- ✅ Push vers ECR
- ✅ Update ECS service (force new deployment)
- ✅ Attend la stabilisation du service

**Usage :**
```bash
cd kambriq-api
./scripts/deploy-api.sh [dev|prod]
```

#### Frontend Web

**Fichier :** `kambriq-web/scripts/deploy-web.sh`

**Fonctionnalités :**
- ✅ Build l'image Docker
- ✅ Push vers ECR
- ✅ Update ECS service (force new deployment)
- ✅ Attend la stabilisation du service

**Usage :**
```bash
cd kambriq-web
./scripts/deploy-web.sh [dev|prod]
```

### 4. Scripts de Tests Créés ✅

#### Backend API

**Fichier :** `kambriq-api/scripts/run-tests.sh`

**Fonctionnalités :**
- ✅ Détecte automatiquement Docker ou environnement local
- ✅ Lance les migrations si nécessaire
- ✅ Exécute les tests avec pytest
- ✅ Supporte : unit, integration, e2e, all

**Usage :**
```bash
cd kambriq-api
./scripts/run-tests.sh [unit|integration|e2e|all]
```

#### Frontend Web

**Fichier :** `kambriq-web/scripts/run-tests.sh`

**Fonctionnalités :**
- ✅ Installe les dépendances si nécessaire
- ✅ Lance ESLint
- ✅ Vérifie les types TypeScript
- ✅ Exécute les tests Playwright (E2E)
- ✅ Supporte : lint, types, e2e, all

**Usage :**
```bash
cd kambriq-web
./scripts/run-tests.sh [lint|types|e2e|all]
```

---

## 📋 Structure des Repos

### 1. `kambriq-aws-iac-terraform`
- Infrastructure AWS (Terraform)
- Stacks : shared, dev-v2, prod
- Scripts : `deploy-terraform.sh`

### 2. `kambriq-api`
- Backend FastAPI (Python 3.11+)
- Architecture DDD
- Scripts : `deploy-api.sh`, `run-tests.sh`

### 3. `kambriq-web`
- Frontend Next.js 16 (React 19)
- Pas de NextAuth (JWT avec cookies HttpOnly)
- Scripts : `deploy-web.sh`, `run-tests.sh`

---

## 🚀 Workflow de Déploiement

### Étape 1 : Infrastructure

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

### Étape 2 : Applications

```bash
# Backend
cd kambriq-api
./scripts/deploy-api.sh dev

# Frontend
cd kambriq-web
./scripts/deploy-web.sh dev
```

### Étape 3 : Tests

```bash
# Tests backend
cd kambriq-api
./scripts/run-tests.sh all

# Tests frontend
cd kambriq-web
./scripts/run-tests.sh all
```

---

## 📝 Configuration Requise

### Prérequis Globaux

- ✅ AWS CLI installé et configuré
- ✅ Terraform installé
- ✅ Docker installé et démarré
- ✅ AWS credentials configurées

### Prérequis Backend

- ✅ Python 3.11+ (si local, sans Docker)
- ✅ Dépendances installées (`pip install -r requirements.txt`)

### Prérequis Frontend

- ✅ Node.js installé
- ✅ npm installé
- ✅ Dépendances installées (`npm install --legacy-peer-deps`)

---

## 🔧 Corrections Appliquées

### Port API
- **Avant :** 3001 (incohérent avec Terraform)
- **Après :** 8000 (cohérent avec Terraform)

### Health Check API
- **Avant :** `/api/health` (incorrect)
- **Après :** `/health` (correct)

### Secrets NextAuth
- **Avant :** Secrets NextAuth dans Terraform
- **Après :** Secrets NextAuth retirés (pas utilisé)

### Variables d'Environnement API
- **Ajouté :** `FRONTEND_URL`, `CORS_ORIGINS`

---

## 📚 Documentation Créée

1. ✅ `CONTEXTE_WORKSPACE.md` - Mis à jour avec nouvelle structure
2. ✅ `DEPLOYMENT_SCRIPTS.md` - Documentation des scripts de déploiement
3. ✅ `SETUP_COMPLETE.md` - Ce document (récapitulatif)

---

## 🎯 Prochaines Étapes

### Immédiat

1. **Démarrer Docker** (si pas déjà fait)
2. **Installer dépendances frontend** :
   ```bash
   cd kambriq-web
   npm install --legacy-peer-deps
   ```

### Déploiement Initial

1. **Déployer infrastructure** :
   ```bash
   cd kambriq-aws-iac-terraform
   ./scripts/deploy-terraform.sh shared
   ```

2. **Configurer manuellement** (après shared) :
   - Route53 hosted zone
   - SES identities
   - ACM certificates

3. **Déployer dev-v2** :
   ```bash
   ./scripts/deploy-terraform.sh dev-v2
   ```

4. **Générer secrets** :
   ```bash
   ./scripts/generate-and-store-secrets.sh dev
   ```

5. **Déployer applications** :
   ```bash
   # Backend
   cd ../kambriq-api
   ./scripts/deploy-api.sh dev
   
   # Frontend
   cd ../kambriq-web
   ./scripts/deploy-web.sh dev
   ```

### Tests

Une fois Docker démarré et dépendances installées :

```bash
# Tests backend
cd kambriq-api
./scripts/run-tests.sh all

# Tests frontend
cd kambriq-web
./scripts/run-tests.sh all
```

---

## ✅ Checklist de Vérification

- [x] CONTEXTE_WORKSPACE.md mis à jour
- [x] Terraform mis à jour (port, health, secrets)
- [x] Dockerfile API corrigé (port 8000)
- [x] docker-compose.yml corrigé (port 8000)
- [x] Script deploy-terraform.sh créé
- [x] Script deploy-api.sh créé
- [x] Script deploy-web.sh créé
- [x] Script run-tests.sh API créé
- [x] Script run-tests.sh Web créé
- [x] Documentation créée
- [ ] Docker démarré (à faire manuellement)
- [ ] Dépendances npm installées (à faire)
- [ ] Infrastructure déployée (à faire)
- [ ] Applications déployées (à faire)
- [ ] Tests exécutés (à faire)

---

**Dernière mise à jour :** 2026-01-10  
**Status :** ✅ **SETUP COMPLET - PRÊT POUR DÉPLOIEMENT**
