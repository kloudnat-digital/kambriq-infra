# Plan de Nettoyage - KAMBRIQ v3.0

**Date :** 2026-01-13  
**Niveau :** CTO-GRADE  
**Status :** ✅ **APPROUVÉ**

---

## 🎯 Objectif

Nettoyer complètement le repository `kambriq-aws-iac-terraform` pour supprimer :
- Toutes les références à l'ancien monorepo `kambriq`
- Les workflows GitHub Actions obsolètes/redondants
- Les scripts obsolètes remplacés
- La documentation obsolète
- Les modules non utilisés

---

## 📋 Fichiers à Supprimer

### Workflows GitHub Actions Obsolètes

1. **`.github/workflows/terraform-dev-optimized.yml`** ❌
   - **Raison :** Doublon de `terraform-dev-v2-optimized.yml`
   - **Remplacement :** `terraform-dev-v2-optimized.yml` (plus récent)

2. **`.github/workflows/terraform-validate-v2.yml`** ❌
   - **Raison :** Redondant - validation déjà dans tous les workflows
   - **Remplacement :** Validation intégrée dans chaque workflow

### Scripts Obsolètes

3. **`scripts/terraform-deploy-dev-v2.sh`** ❌
   - **Raison :** Remplacé par `scripts/deploy-terraform.sh` (unifié)
   - **Remplacement :** `./scripts/deploy-terraform.sh dev-v2`

4. **`scripts/terraform-deploy-shared.sh`** ❌
   - **Raison :** Remplacé par `scripts/deploy-terraform.sh` (unifié)
   - **Remplacement :** `./scripts/deploy-terraform.sh shared`

5. **`scripts/validate-ecs-v2.sh`** ❌
   - **Raison :** Script de validation manuelle obsolète
   - **Remplacement :** Validation via workflows GitHub Actions

### Documentation Obsolète

6. **`docs/archive/DEPLOYMENT_FIX_SUMMARY.md`** ❌
   - **Raison :** Références à l'ancien monorepo (`kambriq/apps/api`, etc.)
   - **Remplacement :** Documentation actuelle dans `docs/DEPLOYMENT_STATUS.md`

### Modules Non Utilisés (À Vérifier)

7. **`modules/bastion/`** ⚠️
   - **Raison :** Module bastion non utilisé dans dev-v2 ou prod
   - **Action :** Vérifier si utilisé ailleurs, sinon supprimer

8. **`modules/iam/`** ⚠️
   - **Raison :** Remplacé par `modules/iam-roles-ecs` pour ECS
   - **Action :** Vérifier si utilisé dans prod (V1), sinon supprimer

9. **`modules/s3-media/`** ⚠️
   - **Raison :** Vérifier si utilisé
   - **Action :** Vérifier utilisation, sinon supprimer

---

## 📝 Fichiers à Mettre à Jour

### Documentation

1. **`README.md`**
   - Supprimer références à `apps/api`, `apps/web`
   - Mettre à jour avec nouvelle structure (3 repos)

2. **`CHANGELOG.md`**
   - Nettoyer les entrées obsolètes
   - Ajouter entrée pour v3.0

3. **`.github/README.md`**
   - Supprimer références à workflows obsolètes
   - Mettre à jour avec workflows actuels

4. **`docs/integration/APP_INTEGRATION.md`**
   - Nettoyer références ancien monorepo
   - Mettre à jour avec nouveaux repos

5. **`docs/setup/TERRAFORM_USAGE.md`**
   - Supprimer références à workflows obsolètes
   - Mettre à jour avec `deploy-terraform.sh`

### Workflows GitHub Actions

6. **`.github/workflows/terraform-dev-v2-optimized.yml`**
   - Renommer en `terraform-dev.yml` (simplification)
   - Mettre à jour les commentaires

7. **`.github/workflows/terraform-shared.yml`**
   - Vérifier et mettre à jour si nécessaire

8. **`.github/workflows/terraform-prod-optimized.yml`**
   - Vérifier si prod utilise encore V1 (Lambda) ou V2 (ECS)
   - Adapter en conséquence

---

## ✅ Validation Post-Nettoyage

- [ ] Aucune référence à `kambriq/apps/`
- [ ] Aucune référence à `apps/api` ou `apps/web`
- [ ] Aucune référence à `monorepo`
- [ ] Aucune référence à `deploy-app` ou `deploy-v2`
- [ ] Tous les workflows sont à jour
- [ ] Tous les scripts sont utilisés
- [ ] Tous les modules sont utilisés

---

**Approuvé par :** Infrastructure Team  
**Date :** 2026-01-13
