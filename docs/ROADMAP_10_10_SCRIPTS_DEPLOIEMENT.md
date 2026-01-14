# Roadmap : Passer de 9/10 à 10/10 - Scripts de Déploiement

**Date :** 2026-01-13  
**Niveau :** CTO-GRADE  
**Objectif :** Atteindre la perfection (10/10) pour les scripts de déploiement

---

## 📊 État Actuel

**Score Actuel :** 9/10  
**Score Cible :** 10/10  
**Gap :** 1 point (4 fonctionnalités optionnelles manquantes)

---

## 🎯 Fonctionnalités Manquantes pour 10/10

### 1. ⚠️ Smoke Tests Post-Déploiement (PRIORITÉ HAUTE)

**Impact sur le score :** +0.15 point

**Description :**
Tests fonctionnels automatisés après déploiement pour vérifier que les endpoints critiques fonctionnent correctement.

**Pourquoi c'est important :**
- Le health check vérifie que l'application démarre, mais pas que les fonctionnalités métier fonctionnent
- Détection de problèmes de configuration (CORS, authentification, base de données)
- Validation que les migrations de base de données sont appliquées correctement

**Implémentation requise :**

```bash
# Fonction à ajouter dans deploy-api.sh
run_smoke_tests() {
    local base_url=$(get_health_check_url | sed 's|/health||')
    
    print_info "🧪 Exécution des smoke tests post-déploiement..."
    
    # Test 1: Health check (déjà fait, mais on peut le refaire)
    if ! curl -f -s "${base_url}/health" > /dev/null; then
        print_error "Smoke test 1 échoué: Health check"
        return 1
    fi
    print_success "✅ Smoke test 1: Health check OK"
    
    # Test 2: Endpoint API critique (ex: GET /api/v1/auth/me avec token)
    # Note: Nécessite un token de test valide
    if [ -n "${SMOKE_TEST_TOKEN:-}" ]; then
        if ! curl -f -s -H "Authorization: Bearer ${SMOKE_TEST_TOKEN}" \
            "${base_url}/api/v1/auth/me" > /dev/null; then
            print_warning "Smoke test 2 échoué: Endpoint auth (non bloquant)"
        else
            print_success "✅ Smoke test 2: Endpoint auth OK"
        fi
    else
        print_info "⚠️  SMOKE_TEST_TOKEN non défini, test auth ignoré"
    fi
    
    # Test 3: Vérification base de données (via health check détaillé)
    local health_response=$(curl -s "${base_url}/health" 2>/dev/null)
    if echo "${health_response}" | grep -q '"database":"ok"'; then
        print_success "✅ Smoke test 3: Base de données accessible"
    else
        print_error "Smoke test 3 échoué: Base de données non accessible"
        return 1
    fi
    
    print_success "🎉 Tous les smoke tests sont passés"
    return 0
}
```

**Pour Web :**

```bash
# Fonction à ajouter dans deploy-web.sh
run_smoke_tests() {
    local base_url=$(get_health_check_url | sed 's|/health||')
    
    print_info "🧪 Exécution des smoke tests post-déploiement..."
    
    # Test 1: Health check
    if ! curl -f -s "${base_url}/health" > /dev/null; then
        print_error "Smoke test 1 échoué: Health check"
        return 1
    fi
    print_success "✅ Smoke test 1: Health check OK"
    
    # Test 2: Page d'accueil (200 OK)
    if ! curl -f -s -o /dev/null -w "%{http_code}" "${base_url}/" | grep -q "200"; then
        print_error "Smoke test 2 échoué: Page d'accueil"
        return 1
    fi
    print_success "✅ Smoke test 2: Page d'accueil OK"
    
    # Test 3: Assets statiques (ex: favicon)
    if ! curl -f -s "${base_url}/favicon.ico" > /dev/null 2>&1; then
        print_warning "Smoke test 3: Assets statiques (non bloquant)"
    else
        print_success "✅ Smoke test 3: Assets statiques OK"
    fi
    
    print_success "🎉 Tous les smoke tests sont passés"
    return 0
}
```

**Effort estimé :** 2-3 heures  
**Complexité :** Moyenne  
**Valeur :** Haute

---

### 2. ⚠️ Vérification de Version (PRIORITÉ MOYENNE)

**Impact sur le score :** +0.15 point

