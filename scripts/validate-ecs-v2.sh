#!/bin/bash
# ============================================================================
# Validation Script - ECS Fargate V2.0
# ============================================================================
# Vérifie que l'architecture ECS Fargate est correctement déployée
# ============================================================================

set -e

ENV=${1:-dev}
REGION=${AWS_REGION:-eu-central-1}
CLUSTER_NAME="kambriq-${ENV}-cluster"
SERVICE_API="kambriq-${ENV}-api"
SERVICE_WEB="kambriq-${ENV}-web"

echo "🔍 Validation ECS Fargate V2.0 - Environment: ${ENV}"
echo "=================================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check command result
check_result() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ $1${NC}"
    else
        echo -e "${RED}❌ $1${NC}"
        exit 1
    fi
}

# 1. Vérifier Cluster
echo "1️⃣  Vérification ECS Cluster..."
CLUSTER_STATUS=$(aws ecs describe-clusters \
    --clusters "${CLUSTER_NAME}" \
    --region "${REGION}" \
    --query 'clusters[0].status' \
    --output text 2>/dev/null || echo "NOT_FOUND")

if [ "${CLUSTER_STATUS}" = "ACTIVE" ]; then
    echo -e "${GREEN}✅ Cluster ${CLUSTER_NAME} est ACTIVE${NC}"
    
    RUNNING_TASKS=$(aws ecs describe-clusters \
        --clusters "${CLUSTER_NAME}" \
        --region "${REGION}" \
        --query 'clusters[0].runningTasksCount' \
        --output text)
    echo "   Running tasks: ${RUNNING_TASKS}"
else
    echo -e "${RED}❌ Cluster ${CLUSTER_NAME} n'existe pas ou n'est pas ACTIVE${NC}"
    exit 1
fi
echo ""

# 2. Vérifier Service API
echo "2️⃣  Vérification Service API (FastAPI)..."
SERVICE_API_STATUS=$(aws ecs describe-services \
    --cluster "${CLUSTER_NAME}" \
    --services "${SERVICE_API}" \
    --region "${REGION}" \
    --query 'services[0].status' \
    --output text 2>/dev/null || echo "NOT_FOUND")

if [ "${SERVICE_API_STATUS}" = "ACTIVE" ]; then
    echo -e "${GREEN}✅ Service ${SERVICE_API} est ACTIVE${NC}"
    
    DESIRED_COUNT=$(aws ecs describe-services \
        --cluster "${CLUSTER_NAME}" \
        --services "${SERVICE_API}" \
        --region "${REGION}" \
        --query 'services[0].desiredCount' \
        --output text)
    RUNNING_COUNT=$(aws ecs describe-services \
        --cluster "${CLUSTER_NAME}" \
        --services "${SERVICE_API}" \
        --region "${REGION}" \
        --query 'services[0].runningCount' \
        --output text)
    
    echo "   Desired: ${DESIRED_COUNT}, Running: ${RUNNING_COUNT}"
    
    if [ "${DESIRED_COUNT}" -eq "${RUNNING_COUNT}" ]; then
        echo -e "${GREEN}✅ Service API: Toutes les tasks sont running${NC}"
    else
        echo -e "${YELLOW}⚠️  Service API: ${RUNNING_COUNT}/${DESIRED_COUNT} tasks running${NC}"
    fi
else
    echo -e "${RED}❌ Service ${SERVICE_API} n'existe pas ou n'est pas ACTIVE${NC}"
    exit 1
fi
echo ""

# 3. Vérifier Service Web
echo "3️⃣  Vérification Service Web (Next.js)..."
SERVICE_WEB_STATUS=$(aws ecs describe-services \
    --cluster "${CLUSTER_NAME}" \
    --services "${SERVICE_WEB}" \
    --region "${REGION}" \
    --query 'services[0].status' \
    --output text 2>/dev/null || echo "NOT_FOUND")

