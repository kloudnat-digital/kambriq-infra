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
#   ECS_CLUSTER      - ECS cluster name     (default: kambriq-<env>-cluster)
#   ECS_API_SERVICE  - ECS API service name (default: kambriq-<env>-api)
#   ECS_WEB_SERVICE  - ECS web service name (default: kambriq-<env>-web)
#
# Exit codes:
#   0 - every check that ran passed, and at least one check ran
#   1 - one or more checks failed, or no check ran at all
#   2 - a required variable resolved to empty; nothing was checked
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

# ---------------------------------------------------------------------------
# Required variables
#
# Everything above is resolved with the ${VAR:-default} form, which substitutes
# when the variable is unset *and* when it is set but empty. The CI workflow
# feeds several of these from repository variables that are not defined, so
# they arrive as empty strings and the defaults correctly take over.
#
# This guard is the backstop for the case the defaults do not cover: if one is
# ever removed, emptied, or switched to the ${VAR-default} form (which does not
# substitute on empty), fail here naming the variable, instead of quietly
# querying an empty cluster or service name and reporting it as a failed check.
# ---------------------------------------------------------------------------
REQUIRED_VARS="ENV AWS_REGION WEB_URL API_URL ECS_CLUSTER ECS_API_SERVICE ECS_WEB_SERVICE"
missing=""
for var in $REQUIRED_VARS; do
  if [[ -z "${!var:-}" ]]; then
    missing="${missing} ${var}"
  fi
done
if [[ -n "$missing" ]]; then
  echo "ERROR: required variable(s) resolved to empty:${missing}" >&2
  echo "       Refusing to run checks against an empty target." >&2
  exit 2
fi

PASS=0
FAIL=0
SKIP=0

# Counters are incremented with an assignment, never with ((VAR++)).
#
# ((VAR++)) is post-increment: it evaluates to the value VAR held *before* the
# increment. When that value is 0 the arithmetic command reports a non-zero
# exit status, and under `set -e` that terminates the script. That is why this
# script died immediately after its first passing check: log_pass ran
# ((PASS++)) with PASS=0, which exited 1 and took the whole run with it.
log_pass() { echo "  ✓ $1"; PASS=$((PASS + 1)); }
log_fail() { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }
log_skip() { echo "  ~ $1"; SKIP=$((SKIP + 1)); }

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
    attempt=$((attempt + 1))
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

  # Two response shapes are in play. The API wraps its payload as
  # {success: ..., data: {...}}, while the web app returns its fields flat at
  # the top level. Read the top level first and fall back to data.<field>, so
  # one check works against both without hardcoding which URL is which.
  actual=$(curl -s --max-time 10 "$url" | python3 -c "import sys,json; d=json.load(sys.stdin); v=d.get('$field'); v=d.get('data',{}).get('$field') if v is None and isinstance(d.get('data'),dict) else v; print('' if v is None else v)" 2>/dev/null || echo "")
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
    log_skip "$label → skipped (aws CLI not available)"
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

EXECUTED=$((PASS + FAIL))

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Results: $PASS passed, $FAIL failed, $SKIP skipped ($EXECUTED executed)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# A run that executed no check proves nothing. Exiting 0 here would report a
# healthy environment on zero evidence, which is the failure this script exists
# to catch. Skipped checks are not evidence either, so they do not count.
if [[ $EXECUTED -eq 0 ]]; then
  echo "ERROR: no check was executed ($SKIP skipped). Refusing to report success." >&2
  exit 1
fi

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
