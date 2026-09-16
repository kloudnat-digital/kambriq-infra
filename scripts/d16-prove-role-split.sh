#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# D16 - prove the plan role cannot change anything, and still plan.
#
# A restriction seen only refusing is as unproven as one seen only allowing, so
# this measures BOTH senses against the real roles with
# simulate-principal-policy:
#
#   negative - every mutating action a plan has no business taking is refused
#              for the plan role (and allowed for the apply role, which is what
#              says the refusal came from the split and not from a typo);
#   positive - every read a `terraform plan` of this estate actually performs is
#              allowed for the plan role. The list is not invented: it is the
#              refresh surface of the resource types in the two states, plus the
#              state object itself and the shared remote state.
#
# The apply direction is NOT faked here. An apply is proven by the next
# legitimate apply, sequenced after this lands - see the pull request.
#
# Usage: scripts/d16-prove-role-split.sh
# Requires: both roles applied. Refuses to run otherwise, because a missing
# role simulates as implicitDeny and would pass the negative half for the
# wrong reason.
# ---------------------------------------------------------------------------
set -uo pipefail

ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"
PLAN_ROLE="arn:aws:iam::${ACCOUNT}:role/kambriq-infra-github-actions-plan"
APPLY_ROLE="arn:aws:iam::${ACCOUNT}:role/kambriq-infra-github-actions"
STATE="arn:aws:s3:::kloudnat-infra-shared-store/kambriq/envs/dev/terraform.tfstate"

for r in "${PLAN_ROLE}" "${APPLY_ROLE}"; do
  aws iam get-role --role-name "${r##*/}" >/dev/null 2>&1 || {
    echo "REFUSED TO PROVE: ${r##*/} does not exist yet. Apply first." >&2
    exit 1
  }
done

decide() { # role action [resource]
  local role="$1" action="$2" resource="${3:-*}"
  aws iam simulate-principal-policy \
    --policy-source-arn "${role}" \
    --action-names "${action}" \
    --resource-arns "${resource}" \
    --query 'EvaluationResults[0].EvalDecision' --output text 2>&1
}

fail=0

echo "== D16 $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo
echo "NEGATIVE - the plan role must not be able to change the estate:"
# One mutating action per service the estate is made of. Each is something an
# apply genuinely does, which is why refusing it is meaningful.
for a in \
  ecs:UpdateService \
  ecs:RegisterTaskDefinition \
  rds:ModifyDBInstance \
  rds:DeleteDBInstance \
  elasticache:ModifyReplicationGroup \
  ssm:PutParameter \
  ssm:DeleteParameter \
  iam:PutRolePolicy \
  iam:CreateRole \
  iam:AttachRolePolicy \
  s3:PutObject \
  s3:DeleteObject \
  elasticloadbalancing:CreateRule \
  elasticloadbalancing:ModifyListener \
  ec2:AuthorizeSecurityGroupIngress \
  ec2:CreateSecurityGroup \
  kms:PutKeyPolicy \
  kms:ScheduleKeyDeletion \
  logs:DeleteLogGroup \
  sns:Publish \
  cloudtrail:StopLogging \
  route53:ChangeResourceRecordSets; do
  p="$(decide "${PLAN_ROLE}" "${a}")"
  q="$(decide "${APPLY_ROLE}" "${a}")"
  if [ "${p}" = "allowed" ]; then
    echo "  FAIL  ${a}: plan=${p} apply=${q}"
    fail=1
  elif [ "${q}" != "allowed" ]; then
    # The apply role must still be able to do it, or the split broke the apply.
    echo "  FAIL  ${a}: plan=${p} (good) but apply=${q} - the apply role lost it"
    fail=1
  else
    echo "  ok    ${a}: plan=${p}, apply=allowed"
  fi
done

echo
echo "POSITIVE - the plan role must be able to read everything a plan refreshes:"
for a in \
  ec2:DescribeSecurityGroups \
  ec2:DescribeSubnets \
  ec2:DescribeRouteTables \
  ecs:DescribeServices \
  ecs:DescribeTaskDefinition \
  ecs:DescribeClusters \
  ecr:DescribeRepositories \
  elasticloadbalancing:DescribeRules \
  elasticloadbalancing:DescribeTargetGroups \
  rds:DescribeDBInstances \
  elasticache:DescribeReplicationGroups \
  ssm:DescribeParameters \
  iam:GetRole \
  iam:ListRolePolicies \
  iam:GetUser \
  logs:DescribeLogGroups \
  cloudwatch:DescribeAlarms \
  sns:GetTopicAttributes \
  cloudtrail:DescribeTrails \
  route53:GetHostedZone \
  acm:DescribeCertificate \
  sesv2:GetContactList \
  kms:DescribeKey; do
  p="$(decide "${PLAN_ROLE}" "${a}")"
  if [ "${p}" = "allowed" ]; then
    echo "  ok    ${a}"
  else
    echo "  FAIL  ${a}: ${p} - a plan would break on this"
    fail=1
  fi
done

echo
echo "POSITIVE - the state object and the shared remote state:"
check_allowed() { # action resource
  local p
  p="$(decide "${PLAN_ROLE}" "$1" "$2")"
  if [ "${p}" = "allowed" ]; then
    echo "  ok    $1 on ${2##*/}"
  else
    echo "  FAIL  $1 on ${2##*/}: ${p}"
    fail=1
  fi
}
check_allowed s3:GetObject "${STATE}"
check_allowed s3:ListBucket "arn:aws:s3:::kloudnat-infra-shared-store"
# Writing the state is the apply's job, and the plan must not be able to.
p="$(decide "${PLAN_ROLE}" s3:PutObject "${STATE}")"
if [ "${p}" = "allowed" ]; then
  echo "  FAIL  s3:PutObject on the state: ${p} - the plan role could overwrite the state"
  fail=1
else
  echo "  ok    s3:PutObject on the state: ${p}"
fi

echo
echo "READ POWER, said out loud rather than implied:"
p="$(decide "${PLAN_ROLE}" ssm:GetParameter "arn:aws:ssm:eu-central-1:${ACCOUNT}:parameter/kambriq/dev/api/JWT_SECRET")"
echo "  plan role can read /kambriq/dev/api/JWT_SECRET: ${p}"
echo "  (a plan refreshes 57 aws_ssm_parameter resources, so this is required."
echo "   Separating plan from apply removes WRITE power, not READ power.)"

echo
if [ "${fail}" -eq 0 ]; then
  echo "D16: both directions hold."
else
  echo "D16: FAILED - see above." >&2
  exit 1
fi
