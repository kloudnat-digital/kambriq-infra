#!/usr/bin/env bash
set -euo pipefail

ENV_NAME="${1:-}"
REPO="${2:-}"
ROLE_ARN="${3:-}"

if [[ -z "${ENV_NAME}" || -z "${REPO}" ]]; then
  echo "Usage: $0 <dev|prd> <owner/repo> [aws_role_arn]" >&2
  exit 1
fi

TF_DIR="envs/${ENV_NAME}"
if [[ ! -d "${TF_DIR}" ]]; then
  echo "Terraform env directory not found: ${TF_DIR}" >&2
  exit 1
fi

OUTPUT_JSON="$(terraform -chdir="${TF_DIR}" output -json)"

AWS_REGION="${AWS_REGION:-}"
if [[ -z "${AWS_REGION}" && -f "${TF_DIR}/terraform.tfvars" ]]; then
  AWS_REGION="$(awk -F'=' '/^aws_region/ { gsub(/["[:space:]]/, "", $2); print $2 }' "${TF_DIR}/terraform.tfvars")"
fi

if [[ -z "${AWS_REGION}" ]]; then
  echo "AWS_REGION is required (set env or in terraform.tfvars)." >&2
  exit 1
fi

ECR_REPO="$(echo "${OUTPUT_JSON}" | jq -r '.ecr_api_repository_url.value')"
ECS_CLUSTER="$(echo "${OUTPUT_JSON}" | jq -r '.ecs_cluster_name.value')"
ECS_SERVICE="$(echo "${OUTPUT_JSON}" | jq -r '.ecs_service_api_name.value')"
ECS_TASK_DEFINITION="$(echo "${OUTPUT_JSON}" | jq -r '.ecs_task_definition_arn_api.value')"
ECS_SUBNETS="$(echo "${OUTPUT_JSON}" | jq -r '.private_subnet_ids.value | join(",")')"
ECS_SECURITY_GROUPS="$(echo "${OUTPUT_JSON}" | jq -r '.ecs_security_group_id.value')"

SMOKE_TEST_URL="${SMOKE_TEST_URL:-}"
if [[ -z "${SMOKE_TEST_URL}" ]]; then
  if [[ "${ENV_NAME}" == "dev" ]]; then
    SMOKE_TEST_URL="https://dev.kambriq.com/api/v1/health/ready"
  elif [[ "${ENV_NAME}" == "prd" ]]; then
    SMOKE_TEST_URL="https://kambriq.com/api/v1/health/ready"
  fi
fi

gh variable set AWS_REGION --repo "${REPO}" --env "${ENV_NAME}" --body "${AWS_REGION}"
gh variable set ECR_REPO --repo "${REPO}" --env "${ENV_NAME}" --body "${ECR_REPO}"
gh variable set ECS_CLUSTER --repo "${REPO}" --env "${ENV_NAME}" --body "${ECS_CLUSTER}"
gh variable set ECS_SERVICE --repo "${REPO}" --env "${ENV_NAME}" --body "${ECS_SERVICE}"
gh variable set ECS_TASK_DEFINITION --repo "${REPO}" --env "${ENV_NAME}" --body "${ECS_TASK_DEFINITION}"
gh variable set ECS_SUBNETS --repo "${REPO}" --env "${ENV_NAME}" --body "${ECS_SUBNETS}"
gh variable set ECS_SECURITY_GROUPS --repo "${REPO}" --env "${ENV_NAME}" --body "${ECS_SECURITY_GROUPS}"
gh variable set CONTAINER_NAME --repo "${REPO}" --env "${ENV_NAME}" --body "api"
gh variable set ASSIGN_PUBLIC_IP --repo "${REPO}" --env "${ENV_NAME}" --body "DISABLED"
if [[ -n "${SMOKE_TEST_URL}" ]]; then
  gh variable set SMOKE_TEST_URL --repo "${REPO}" --env "${ENV_NAME}" --body "${SMOKE_TEST_URL}"
fi

if [[ -n "${ROLE_ARN}" ]]; then
  gh secret set AWS_ROLE_ARN --repo "${REPO}" --env "${ENV_NAME}" --body "${ROLE_ARN}"
fi

echo "GitHub variables updated for ${ENV_NAME} in ${REPO}."
