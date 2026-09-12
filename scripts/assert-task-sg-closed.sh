#!/usr/bin/env bash
#
# D15 - the ECS task security group is the only thing between the tasks and the
# internet, so it is asserted rather than assumed.
#
# Moving the Fargate tasks into public subnets removed a layer. Before, a task
# was protected twice: by a private subnet with no inbound route, and by this
# security group. Now only the security group stands there, and a rule widened
# by accident is no longer caught by the subnet behind it.
#
# The check reads the **resolved plan**, not the Terraform source. A `dynamic
# "ingress"` block cannot be read by grepping, and the source does not say what
# `for_each` produced; the plan does. It also means a rule added by any route -
# a literal block, a dynamic one, a module - is seen the same way.
#
# Fails when any ingress rule on the task security group:
#   - carries a CIDR, v4 or v6, or a prefix list
#   - has `self = true`
#   - names any source security group other than the ALB's
#
set -euo pipefail

PLAN_JSON="${1:?usage: assert-task-sg-closed.sh <plan.json>}"

alb_sg="$(jq -r '
  [.planned_values.root_module.child_modules[]?.resources[]?
   | select(.type=="aws_security_group" and .name=="alb")
   | .values.id] | first // empty' "$PLAN_JSON")"

if [ -z "$alb_sg" ]; then
  echo "FAIL: no ALB security group found in the plan - cannot establish the one legitimate source." >&2
  exit 1
fi

task_sg="$(jq -c '
  [.planned_values.root_module.resources[]?
   | select(.type=="aws_security_group" and .name=="ecs")] | first // empty' "$PLAN_JSON")"

if [ -z "$task_sg" ]; then
  echo "FAIL: no ECS task security group (aws_security_group.ecs) found in the plan." >&2
  exit 1
fi

violations="$(jq -r --arg alb "$alb_sg" '
  .values.ingress[]? as $r
  | [ (if ($r.cidr_blocks      | length) > 0 then "carries IPv4 CIDR \($r.cidr_blocks|join(","))"      else empty end),
      (if ($r.ipv6_cidr_blocks | length) > 0 then "carries IPv6 CIDR \($r.ipv6_cidr_blocks|join(","))" else empty end),
      (if ($r.prefix_list_ids  | length) > 0 then "carries prefix list \($r.prefix_list_ids|join(","))" else empty end),
      (if $r.self then "allows itself as a source" else empty end),
      (if ([$r.security_groups[]? | select(. != $alb)] | length) > 0
         then "names a source security group that is not the ALB: \([$r.security_groups[]? | select(. != $alb)]|join(","))"
         else empty end),
      (if (($r.security_groups | length) == 0 and ($r.cidr_blocks | length) == 0
           and ($r.ipv6_cidr_blocks | length) == 0 and ($r.prefix_list_ids | length) == 0 and ($r.self | not))
         then "has no source at all" else empty end)
    ]
  | map("    port \($r.from_port)-\($r.to_port): " + .)[]' <<<"$task_sg")"

if [ -n "$violations" ]; then
  cat >&2 <<EOF
FAIL: the ECS task security group admits traffic from something other than the ALB.

  The tasks run in public subnets with public IPs. This security group is the
  only thing between them and the internet, so every ingress rule must name the
  ALB security group ($alb_sg) and nothing else.

$violations

  If this rule is deliberate, it is a decision about exposing a task directly to
  the internet and belongs in the register, not in a security group.
EOF
  exit 1
fi

rules="$(jq -r '.values.ingress | length' <<<"$task_sg")"
echo "OK: all $rules ingress rules on the task security group name only the ALB ($alb_sg)."
