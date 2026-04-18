#!/usr/bin/env bash
# smoke-test.sh: Validates that a deployed Kambriq environment is healthy.
#
# Usage: ./scripts/smoke-test.sh [ENV]
#   ENV  - environment to test (default: dev)
#
# Environment variables:
#   AWS_REGION   - AWS region (default: eu-central-1)
#   WEB_URL      - Web app base URL (default: https://dev.kambriq.com)
#   API_URL      - API base URL    (default: https://dev.kambriq.com)
#   ECS_CLUSTER  - ECS cluster name (optional, for ECS health checks)
#
# Exit codes:
#   0 - all checks passed
#   1 - one or more checks failed
#
# NOTE: Make this script executable before use: chmod +x scripts/smoke-test.sh

set -euo pipefail

ENV="${1:-dev}"
AWS_REGION="${AWS_REGION:-eu-central-1}"
RETRIES=5
RETRY_DELAY=5

# Default URLs based on environment
if [[ "$ENV" == "prd" ]]; then
  WEB_URL="${WEB_URL:-https://kambriq.com}"
  API_URL="${API_URL:-https://kambriq.com}"
  ECS_CLUSTER="${ECS_CLUSTER:-kambriq-prd-cluster}"
  ECS_API_SERVICE="${ECS_API_SERVICE:-kambriq-prd-api}"
  ECS_WEB_SERVICE="${ECS_WEB_SERVICE:-kambriq-prd-web}"
else
  WEB_URL="${WEB_URL:-https://dev.kambriq.com}"
  API_URL="${API_URL:-https://dev.kambriq.com}"
  ECS_CLUSTER="${ECS_CLUSTER:-kambriq-dev-cluster}"
  ECS_API_SERVICE="${ECS_API_SERVICE:-kambriq-dev-api}"
  ECS_WEB_SERVICE="${ECS_WEB_SERVICE:-kambriq-dev-web}"
fi

PASS=0
FAIL=0

log_pass() { echo "  ✓ $1"; ((PASS++)); }
log_fail() { echo "  ✗ $1"; ((FAIL++)); }

check_http() {
  local label="$1"
  local url="$2"
  local expected_status="${3:-200}"
  local attempt=0

  while [[ $attempt -lt $RETRIES ]]; do
    status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$url" || echo "000")
    if [[ "$status" == "$expected_status" ]]; then
      log_pass "$label → HTTP $status"
      return 0
    fi
    ((attempt++))
    if [[ $attempt -lt $RETRIES ]]; then
      echo "    retry $attempt/$RETRIES (got $status, expected $expected_status)..."
      sleep "$RETRY_DELAY"
    fi
  done
  log_fail "$label → HTTP $status (expected $expected_status)"
  return 0  # don't exit — accumulate all failures
}

check_json_field() {
  local label="$1"
  local url="$2"
  local field="$3"
  local expected="$4"

  actual=$(curl -s --max-time 10 "$url" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('$field',''))" 2>/dev/null || echo "")
  if [[ "$actual" == "$expected" ]]; then
    log_pass "$label → $field=$actual"
  else
    log_fail "$label → $field=$actual (expected $expected)"
  fi
}

check_ecs_service() {
  local label="$1"
  local cluster="$2"
  local service="$3"

  if ! command -v aws &>/dev/null; then
    echo "  ~ $label → skipped (aws CLI not available)"
    return 0
  fi

  result=$(aws ecs describe-services \
    --cluster "$cluster" \
    --services "$service" \
    --region "$AWS_REGION" \
    --query 'services[0].{desired:desiredCount,running:runningCount,status:status}' \
    --output json 2>/dev/null || echo '{}')

  desired=$(echo "$result" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('desired',0))" 2>/dev/null || echo "0")
  running=$(echo "$result" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('running',0))" 2>/dev/null || echo "0")
  status=$(echo "$result"  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status',''))" 2>/dev/null || echo "")

  if [[ "$status" == "ACTIVE" && "$running" -ge 1 && "$running" == "$desired" ]]; then
    log_pass "$label → ACTIVE ($running/$desired running)"
  else
    log_fail "$label → status=$status running=$running desired=$desired"
  fi
}

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Kambriq Smoke Test — environment: $ENV"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "1. HTTP health checks"
check_http    "API health ready"  "${API_URL}/api/v1/health/ready"
check_json_field "API health body"   "${API_URL}/api/v1/health/ready" "status" "ok"
check_http    "Web health"        "${WEB_URL}/health"
check_json_field "Web health body"   "${WEB_URL}/health" "status" "ok"

echo ""
echo "2. Public page accessibility"
check_http "Root page"       "${WEB_URL}/"
check_http "Login page"      "${WEB_URL}/login"

echo ""
echo "3. ECS service health"
check_ecs_service "API ECS service" "$ECS_CLUSTER" "$ECS_API_SERVICE"
check_ecs_service "Web ECS service" "$ECS_CLUSTER" "$ECS_WEB_SERVICE"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Results: $PASS passed, $FAIL failed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
