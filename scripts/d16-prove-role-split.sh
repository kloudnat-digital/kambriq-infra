#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# D16 - prove the plan role cannot change anything, and still plan.
#
# A restriction seen only refusing is as unproven as one seen only allowing, so
# this measures BOTH senses against the real roles.
#
#   stage 0  - both policies are VALID. Access Analyzer, not the simulator.
#   negative - every mutating action a plan has no business taking is refused
#              for the plan role (and allowed for the apply role, which is what
#              says the refusal came from the split and not from a typo);
#   positive - every read a `terraform plan` of this estate actually performs is
#              allowed for the plan role. The list is not invented: it is the
#              refresh surface of the resource types in the two states, and the
#              resource on each case is the resource CloudTrail recorded for
#              that call where the pipeline has made it.
#
# THREE MISTAKES THIS SCRIPT MADE ON 2026-09-16, each of which produced a
# confident result that was false. They are the reason for the shape below.
#
#  1. AN ACTION SIMULATED WITHOUT ITS RESOURCE IS NOT THE ACTION THE PIPELINE
#     PERFORMS. `--resource-arns` defaults to "*", and a resource-scoped
#     statement can never match "*". Seven mutating actions therefore read as
#     implicitDeny for the apply role, and the script reported that the apply
#     role had lost powers it still held. Every case now carries a resource.
#
#  2. SOME ACTIONS TAKE NO RESOURCE AT ALL. IAM evaluates those only against
#     "*", so naming them in a resource-scoped statement grants nothing however
#     plainly it lists them. ssm:DescribeParameters sat in the plan role's
#     scoped SSM statement and was refused every time - and the provider calls
#     it on every aws_ssm_parameter refresh. Cases in this class carry "*",
#     which is not laziness but the only resource they have.
#
#  3. A SERVICE PREFIX IAM DOES NOT KNOW IS A SILENT DENY, NOT AN ERROR. The
#     two policies said `sesv2:`; the SESv2 API authorises against `ses:`. The
#     simulator cannot catch this - it string-matches, and returns implicitDeny
#     for notarealservice:DoThing rather than rejecting it. So the simulator
#     agreed that `sesv2:*` allowed `sesv2:GetContactList`, which is true and
#     means nothing. Access Analyzer's validate-policy is the instrument that
#     catches it, and it runs FIRST below.
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

REGION="${AWS_REGION:-eu-central-1}"
ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"
PLAN_ROLE="arn:aws:iam::${ACCOUNT}:role/kambriq-infra-github-actions-plan"
APPLY_ROLE="arn:aws:iam::${ACCOUNT}:role/kambriq-infra-github-actions"
STATE_BUCKET="kloudnat-infra-shared-store"
STATE="arn:aws:s3:::${STATE_BUCKET}/kambriq/envs/dev/terraform.tfstate"
STATE_SHARED="arn:aws:s3:::${STATE_BUCKET}/kambriq/envs/shared/terraform.tfstate"
KEY_ALIAS="alias/kambriq-shared-tfstate"

for r in "${PLAN_ROLE}" "${APPLY_ROLE}"; do
  aws iam get-role --role-name "${r##*/}" >/dev/null 2>&1 || {
    echo "REFUSED TO PROVE: ${r##*/} does not exist yet. Apply first." >&2
    exit 1
  }
done

# The D21 key by alias, so the script does not carry a key id that can go stale.
KEY_ARN="$(aws kms describe-key --key-id "${KEY_ALIAS}" \
  --query 'KeyMetadata.Arn' --output text 2>/dev/null)"
[ -n "${KEY_ARN}" ] && [ "${KEY_ARN}" != "None" ] || KEY_ARN="*"

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

# ---------------------------------------------------------------------------
# STAGE 0 - the policies are valid at all.
# ---------------------------------------------------------------------------
echo "STAGE 0 - both policies contain only actions IAM recognises:"
validate_role_policy() { # role-name
  local role="$1" pol doc errs
  for pol in $(aws iam list-role-policies --role-name "${role}" \
                 --query 'PolicyNames' --output text 2>/dev/null); do
    doc="$(aws iam get-role-policy --role-name "${role}" --policy-name "${pol}" \
            --query 'PolicyDocument' --output json 2>/dev/null)"
    if errs="$(aws accessanalyzer validate-policy --policy-type IDENTITY_POLICY \
                 --policy-document "${doc}" \
                 --query "findings[?findingType=='ERROR'].findingDetails" \
                 --output text 2>&1)"; then
      if [ -n "${errs}" ]; then
        echo "  FAIL      ${role}/${pol}"
        while IFS= read -r line; do echo "              ${line}"; done <<<"${errs}"
        fail=1
      else
        echo "  ok        ${role}/${pol}"
      fi
    else
      echo "  UNPROVEN  ${role}/${pol}: validate-policy did not run."
      echo "            ${errs}"
      echo "            This stage is the only one that can see an invalid"
      echo "            service prefix. Treat the run as incomplete, not green."
      fail=1
    fi
  done
}
validate_role_policy "${APPLY_ROLE##*/}"
validate_role_policy "${PLAN_ROLE##*/}"