**Description :**
Vérification que la version déployée correspond à la version attendue (basée sur git tag, package.json, ou variable d'environnement).

**Pourquoi c'est important :**
- Traçabilité : Confirmation que la bonne version est déployée
- Debugging : Facilite l'identification de la version en cas de problème
- Compliance : Vérification que la version de production correspond aux attentes

**Implémentation requise :**

```bash
# Fonction à ajouter dans deploy-api.sh et deploy-web.sh
verify_deployed_version() {
    local health_url=$(get_health_check_url)
    local expected_version="${IMAGE_TAG}"
    
    # Si IMAGE_TAG est "latest", essayer de récupérer depuis git
    if [ "${expected_version}" = "latest" ]; then
        if command -v git &> /dev/null && [ -d "${PROJECT_ROOT}/.git" ]; then
            expected_version=$(git describe --tags --always 2>/dev/null || git rev-parse --short HEAD 2>/dev/null || echo "unknown")
        fi
    fi
    
    print_info "🔍 Vérification de la version déployée..."
    print_info "Version attendue: ${expected_version}"
    
    # Récupérer la version depuis le health check
    local health_response=$(curl -s --max-time 5 "${health_url}" 2>/dev/null || echo "")
    
    if [ -z "${health_response}" ]; then
        print_warning "Impossible de récupérer la version depuis le health check"
        return 0  # Non bloquant
    fi
    
    # Extraire la version depuis la réponse JSON
    local deployed_version=""
    if command -v jq &> /dev/null; then
        deployed_version=$(echo "${health_response}" | jq -r '.version // empty' 2>/dev/null || echo "")
    else
        # Fallback: extraction basique avec grep/sed
        deployed_version=$(echo "${health_response}" | grep -o '"version":"[^"]*"' | sed 's/"version":"\([^"]*\)"/\1/' || echo "")
    fi
    
    if [ -n "${deployed_version}" ]; then
        print_info "Version déployée: ${deployed_version}"
        
        if [ "${expected_version}" != "latest" ] && [ "${expected_version}" != "unknown" ]; then
            if [ "${deployed_version}" = "${expected_version}" ]; then
                print_success "✅ Version vérifiée: ${deployed_version}"
            else
                print_warning "⚠️  Version mismatch: attendue ${expected_version}, déployée ${deployed_version}"
                print_info "Cela peut être normal si IMAGE_TAG=latest"
            fi
        else
            print_success "✅ Version déployée: ${deployed_version}"
        fi
    else
        print_warning "Version non disponible dans le health check (non bloquant)"
    fi
    
    return 0
}
```

**Prérequis :**
- Les endpoints `/health` doivent retourner un champ `version` dans la réponse JSON
- Pour API : Modifier `main.py` pour inclure la version dans `/health`
- Pour Web : Modifier `app/health/route.ts` pour inclure la version dynamique

**Effort estimé :** 1-2 heures  
**Complexité :** Faible  
**Valeur :** Moyenne

---

### 3. ⚠️ Validation Image Docker (PRIORITÉ MOYENNE)

**Impact sur le score :** +0.15 point

**Description :**
Validation de l'image Docker avant push : taille, scan de sécurité, test de démarrage.

**Pourquoi c'est important :**
- Sécurité : Détection précoce des vulnérabilités
- Performance : Vérification de la taille de l'image
- Qualité : Test que l'image démarre correctement

**Implémentation requise :**

```bash
# Fonction à ajouter dans deploy-api.sh et deploy-web.sh
validate_docker_image() {
    local image_tag=$1
    
    print_info "🔍 Validation de l'image Docker..."
    
    # 1. Vérifier la taille de l'image
    local image_size=$(docker images "${image_tag}" --format "{{.Size}}" 2>/dev/null || echo "")
    if [ -n "${image_size}" ]; then
        print_info "Taille de l'image: ${image_size}"
        
        # Avertir si l'image est très grande (> 1GB)
        local size_mb=$(echo "${image_size}" | sed 's/[^0-9.]//g' | head -1)
        if [ -n "${size_mb}" ] && (( $(echo "${size_mb} > 1000" | bc -l 2>/dev/null || echo 0) )); then
            print_warning "⚠️  Image très volumineuse (${image_size}). Considérez l'optimisation."
        fi
    fi
    
    # 2. Scan de sécurité (si Trivy disponible)
    if command -v trivy &> /dev/null; then
        print_info "🔒 Scan de sécurité de l'image (Trivy)..."
        if trivy image --severity HIGH,CRITICAL --exit-code 0 --quiet "${image_tag}" 2>/dev/null; then
            print_success "✅ Scan de sécurité: Aucune vulnérabilité critique"
        else
            local vuln_count=$(trivy image --severity HIGH,CRITICAL --format json "${image_tag}" 2>/dev/null | \
                jq '[.Results[]?.Vulnerabilities[]?] | length' 2>/dev/null || echo "0")
            if [ "${vuln_count}" != "0" ]; then
                print_warning "⚠️  ${vuln_count} vulnérabilité(s) HIGH/CRITICAL détectée(s) (non bloquant)"
                print_info "Considérez la mise à jour des dépendances"
            fi
        fi
    else
        print_info "ℹ️  Trivy non installé, scan de sécurité ignoré"
        print_info "   Installez Trivy: https://aquasecurity.github.io/trivy/"
    fi
    
    # 3. Test de démarrage de l'image (optionnel, peut être long)
    if [ "${SKIP_IMAGE_START_TEST:-false}" != "true" ]; then
        print_info "🧪 Test de démarrage de l'image..."
        local test_container=$(docker run -d --rm "${image_tag}" sleep 5 2>/dev/null)
        if [ -n "${test_container}" ]; then
            sleep 2
            if docker ps --format "{{.ID}}" | grep -q "${test_container}"; then
                docker stop "${test_container}" > /dev/null 2>&1
                print_success "✅ Image démarre correctement"
            else
                print_warning "⚠️  Test de démarrage échoué (non bloquant)"
            fi
        fi
    fi
    
    print_success "✅ Validation de l'image terminée"
    return 0
}
```

**Prérequis :**
- Installation optionnelle de Trivy pour scan de sécurité
- Variable d'environnement `SKIP_IMAGE_START_TEST=true` pour désactiver le test de démarrage (peut être long)

**Effort estimé :** 2-3 heures  
**Complexité :** Moyenne  
**Valeur :** Haute (sécurité)

---

### 4. ⚠️ Rollback Manuel Explicite (PRIORITÉ BASSE)

**Impact sur le score :** +0.1 point

**Description :**
Fonction de rollback manuel explicite pour revenir à la version précédente en cas de problème.

**Pourquoi c'est important :**
- Contrôle : Rollback manuel même si le circuit breaker n'a pas déclenché
- Flexibilité : Choix de la version cible pour rollback
- Debugging : Possibilité de rollback vers une version spécifique

**Implémentation requise :**

```bash
# Fonction à ajouter dans deploy-api.sh et deploy-web.sh
rollback_service() {
    local cluster_name=$1
    local service_name=$2
    local target_revision="${3:-previous}"
    
    print_warning "🔄 Rollback du service ${service_name}..."
    
    local task_definition_arn=""
    
    if [ "${target_revision}" = "previous" ]; then
        # Récupérer la dernière révision précédente (non PRIMARY)
        task_definition_arn=$(aws ecs describe-services \
            --cluster "${cluster_name}" \
            --services "${service_name}" \
            --region "${AWS_REGION}" \
            --query 'services[0].deployments[?status!=`PRIMARY`].taskDefinition' \
            --output text 2>/dev/null | head -1)
    else
        # Utiliser la révision spécifiée
        task_definition_arn="${target_revision}"
    fi
    
    if [ -z "${task_definition_arn}" ]; then
        print_error "❌ Aucune révision précédente trouvée pour rollback"
        print_info "Liste des révisions disponibles:"
        aws ecs list-task-definitions \
            --family-prefix "${service_name}" \
            --region "${AWS_REGION}" \
            --sort DESC \
            --max-items 5 \
            --query 'taskDefinitionArns[]' \
            --output table
        return 1
    fi
    
    print_info "Rollback vers: ${task_definition_arn}"
    
    # Confirmation (sauf si FORCE_ROLLBACK=true)
    if [ "${FORCE_ROLLBACK:-false}" != "true" ]; then
        print_warning "⚠️  Êtes-vous sûr de vouloir effectuer le rollback? (Ctrl+C pour annuler)"
        sleep 5
    fi
    
    aws ecs update-service \
        --cluster "${cluster_name}" \
        --service "${service_name}" \
        --task-definition "${task_definition_arn}" \
        --region "${AWS_REGION}" \
        --query 'service.{serviceName:serviceName,status:status,taskDefinition:taskDefinition}' \
        --output table
    
    print_info "Attente de la stabilisation du service..."
    aws ecs wait services-stable \
        --cluster "${cluster_name}" \
        --services "${service_name}" \
        --region "${AWS_REGION}"
    
    print_success "✅ Rollback terminé avec succès"
    return 0
}
```

**Usage :**
```bash
# Rollback vers la version précédente
./scripts/deploy-api.sh rollback dev

# Rollback vers une version spécifique
./scripts/deploy-api.sh rollback dev arn:aws:ecs:region:account:task-definition/name:revision
```

**Effort estimé :** 1-2 heures  
**Complexité :** Faible  
**Valeur :** Moyenne (circuit breaker existe déjà)

---

## 📊 Calcul du Score

### Score Actuel : 9/10

| Fonctionnalité | Poids | Status | Score |
|----------------|-------|--------|-------|
| Build Docker | 0.10 | ✅ | 0.10 |
| Push ECR | 0.10 | ✅ | 0.10 |
| Update ECS | 0.10 | ✅ | 0.10 |
| Wait service stable | 0.10 | ✅ | 0.10 |
| Tests avant déploiement | 0.15 | ✅ | 0.15 |
| Validation post-déploiement | 0.15 | ✅ | 0.15 |
| Health check HTTP | 0.10 | ✅ | 0.10 |
| Gestion erreurs | 0.10 | ✅ | 0.10 |
| **Smoke tests** | **0.15** | ❌ | **0.00** |
| **Vérification version** | **0.15** | ❌ | **0.00** |
| **Validation image Docker** | **0.15** | ❌ | **0.00** |
| **Rollback manuel** | **0.10** | ❌ | **0.00** |
| **TOTAL** | **1.00** | | **0.90** |

### Score Cible : 10/10

| Fonctionnalité | Poids | Status | Score |
|----------------|-------|--------|-------|
| Build Docker | 0.10 | ✅ | 0.10 |
| Push ECR | 0.10 | ✅ | 0.10 |
| Update ECS | 0.10 | ✅ | 0.10 |
| Wait service stable | 0.10 | ✅ | 0.10 |
| Tests avant déploiement | 0.15 | ✅ | 0.15 |
| Validation post-déploiement | 0.15 | ✅ | 0.15 |
| Health check HTTP | 0.10 | ✅ | 0.10 |
| Gestion erreurs | 0.10 | ✅ | 0.10 |
| **Smoke tests** | **0.15** | ✅ | **0.15** |
| **Vérification version** | **0.15** | ✅ | **0.15** |
| **Validation image Docker** | **0.15** | ✅ | **0.15** |
| **Rollback manuel** | **0.10** | ✅ | **0.10** |
| **TOTAL** | **1.00** | | **1.00** |

---

## 🎯 Plan d'Implémentation Recommandé

### Phase 1 : Smoke Tests (Priorité Haute)
**Effort :** 2-3 heures  
**Impact :** +0.15 point  
**Valeur :** Haute (validation fonctionnelle)

### Phase 2 : Vérification Version (Priorité Moyenne)
**Effort :** 1-2 heures  
**Impact :** +0.15 point  
**Valeur :** Moyenne (traçabilité)

### Phase 3 : Validation Image Docker (Priorité Moyenne)
**Effort :** 2-3 heures  
**Impact :** +0.15 point  
**Valeur :** Haute (sécurité)

### Phase 4 : Rollback Manuel (Priorité Basse)
**Effort :** 1-2 heures  
**Impact :** +0.1 point  
**Valeur :** Moyenne (circuit breaker existe)

**Total Effort Estimé :** 6-10 heures  
**Score Final :** 10/10

---

## ✅ Checklist pour 10/10

- [ ] ✅ **Smoke tests post-déploiement**
  - [ ] Tests endpoints critiques API
  - [ ] Tests pages critiques Web
  - [ ] Tests base de données
  
- [ ] ✅ **Vérification de version**
  - [ ] Version dans `/health` (API)
  - [ ] Version dans `/health` (Web)
  - [ ] Comparaison version attendue vs déployée
  
- [ ] ✅ **Validation image Docker**
  - [ ] Vérification taille image
  - [ ] Scan sécurité (Trivy)
  - [ ] Test démarrage image (optionnel)
  
- [ ] ✅ **Rollback manuel**
  - [ ] Fonction rollback vers version précédente
  - [ ] Fonction rollback vers version spécifique
  - [ ] Confirmation avant rollback

---

## 🎯 Conclusion

**Pour atteindre 10/10, il faut implémenter :**

1. **Smoke tests post-déploiement** (priorité haute) - +0.15 point
2. **Vérification de version** (priorité moyenne) - +0.15 point
3. **Validation image Docker** (priorité moyenne) - +0.15 point
4. **Rollback manuel** (priorité basse) - +0.1 point

**Total :** 4 fonctionnalités optionnelles  
**Effort total estimé :** 6-10 heures  
**Score final :** 10/10

---

**Approuvé par :** Infrastructure Team  
**Date :** 2026-01-13  
**Version :** 1.0
