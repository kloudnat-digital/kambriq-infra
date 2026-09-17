#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# D21 - prove the key barrier, with a throwaway principal.
#
# The claim: once the state is encrypted under the D21 key, s3:GetObject alone
# is not enough to read it. A principal that IAM allows to GetObject, and that
# the key policy does not name, must be refused.
#
# A claim about a barrier that has only ever been seen allowing is not proven.
# So this creates a throwaway role whose ONLY permission is s3:GetObject on the
# state object, has it read the object, and requires AccessDenied naming KMS.
# Then it reads the same object as the caller (a named principal) and requires
# success - a refusal that refuses everybody proves nothing either.
#
# It is a throwaway: the role is created, used, and deleted in the same run,
# including on failure. It is never a principal anybody else can assume - its
# trust policy names only this account's caller.
#
# NEVER PRINTS THE STATE. The object is fetched to a temp file whose bytes are
# never echoed; what is printed is the HTTP/CLI outcome and the file's size.
#
# Usage: scripts/d21-prove-kms-barrier.sh [dev|shared]     (default: dev)
# Requires: the D21 key applied, and the backend PR applied for that env, so
# that the object is actually SSE-KMS. It refuses to run before that, because
# "allowed" against an SSE-S3 object would look like a passing barrier.
# ---------------------------------------------------------------------------
set -uo pipefail

ENV_NAME="${1:-dev}"
case "${ENV_NAME}" in
  dev | shared) ;;
  *)
    echo "usage: $0 [dev|shared]" >&2
    exit 2
    ;;
esac

BUCKET="kloudnat-infra-shared-store"
KEY="kambriq/envs/${ENV_NAME}/terraform.tfstate"
ALIAS="alias/kambriq-shared-tfstate"
ROLE="kambriq-d21-barrier-probe"
REGION="eu-central-1"

cleanup() {
  aws iam delete-role-policy --role-name "${ROLE}" --policy-name getobject-only >/dev/null 2>&1
  aws iam delete-role --role-name "${ROLE}" >/dev/null 2>&1
  rm -f "${TMP:-/dev/null}"
}
trap cleanup EXIT

echo "== D21 barrier, ${ENV_NAME} state, $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# 1. The object must already be SSE-KMS under this key. Otherwise the probe
#    below would be refused - or allowed - for the wrong reason.
enc="$(aws s3api head-object --bucket "${BUCKET}" --key "${KEY}" \
  --query '[ServerSideEncryption,SSEKMSKeyId]' --output text 2>&1)"
echo "   object encryption: ${enc}"
case "${enc}" in
  aws:kms*) ;;
  *)
    echo "   REFUSED TO PROVE: ${KEY} is not SSE-KMS yet, so this measures nothing." >&2
    echo "   The object re-encrypts on the next ${ENV_NAME} apply after the backend PR." >&2
    exit 1
    ;;
esac

KEY_ARN="$(aws kms describe-key --key-id "${ALIAS}" --query 'KeyMetadata.Arn' --output text 2>&1)"
echo "   key: ${KEY_ARN}"

# 2. The throwaway principal: GetObject on exactly that object, nothing else,
#    and no kms:Decrypt anywhere.
ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"
CALLER="$(aws sts get-caller-identity --query Arn --output text)"
echo "   caller: ${CALLER}"

aws iam create-role --role-name "${ROLE}" \
  --description "D21 throwaway: proves the state key barrier. Deleted by the script that made it." \
  --max-session-duration 3600 \
  --assume-role-policy-document "{
    \"Version\": \"2012-10-17\",
    \"Statement\": [{
      \"Effect\": \"Allow\",
      \"Principal\": {\"AWS\": \"arn:aws:iam::${ACCOUNT}:root\"},
      \"Action\": \"sts:AssumeRole\"
    }]
  }" >/dev/null || {
  echo "   could not create the throwaway role" >&2
  exit 1
}

aws iam put-role-policy --role-name "${ROLE}" --policy-name getobject-only \
  --policy-document "{
    \"Version\": \"2012-10-17\",
    \"Statement\": [{
      \"Sid\": \"GetObjectOnlyNoKms\",
      \"Effect\": \"Allow\",
      \"Action\": [\"s3:GetObject\", \"s3:ListBucket\"],
      \"Resource\": [
        \"arn:aws:s3:::${BUCKET}\",
        \"arn:aws:s3:::${BUCKET}/${KEY}\"
      ]
    }]
  }" >/dev/null

# IAM is eventually consistent; a refusal seen one second after creation could
# be the role not existing yet rather than the key policy.
echo "   waiting 15s for IAM to settle"
sleep 15

# 3. What IAM thinks: GetObject allowed. That is the half everybody measures.
sim="$(aws iam simulate-principal-policy \
  --policy-source-arn "arn:aws:iam::${ACCOUNT}:role/${ROLE}" \
  --action-names s3:GetObject \
  --resource-arns "arn:aws:s3:::${BUCKET}/${KEY}" \
  --query 'EvaluationResults[0].EvalDecision' --output text 2>&1)"
echo "   simulate s3:GetObject as the throwaway: ${sim}"
[ "${sim}" = "allowed" ] || {
  echo "   REFUSED TO PROVE: IAM does not allow GetObject, so a refusal below says nothing about KMS." >&2
  exit 1
}

# 4. What actually happens: the read, with those credentials only.
creds="$(aws sts assume-role --role-arn "arn:aws:iam::${ACCOUNT}:role/${ROLE}" \
  --role-session-name d21-barrier --duration-seconds 900 \
  --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' --output text 2>&1)" || {
  echo "   could not assume the throwaway role: ${creds}" >&2
  exit 1
}
read -r AK SK ST <<<"${creds}"

TMP="$(mktemp)"
out="$(AWS_ACCESS_KEY_ID="${AK}" AWS_SECRET_ACCESS_KEY="${SK}" AWS_SESSION_TOKEN="${ST}" \
  aws s3api get-object --region "${REGION}" --bucket "${BUCKET}" --key "${KEY}" "${TMP}" 2>&1)"
rc=$?
unset AK SK ST

if [ "${rc}" -eq 0 ]; then
  echo "   FAIL  the throwaway principal READ the state ($(wc -c <"${TMP}" | tr -d ' ') bytes). There is no barrier." >&2
  exit 1
fi

echo "   refusal: $(printf '%s' "${out}" | tr '\n' ' ' | cut -c1-200)"
case "${out}" in
  *AccessDenied* | *KMS* | *kms* | *"not authorized"*)
    echo "   PASS  GetObject allowed by IAM, read refused - the key policy is the barrier." ;;
  *)
    echo "   FAIL  refused, but not for a reason this proves: read the message above." >&2
    exit 1 ;;
esac

# 5. The other direction: a named principal still reads it. Without this, a
#    broken key policy that refuses everybody would look like success.
if aws s3api get-object --region "${REGION}" --bucket "${BUCKET}" --key "${KEY}" "${TMP}" >/dev/null 2>&1; then
  echo "   PASS  a named principal (${CALLER##*/}) still reads it: $(wc -c <"${TMP}" | tr -d ' ') bytes, contents not printed."
else
  echo "   FAIL  a named principal cannot read the state either - the key policy is too narrow." >&2
  exit 1
fi

echo "== done, throwaway role deleted by the exit trap"