# ---------------------------------------------------------------------------
# NEGATIVE - the plan role must not be able to change the estate.
#
# Refused for the plan role against the case's own resource AND against "*",
# because an action that takes no resource is granted only on "*" and would
# otherwise hide behind a resource that never matches.
# ---------------------------------------------------------------------------
echo
echo "NEGATIVE - the plan role must not be able to change the estate:"
while IFS='|' read -r a res; do
  [ -z "${a}" ] && continue
  res="${res//ACCOUNT/${ACCOUNT}}"; res="${res//REGION/${REGION}}"
  res="${res//KEY_ARN/${KEY_ARN}}"
  p="$(decide "${PLAN_ROLE}" "${a}" "${res}")"
  p_star="$(decide "${PLAN_ROLE}" "${a}" '*')"
  q="$(decide "${APPLY_ROLE}" "${a}" "${res}")"
  q_star="$(decide "${APPLY_ROLE}" "${a}" '*')"
  if [ "${p}" = "allowed" ] || [ "${p_star}" = "allowed" ]; then
    echo "  FAIL  ${a}: the PLAN role is allowed (resource=${p}, \"*\"=${p_star})"
    fail=1
  elif [ "${q}" != "allowed" ] && [ "${q_star}" != "allowed" ]; then
    # The apply role must still be able to do it, or the split broke the apply.
    echo "  FAIL  ${a}: plan refused (good) but the APPLY role lost it too"
    echo "        (apply: resource=${q}, \"*\"=${q_star})"
    fail=1
  else
    if [ "${q}" = "allowed" ]; then w="on its resource"; else w="on \"*\" (takes no resource)"; fi
    echo "  ok    ${a}: plan refused, apply allowed ${w}"
  fi
done <<'LIST'
ecs:UpdateService|arn:aws:ecs:REGION:ACCOUNT:service/kambriq-dev-cluster/kambriq-dev-api
ecs:RegisterTaskDefinition|*
rds:ModifyDBInstance|arn:aws:rds:REGION:ACCOUNT:db:kambriq-dev-postgres
rds:DeleteDBInstance|arn:aws:rds:REGION:ACCOUNT:db:kambriq-dev-postgres
elasticache:ModifyReplicationGroup|arn:aws:elasticache:REGION:ACCOUNT:replicationgroup:kambriq-dev-redis
ssm:PutParameter|arn:aws:ssm:REGION:ACCOUNT:parameter/kambriq/dev/api/PROBE
ssm:DeleteParameter|arn:aws:ssm:REGION:ACCOUNT:parameter/kambriq/dev/api/PROBE
iam:PutRolePolicy|arn:aws:iam::ACCOUNT:role/kambriq-dev-ecs-task-api
iam:CreateRole|arn:aws:iam::ACCOUNT:role/kambriq-probe-role
iam:AttachRolePolicy|arn:aws:iam::ACCOUNT:role/kambriq-dev-ecs-task-api
s3:PutObject|arn:aws:s3:::kambriq-media-dev/probe.txt
s3:DeleteObject|arn:aws:s3:::kambriq-media-dev/probe.txt
elasticloadbalancing:CreateRule|arn:aws:elasticloadbalancing:REGION:ACCOUNT:listener/app/kambriq-dev-alb/0000000000000000/0000000000000000
elasticloadbalancing:ModifyListener|arn:aws:elasticloadbalancing:REGION:ACCOUNT:listener/app/kambriq-dev-alb/0000000000000000/0000000000000000
ec2:AuthorizeSecurityGroupIngress|arn:aws:ec2:REGION:ACCOUNT:security-group/sg-00000000000000000
ec2:CreateSecurityGroup|arn:aws:ec2:REGION:ACCOUNT:security-group/sg-00000000000000000
kms:PutKeyPolicy|KEY_ARN
kms:ScheduleKeyDeletion|KEY_ARN
logs:DeleteLogGroup|arn:aws:logs:REGION:ACCOUNT:log-group:/ecs/kambriq-dev-api:*
sns:Publish|arn:aws:sns:REGION:ACCOUNT:kambriq-dev-security-alerts
cloudtrail:StopLogging|arn:aws:cloudtrail:REGION:ACCOUNT:trail/kambriq-management-events
route53:ChangeResourceRecordSets|arn:aws:route53:::hostedzone/Z00411721R2YKO3VFIPU4
ses:CreateContactList|arn:aws:ses:REGION:ACCOUNT:contact-list/kambriq-newsletter
ses:DeleteContactList|arn:aws:ses:REGION:ACCOUNT:contact-list/kambriq-newsletter
LIST

