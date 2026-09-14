#!/usr/bin/env bash
#
# D17 - production and development share one VPC, so their isolation is
# configurational, not physical. This refuses the three ways one environment can
# reach into the other:
#
#   1. a security group in one env admits a security group of the other;
#   2. a role in one env can read an SSM parameter of the other;
#   3. a security-group rule cites a CIDR that covers the other env's subnets.
#
# It judges a PAIR of environments that must not cross (default dev / prod).
# "shared" is exempt on purpose: both environments legitimately use the shared
# VPC, buckets and zone, so a dev-or-prod resource pointing at shared is not a
# crossing. A crossing is dev<->prod specifically.
#
# Reads the live estate by default. Give INPUT=<file> a saved estate document to
# test the check itself without touching AWS - that is how its red and green are
# proven.
#
set -euo pipefail

REGION="${REGION:-eu-central-1}"
ENV_A="${ENV_A:-dev}"
ENV_B="${ENV_B:-prod}"
INPUT="${INPUT:-}"

tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT

if [ -n "$INPUT" ]; then
  cp "$INPUT" "$tmp"
else
  # ---- gather the live estate into the document the checker consumes ----
  # shellcheck disable=SC2016  # backticks are JMESPath, must stay literal
  sgs="$(aws ec2 describe-security-groups --region "$REGION" \
        --query 'SecurityGroups[].{id:GroupId,env:Tags[?Key==`Environment`]|[0].Value,peers:IpPermissions[].UserIdGroupPairs[].GroupId,cidrs:IpPermissions[].IpRanges[].CidrIp}' --output json)"
  # shellcheck disable=SC2016
  sgenv="$(aws ec2 describe-security-groups --region "$REGION" \
          --query 'SecurityGroups[].{id:GroupId,env:Tags[?Key==`Environment`]|[0].Value}' --output json)"
  # shellcheck disable=SC2016
  subnets="$(aws ec2 describe-subnets --region "$REGION" \
            --query 'Subnets[].{cidr:CidrBlock,env:Tags[?Key==`Environment`]|[0].Value}' --output json)"
  acct="$(aws sts get-caller-identity --query Account --output text)"
  roles_json="["
  first=1
  for role in $(aws iam list-roles --query "Roles[?contains(RoleName,'kambriq')].RoleName" --output text); do
    renv=""
    case "$role" in
      *-"$ENV_A"-*|"$ENV_A"-*|*-"$ENV_A") renv="$ENV_A" ;;
      *-"$ENV_B"-*|"$ENV_B"-*|*-"$ENV_B") renv="$ENV_B" ;;
    esac
    [ -z "$renv" ] && continue
    other="$ENV_A"; [ "$renv" = "$ENV_A" ] && other="$ENV_B"
    probe="arn:aws:ssm:${REGION}:${acct}:parameter/kambriq/${other}/db/DB_PASSWORD"
    dec="$(aws iam simulate-principal-policy --policy-source-arn "arn:aws:iam::${acct}:role/${role}" \
           --action-names ssm:GetParameter --resource-arns "$probe" \
           --query 'EvaluationResults[0].EvalDecision' --output text 2>/dev/null || echo error)"
    canread="false"; [ "$dec" = "allowed" ] && canread="true"
    [ "$first" -eq 0 ] && roles_json="$roles_json,"
    roles_json="$roles_json{\"name\":\"$role\",\"env\":\"$renv\",\"reads_other_ssm\":$canread,\"other\":\"$other\"}"
    first=0
  done
  roles_json="$roles_json]"
  python3 -c "
import json,sys
json.dump({
  'security_groups': json.loads(sys.argv[1]),
  'sg_env': json.loads(sys.argv[2]),
  'subnets': json.loads(sys.argv[3]),
  'roles': json.loads(sys.argv[4]),
}, open(sys.argv[5],'w'))" "$sgs" "$sgenv" "$subnets" "$roles_json" "$tmp"
fi

python3 - "$ENV_A" "$ENV_B" "$tmp" <<'PY'
import json, sys, ipaddress
A, B, path = sys.argv[1], sys.argv[2], sys.argv[3]
PAIR = {A, B}
e = json.load(open(path))

sg_env = {r["id"]: r.get("env") for r in e.get("sg_env", [])}
for sg in e.get("security_groups", []):
    sg_env.setdefault(sg["id"], sg.get("env"))

fails = []

# 1. SG admits a peer SG of the other environment
for sg in e.get("security_groups", []):
    env = sg.get("env")
    if env not in PAIR:
        continue
    for peer in (sg.get("peers") or []):
        penv = sg_env.get(peer)
        if penv in PAIR and penv != env:
            fails.append(f'security group {sg["id"]} ({env}) admits {peer} ({penv}) - a cross-environment ingress')

# 2. role in one env can read the other's SSM
for r in e.get("roles", []):
    if r.get("env") in PAIR and r.get("reads_other_ssm"):
        fails.append(f'role {r["name"]} ({r["env"]}) can read /kambriq/{r.get("other")}/ SSM parameters')

# 3. a CIDR on one env's SG covers the other env's subnets
subnets = [s for s in e.get("subnets", []) if s.get("env") in PAIR and s.get("cidr")]
for sg in e.get("security_groups", []):
    env = sg.get("env")
    if env not in PAIR:
        continue
    for cidr in (sg.get("cidrs") or []):
        try:
            net = ipaddress.ip_network(cidr, strict=False)
        except ValueError:
            continue
        for s in subnets:
            if s["env"] == env:
                continue
            try:
                sub = ipaddress.ip_network(s["cidr"], strict=False)
            except ValueError:
                continue
            if net.overlaps(sub):
                fails.append(f'security group {sg["id"]} ({env}) cites {cidr}, which covers {s["env"]} subnet {s["cidr"]}')

pair = f"{A} / {B}"
if fails:
    print(f"\nFAIL: {len(fails)} cross-environment crossing(s) between {pair}.\n", file=sys.stderr)
    for f in fails:
        print(f"  {f}", file=sys.stderr)
    sys.exit(1)
print(f"OK: no security group, role or CIDR crosses between {pair}.")
PY