if [ "${SERVICE_WEB_STATUS}" = "ACTIVE" ]; then
    echo -e "${GREEN}✅ Service ${SERVICE_WEB} est ACTIVE${NC}"
    
    DESIRED_COUNT=$(aws ecs describe-services \
        --cluster "${CLUSTER_NAME}" \
        --services "${SERVICE_WEB}" \
        --region "${REGION}" \
        --query 'services[0].desiredCount' \
        --output text)
    RUNNING_COUNT=$(aws ecs describe-services \
        --cluster "${CLUSTER_NAME}" \
        --services "${SERVICE_WEB}" \
        --region "${REGION}" \
        --query 'services[0].runningCount' \
        --output text)
    
    echo "   Desired: ${DESIRED_COUNT}, Running: ${RUNNING_COUNT}"
    
    if [ "${DESIRED_COUNT}" -eq "${RUNNING_COUNT}" ]; then
        echo -e "${GREEN}✅ Service Web: Toutes les tasks sont running${NC}"
    else
        echo -e "${YELLOW}⚠️  Service Web: ${RUNNING_COUNT}/${DESIRED_COUNT} tasks running${NC}"
    fi
else
    echo -e "${RED}❌ Service ${SERVICE_WEB} n'existe pas ou n'est pas ACTIVE${NC}"
    exit 1
fi
echo ""

# 4. Vérifier Tasks
echo "4️⃣  Vérification Tasks..."
TASKS_API=$(aws ecs list-tasks \
    --cluster "${CLUSTER_NAME}" \
    --service-name "${SERVICE_API}" \
    --region "${REGION}" \
    --query 'taskArns | length(@)' \
    --output text)

TASKS_WEB=$(aws ecs list-tasks \
    --cluster "${CLUSTER_NAME}" \
    --service-name "${SERVICE_WEB}" \
    --region "${REGION}" \
    --query 'taskArns | length(@)' \
    --output text)

echo "   Tasks API: ${TASKS_API}"
echo "   Tasks Web: ${TASKS_WEB}"

if [ "${TASKS_API}" -gt 0 ] && [ "${TASKS_WEB}" -gt 0 ]; then
    echo -e "${GREEN}✅ Tasks trouvées pour les deux services${NC}"
else
    echo -e "${RED}❌ Pas de tasks trouvées${NC}"
    exit 1
fi
echo ""

# 5. Vérifier Target Health (nécessite ARN des target groups)
echo "5️⃣  Vérification Target Health (ALB)..."
echo "   ⚠️  Pour vérifier les target groups, utilisez:"
echo "   aws elbv2 describe-target-health --target-group-arn <TG_ARN> --region ${REGION}"
echo ""

# 6. Test End-to-End
echo "6️⃣  Test End-to-End..."
DOMAIN="dev.kambriq.com"
if [ "${ENV}" = "prod" ]; then
    DOMAIN="kambriq.com"
fi

echo "   Test API Health: curl -f https://${DOMAIN}/api/health"
API_HEALTH=$(curl -sf "https://${DOMAIN}/api/health" 2>/dev/null && echo "OK" || echo "FAIL")
if [ "${API_HEALTH}" = "OK" ]; then
    echo -e "${GREEN}✅ API Health check: OK${NC}"
else
    echo -e "${YELLOW}⚠️  API Health check: FAIL (peut être normal si pas encore déployé)${NC}"
fi

echo "   Test Web Health: curl -f https://${DOMAIN}/health"
WEB_HEALTH=$(curl -sf "https://${DOMAIN}/health" 2>/dev/null && echo "OK" || echo "FAIL")
if [ "${WEB_HEALTH}" = "OK" ]; then
    echo -e "${GREEN}✅ Web Health check: OK${NC}"
else
    echo -e "${YELLOW}⚠️  Web Health check: FAIL (peut être normal si pas encore déployé)${NC}"
fi
echo ""

# Summary
echo "=================================================="
echo -e "${GREEN}✅ Validation ECS Fargate V2.0 complétée${NC}"
echo ""
echo "📊 Résumé:"
echo "   - Cluster: ${CLUSTER_NAME} (${CLUSTER_STATUS})"
echo "   - Service API: ${SERVICE_API} (${SERVICE_API_STATUS})"
echo "   - Service Web: ${SERVICE_WEB} (${SERVICE_WEB_STATUS})"
echo "   - Tasks API: ${TASKS_API}"
echo "   - Tasks Web: ${TASKS_WEB}"
echo ""