# ---------------------------------------------------------------------------
# POSITIVE - the plan role must be able to read everything a plan refreshes.
#
# A denial against the case's resource that becomes "allowed" against "*" is
# not a gap in the policy: it means the action takes no resource and the case
# names one. That is reported as a NOTE against the case, not a FAIL against
# the policy, because the policy verdict is then unambiguous.
# ---------------------------------------------------------------------------
echo
echo "POSITIVE - the plan role must be able to read everything a plan refreshes:"
while IFS='|' read -r a res; do
  [ -z "${a}" ] && continue
  res="${res//ACCOUNT/${ACCOUNT}}"; res="${res//REGION/${REGION}}"
  res="${res//KEY_ARN/${KEY_ARN}}"
  p="$(decide "${PLAN_ROLE}" "${a}" "${res}")"
  if [ "${p}" = "allowed" ]; then
    echo "  ok    ${a}"
    continue
  fi
  p_star="$(decide "${PLAN_ROLE}" "${a}" '*')"
  if [ "${p_star}" = "allowed" ]; then
    echo "  NOTE  ${a}: refused on ${res} but allowed on \"*\" - this action"
    echo "        takes no resource; the grant is fine, the case's resource is not."
  else
    echo "  FAIL  ${a}: ${p} - a plan would break on this"
    fail=1
  fi
done <<'LIST'
ec2:DescribeSecurityGroups|*
ec2:DescribeSubnets|*
ec2:DescribeRouteTables|*
ec2:DescribeVpcs|*
ec2:DescribeVpcAttribute|*
ecs:DescribeServices|arn:aws:ecs:REGION:ACCOUNT:service/kambriq-dev-cluster/kambriq-dev-api
ecs:DescribeTaskDefinition|*
ecs:DescribeClusters|arn:aws:ecs:REGION:ACCOUNT:cluster/kambriq-dev-cluster
ecr:DescribeRepositories|arn:aws:ecr:REGION:ACCOUNT:repository/kambriq-api
ecr:GetLifecyclePolicy|arn:aws:ecr:REGION:ACCOUNT:repository/kambriq-api
elasticloadbalancing:DescribeRules|*
elasticloadbalancing:DescribeTargetGroups|*
elasticloadbalancing:DescribeListeners|*
rds:DescribeDBInstances|arn:aws:rds:REGION:ACCOUNT:db:kambriq-dev-postgres
rds:DescribeDBSubnetGroups|*
elasticache:DescribeReplicationGroups|*
elasticache:DescribeCacheSubnetGroups|*
ssm:DescribeParameters|*
ssm:GetParameter|arn:aws:ssm:REGION:ACCOUNT:parameter/kambriq/dev/api/DATABASE_URL_KBS
ssm:ListTagsForResource|arn:aws:ssm:REGION:ACCOUNT:parameter/kambriq/dev/api/DATABASE_URL_KBS
iam:GetRole|arn:aws:iam::ACCOUNT:role/kambriq-dev-ecs-task-api
iam:ListRolePolicies|arn:aws:iam::ACCOUNT:role/kambriq-dev-ecs-task-api
iam:GetUser|arn:aws:iam::ACCOUNT:user/kambriq-app-dev
logs:DescribeLogGroups|*
cloudwatch:DescribeAlarms|*
sns:GetTopicAttributes|arn:aws:sns:REGION:ACCOUNT:kambriq-dev-security-alerts
cloudtrail:DescribeTrails|*
cloudtrail:GetTrailStatus|arn:aws:cloudtrail:REGION:ACCOUNT:trail/kambriq-management-events
route53:GetHostedZone|arn:aws:route53:::hostedzone/Z00411721R2YKO3VFIPU4
acm:DescribeCertificate|arn:aws:acm:REGION:ACCOUNT:certificate/00000000-0000-0000-0000-000000000000
ses:GetContactList|arn:aws:ses:REGION:ACCOUNT:contact-list/kambriq-newsletter
ses:ListTagsForResource|*
kms:DescribeKey|KEY_ARN
kms:GetKeyPolicy|KEY_ARN
s3:GetAccountPublicAccessBlock|*
s3:GetBucketVersioning|arn:aws:s3:::kambriq-artifacts-b9321a78
tag:GetResources|*
LIST

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
check_allowed s3:GetObject "${STATE_SHARED}"
check_allowed s3:ListBucket "arn:aws:s3:::${STATE_BUCKET}"
# Writing the state is the apply's job, and the plan must not be able to.
for a in s3:PutObject s3:DeleteObject; do
  p="$(decide "${PLAN_ROLE}" "${a}" "${STATE}")"
  p_star="$(decide "${PLAN_ROLE}" "${a}" '*')"
  if [ "${p}" = "allowed" ] || [ "${p_star}" = "allowed" ]; then
    echo "  FAIL  ${a} on the state: ${p} - the plan role could overwrite the state"
    fail=1
  else
    echo "  ok    ${a} on the state: ${p}"
  fi
done

echo
echo "READ POWER, said out loud rather than implied:"
p="$(decide "${PLAN_ROLE}" ssm:GetParameter "arn:aws:ssm:${REGION}:${ACCOUNT}:parameter/kambriq/dev/api/JWT_SECRET")"
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
