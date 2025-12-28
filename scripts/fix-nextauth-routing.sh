#!/bin/bash
# ============================================================================
# Fix NextAuth Routing - Script Automatique
# ============================================================================
# 
# Ce script résout le problème où /api/auth/* retourne 404/405
# en s'assurant que CloudFront a les cache behaviors corrects déployés.
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${SCRIPT_DIR}/../envs/dev"

cd "$TERRAFORM_DIR"

echo "🔍 Diagnostic CloudFront..."

# 1. Obtenir l'ID de distribution
DIST_ID=$(terraform output -raw cloudfront_distribution_id 2>/dev/null || echo "")

if [ -z "$DIST_ID" ]; then
  echo "❌ Distribution ID non trouvé dans Terraform outputs"
  echo "   Tentative de récupération depuis AWS..."
  DIST_ID=$(aws cloudfront list-distributions \
    --query "DistributionList.Items[?contains(Comment, 'kambriq') || contains(Comment, 'dev')].Id" \
    --output text | head -1)
  
  if [ -z "$DIST_ID" ]; then
    echo "❌ Aucune distribution CloudFront trouvée"
    echo "   La distribution doit être recréée via Terraform"
    exit 1
  fi
  echo "   Distribution trouvée: $DIST_ID"
fi

echo "📋 Distribution ID: $DIST_ID"

# 2. Vérifier l'état de la distribution
STATUS=$(aws cloudfront get-distribution --id "$DIST_ID" \
  --query 'Distribution.Status' --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$STATUS" = "NOT_FOUND" ]; then
  echo "❌ Distribution $DIST_ID n'existe pas dans AWS"
  echo "   Recréation nécessaire..."
  terraform apply -target=module.frontend.aws_cloudfront_distribution.main -auto-approve
  echo "✅ Distribution recréée"
  exit 0
fi

echo "📊 Status: $STATUS"

# 3. Vérifier les cache behaviors
CACHE_BEHAVIORS=$(aws cloudfront get-distribution-config --id "$DIST_ID" \
  --query 'DistributionConfig.OrderedCacheBehaviors.Items | length' \
  --output text 2>/dev/null || echo "0")

echo "📋 Cache behaviors déployés: $CACHE_BEHAVIORS"

if [ "$CACHE_BEHAVIORS" = "0" ]; then
  echo "⚠️  Aucun cache behavior déployé - c'est le problème!"
  
  # 4. Vérifier si la distribution est dans l'état Terraform
  if ! terraform state list | grep -q "aws_cloudfront_distribution.main"; then
    echo "📥 Import de la distribution dans Terraform..."
    terraform import module.frontend.aws_cloudfront_distribution.main "$DIST_ID" || {
      echo "⚠️  Import échoué, tentative de mise à jour directe..."
    }
  fi
  
  # 5. Appliquer les changements
  echo "🔄 Application des cache behaviors via Terraform..."
  terraform apply -target=module.frontend.aws_cloudfront_cache_policy.lambda_ssr \
                  -target=module.frontend.aws_cloudfront_origin_request_policy.lambda_ssr \
                  -target=module.frontend.aws_cloudfront_distribution.main \
                  -auto-approve
  
  # 6. Vérifier le déploiement
  echo "⏳ Attente propagation CloudFront (30s)..."
  sleep 30
  
  CACHE_BEHAVIORS_AFTER=$(aws cloudfront get-distribution-config --id "$DIST_ID" \
    --query 'DistributionConfig.OrderedCacheBehaviors.Items | length' \
    --output text)
  
  if [ "$CACHE_BEHAVIORS_AFTER" -gt "0" ]; then
    echo "✅ Cache behaviors déployés: $CACHE_BEHAVIORS_AFTER"
  else
    echo "❌ Cache behaviors toujours absents"
    echo "   Vérifier manuellement: terraform plan"
    exit 1
  fi
else
  echo "✅ Cache behaviors déjà déployés: $CACHE_BEHAVIORS"
  
  # Vérifier que /api/auth/* est présent
  AUTH_BEHAVIOR=$(aws cloudfront get-distribution-config --id "$DIST_ID" \
    --query 'DistributionConfig.OrderedCacheBehaviors.Items[?PathPattern==`/api/auth/*`].PathPattern' \
    --output text)
  
  if [ -z "$AUTH_BEHAVIOR" ]; then
    echo "⚠️  /api/auth/* cache behavior manquant!"
    echo "   Application des changements..."
    terraform apply -target=module.frontend.aws_cloudfront_distribution.main -auto-approve
  else
    echo "✅ /api/auth/* cache behavior présent"
  fi
fi

# 7. Invalider le cache
echo "🔄 Invalidation du cache CloudFront..."
aws cloudfront create-invalidation \
  --distribution-id "$DIST_ID" \
  --paths "/*" \
  --output json | jq -r '{Id: .Invalidation.Id, Status: .Invalidation.Status}'

# 8. Tests
echo ""
echo "🧪 Tests NextAuth (attendre 30s pour propagation)..."
sleep 30

BASE_URL="https://dev.kambriq.com"
FAILED=0

# Test providers
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/auth/providers" || echo "000")
if [ "$STATUS" = "200" ]; then
  echo "✅ /api/auth/providers: HTTP $STATUS"
else
  echo "❌ /api/auth/providers: HTTP $STATUS (attendu: 200)"
  FAILED=1
fi

# Test csrf
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/auth/csrf" || echo "000")
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
  -d '{"email":"test@test.com","password":"test"}' || echo "000")
if [ "$STATUS" = "200" ] || [ "$STATUS" = "401" ]; then
  echo "✅ /api/auth/signin: HTTP $STATUS (200 ou 401 = OK)"
else
  echo "❌ /api/auth/signin: HTTP $STATUS (attendu: 200 ou 401)"
  FAILED=1
fi

if [ $FAILED -eq 0 ]; then
  echo ""
  echo "✅ Tous les tests NextAuth passent!"
  exit 0
else
  echo ""
  echo "❌ Certains tests ont échoué"
  echo "   Vérifier les logs Lambda et la configuration CloudFront"
  exit 1
fi

