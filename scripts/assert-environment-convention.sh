#!/usr/bin/env bash
#
# Every resource carries its environment, in a tag and in its name.
#
# Three failures, and the third is the one worth building this for:
#   - no Environment tag: the resource cannot be attributed or billed;
#   - a value outside shared / prod / dev: a fourth value is a second convention;
#   - a Name tag whose environment word CONTRADICTS the Environment tag. That is
#     worse than no tag at all, because it is not silence, it is a false
#     statement, and the reader has no way to know which half is wrong.
#
# The tag is validated universally. The IDENTIFIER is validated only where the
# convention governs from birth, because a name cannot be changed without
# replacing the resource - renaming this estate would replace the database,
# sixty SSM parameters, six IAM roles, four security groups, four log groups and
# three buckets. A check whose first run refuses everything gets weakened until
# it refuses nothing, so it refuses only what somebody can actually fix.
#
# Existing identifiers are a CLOSED, dated list. The list may shrink. Any
# resource lacking an environment word that is NOT on it fails, and the message
# says so - an exception list that grows silently is how a convention dies.
#
set -euo pipefail

REGION="${REGION:-eu-central-1}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXCEPTIONS="${EXCEPTIONS:-$HERE/environment-convention-exceptions.txt}"
INPUT="${INPUT:-}"   # a saved tagging-API document, for testing the check itself

if [ -n "$INPUT" ]; then
  doc="$(cat "$INPUT")"
else
  doc="$(aws resourcegroupstaggingapi get-resources --region "$REGION" --max-items 500 \
          --query 'ResourceTagMappingList[].{a:ResourceARN,t:Tags}' --output json)"
fi

tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
printf '%s' "$doc" > "$tmp"

python3 - "$EXCEPTIONS" "$tmp" <<'PY'
import json, re, sys
exc_path, doc_path = sys.argv[1], sys.argv[2]
doc = json.load(open(doc_path))
ALLOWED = {"shared", "prod", "dev"}
WORD = re.compile(r'(^|[-_/:])(dev|prod|prd|shared)([-_/:.]|$)', re.I)

exceptions = []
for line in open(exc_path):
    line = re.sub(r'#.*', '', line).strip()
    if line:
        exceptions.append(line)

fails = []
checked = 0
# An ECS task-definition revision is immutable: it cannot be retagged once
# registered, so every superseded revision would fail forever and no one could
# fix it. Only the newest revision of each family is judged - that is the one a
# change can still reach.
latest = {}
for r in doc:
    m = re.match(r'(.*task-definition/[^:]+):(\d+)$', r["a"])
    if m:
        fam, rev = m.group(1), int(m.group(2))
        if rev > latest.get(fam, -1):
            latest[fam] = rev

for r in doc:
    arn = r["a"]
    if "kambriq" not in arn.lower():
        continue                      # another project's resources are not ours to judge
    keys = {t["Key"] for t in (r.get("t") or [])}
    if any(k.startswith(("elbv2.k8s.aws/", "ingress.k8s.aws/")) for k in keys):
        continue                      # owned by the k8s load-balancer controller on the
                                      # shared EKS cluster - a different system creates and
                                      # tags these; the "kambriq" in the ARN is a k8s service
                                      # name, not our resource. Not ours to judge or retag.
    m = re.match(r'(.*task-definition/[^:]+):(\d+)$', arn)
    if m and int(m.group(2)) != latest.get(m.group(1)):
        continue                      # a superseded revision, immutable and unfixable
    tags = {t["Key"]: t["Value"] for t in (r.get("t") or [])}
    tail = ":".join(arn.split(":")[5:])
    checked += 1
    env = tags.get("Environment")

    if env is None:
        fails.append((arn, "no Environment tag"))
        continue
    if env not in ALLOWED:
        fails.append((arn, f'Environment="{env}" is outside shared / prod / dev'))
        continue

    name = tags.get("Name", "")
    m = WORD.search(name)
    if m:
        word = m.group(2).lower()
        word = "prod" if word == "prd" else word
        if word != env:
            fails.append((arn, f'Name tag says "{word}" and the Environment tag says "{env}" - one of them is a lie'))
            continue

    if not WORD.search(tail):
        if not any(e in arn for e in exceptions):
            fails.append((arn, "identifier carries no environment word and is not on the closed exception list "
                               "(dated 2026-09-13). A new resource must be born with its environment in its name; "
                               "adding a line to that list is a decision to argue for in review, not a fix"))

print(f"checked {checked} kambriq resources in the tagging API")
if fails:
    print(f"\nFAIL: {len(fails)} resource(s) break the environment convention.\n", file=sys.stderr)
    for arn, why in fails:
        print(f"  {arn}\n      {why}", file=sys.stderr)
    sys.exit(1)
print("OK: every resource carries a valid Environment tag, no Name contradicts it, "
      "and no identifier outside the closed list lacks its environment word.")
PY
