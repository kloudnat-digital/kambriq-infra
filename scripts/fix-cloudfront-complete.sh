#!/bin/bash
# ============================================================================
# Fix CloudFront Complet - Solution Expert
# ============================================================================
# 
# Ce script résout définitivement le problème NextAuth en créant/mettant à jour
# la distribution CloudFront avec tous les cache behaviors corrects.
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${SCRIPT_DIR}/../envs/dev"
cd "$TERRAFORM_DIR"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 Fix CloudFront - Solution Expert"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 1. Vérifier si une distribution existe déjà
echo "🔍 Étape 1: Recherche de distribution existante..."
EXISTING_DIST=$(aws cloudfront list-distributions --output json | \
  jq -r '.DistributionList.Items[]? | 
    select(.Aliases.Items[]? | contains("dev.kambriq.com")) | 
    .Id' | head -1)

if [ -n "$EXISTING_DIST" ]; then
  echo "✅ Distribution trouvée: $EXISTING_DIST"
  
  # Vérifier les cache behaviors
  CACHE_BEHAVIORS=$(aws cloudfront get-distribution-config --id "$EXISTING_DIST" \
    --query 'DistributionConfig.OrderedCacheBehaviors.Items | length' \
    --output text 2>/dev/null || echo "0")
  
  echo "📋 Cache behaviors actuels: $CACHE_BEHAVIORS"
  
  if [ "$CACHE_BEHAVIORS" = "0" ]; then
    echo "⚠️  Aucun cache behavior - mise à jour nécessaire"
    
    # Importer dans Terraform
    if ! terraform state list | grep -q "aws_cloudfront_distribution.main"; then
      echo "📥 Import de la distribution..."
      terraform import module.frontend.aws_cloudfront_distribution.main "$EXISTING_DIST" || {
        echo "❌ Import échoué"
        exit 1
      }
    fi
    
    # Mettre à jour
    echo "🔄 Mise à jour de la distribution..."
    terraform apply -target=module.frontend.aws_cloudfront_distribution.main -auto-approve
    
    DIST_ID="$EXISTING_DIST"
  else
    echo "✅ Cache behaviors déjà présents"
    DIST_ID="$EXISTING_DIST"
  fi
else
  echo "⚠️  Aucune distribution trouvée"
  echo "   Création d'une nouvelle distribution..."
  
  # Vérifier le conflit CNAME
  echo "🔍 Vérification du CNAME dev.kambriq.com..."
  
  # Essayer de créer avec CNAME
  if terraform apply -target=module.frontend.aws_cloudfront_distribution.main -auto-approve 2>&1 | grep -q "CNAMEAlreadyExists"; then
    echo "⚠️  CNAME conflict détecté"
    echo "   Solution: Création sans CNAME, puis ajout après"
    
    # Backup terraform.tfvars
    cp terraform.tfvars terraform.tfvars.bak
    CURRENT_DOMAIN=$(grep '^cloudfront_domain' terraform.tfvars | cut -d'"' -f2 || echo "dev.kambriq.com")
    
    # Créer sans CNAME
    echo "📝 Modification temporaire: cloudfront_domain = \"\""
    sed -i.bak 's/cloudfront_domain = ".*"/cloudfront_domain = ""/' terraform.tfvars
    
    echo "🔄 Création de la distribution sans CNAME..."
    terraform apply -target=module.frontend.aws_cloudfront_distribution.main -auto-approve
    
    # Attendre déploiement
    NEW_DIST_ID=$(terraform output -raw cloudfront_distribution_id)
    echo "⏳ Attente déploiement distribution $NEW_DIST_ID..."
    
    # Polling pour status Deployed (max 20 minutes)
    MAX_WAIT=1200
    ELAPSED=0
    while [ $ELAPSED -lt $MAX_WAIT ]; do
      STATUS=$(aws cloudfront get-distribution --id "$NEW_DIST_ID" \
        --query 'Distribution.Status' --output text 2>/dev/null || echo "NOT_FOUND")
      
      if [ "$STATUS" = "Deployed" ]; then
        echo "✅ Distribution déployée"
        break
      elif [ "$STATUS" = "NOT_FOUND" ]; then
        echo "❌ Distribution non trouvée"
        exit 1
      else
        echo "⏳ Status: $STATUS - attente 30s... ($ELAPSED/$MAX_WAIT)"
        sleep 30
        ELAPSED=$((ELAPSED + 30))
      fi
    done
    
    if [ $ELAPSED -ge $MAX_WAIT ]; then
      echo "❌ Timeout - distribution non déployée après 20 minutes"
      exit 1
    fi
    
    # Restaurer CNAME
    echo "📝 Restauration: cloudfront_domain = \"$CURRENT_DOMAIN\""
    sed -i.bak "s/cloudfront_domain = \"\"/cloudfront_domain = \"$CURRENT_DOMAIN\"/" terraform.tfvars
    
    # Mettre à jour avec CNAME
    echo "🔄 Ajout du CNAME..."
    terraform apply -target=module.frontend.aws_cloudfront_distribution.main -auto-approve
    
    DIST_ID="$NEW_DIST_ID"
  else
    # Création réussie avec CNAME
    DIST_ID=$(terraform output -raw cloudfront_distribution_id)
    echo "✅ Distribution créée: $DIST_ID"
  fi
fi

# 2. Vérifier les cache behaviors
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 Étape 2: Vérification des cache behaviors"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

CACHE_BEHAVIORS=$(aws cloudfront get-distribution-config --id "$DIST_ID" \
  --query 'DistributionConfig.OrderedCacheBehaviors.Items | length' \
  --output text)

echo "📋 Cache behaviors déployés: $CACHE_BEHAVIORS"

if [ "$CACHE_BEHAVIORS" -lt "8" ]; then
  echo "⚠️  Cache behaviors manquants - mise à jour nécessaire"
  terraform apply -target=module.frontend.aws_cloudfront_distribution.main -auto-approve
  
  # Re-vérifier
  sleep 10
  CACHE_BEHAVIORS=$(aws cloudfront get-distribution-config --id "$DIST_ID" \
    --query 'DistributionConfig.OrderedCacheBehaviors.Items | length' \
    --output text)
fi

# Vérifier que /api/auth/* est présent
AUTH_BEHAVIOR=$(aws cloudfront get-distribution-config --id "$DIST_ID" \
  --query 'DistributionConfig.OrderedCacheBehaviors.Items[?PathPattern==`/api/auth/*`].PathPattern' \
  --output text)

if [ -z "$AUTH_BEHAVIOR" ]; then
  echo "❌ /api/auth/* cache behavior manquant!"
  echo "   Vérifier la configuration Terraform"
  exit 1
fi

echo "✅ /api/auth/* cache behavior présent"
echo "✅ Tous les cache behaviors déployés: $CACHE_BEHAVIORS"

# 3. Invalider le cache
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔄 Étape 3: Invalidation du cache"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

INVALIDATION_ID=$(aws cloudfront create-invalidation \
  --distribution-id "$DIST_ID" \
  --paths "/*" \
  --output json | jq -r '.Invalidation.Id')

echo "✅ Invalidation créée: $INVALIDATION_ID"

# 4. Tests
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 Étape 4: Tests NextAuth (attendre 30s propagation)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

sleep 30

BASE_URL="https://dev.kambriq.com"
FAILED=0

# Test providers
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/auth/providers" 2>/dev/null || echo "000")
if [ "$STATUS" = "200" ]; then
  echo "✅ /api/auth/providers: HTTP $STATUS"
else
  echo "❌ /api/auth/providers: HTTP $STATUS (attendu: 200)"
  FAILED=1
fi

# Test csrf
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/auth/csrf" 2>/dev/null || echo "000")
if [ "$STATUS" = "200" ]; then
  echo "✅ /api/auth/csrf: HTTP $STATUS"
else
  echo "❌ /api/auth/csrf: HTTP $STATUS (attendu: 200)"
  FAILED=1
fi

# Test signin (POST)
STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -X POST "$BASE_URL/api/auth/signin" \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"test"}' 2>/dev/null || echo "000")
if [ "$STATUS" = "200" ] || [ "$STATUS" = "401" ]; then
  echo "✅ /api/auth/signin: HTTP $STATUS (200 ou 401 = OK)"
else
  echo "❌ /api/auth/signin: HTTP $STATUS (attendu: 200 ou 401)"
  FAILED=1
fi

echo ""
if [ $FAILED -eq 0 ]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "✅ SUCCESS - Tous les tests NextAuth passent!"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  exit 0
else
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "❌ ÉCHEC - Certains tests ont échoué"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "Vérifications supplémentaires:"
  echo "1. Vérifier les logs Lambda: aws logs tail /aws/lambda/kambriq-frontend-dev-ssr --since 5m"
  echo "2. Vérifier la configuration CloudFront: aws cloudfront get-distribution-config --id $DIST_ID"
  echo "3. Attendre 5-10 minutes pour la propagation complète"
  exit 1
fi

