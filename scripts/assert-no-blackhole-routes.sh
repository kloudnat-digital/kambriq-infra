#!/usr/bin/env bash
#
# D15 - no route may point at a target that no longer exists.
#
# This is the specific failure the NAT removal risks. Delete a gateway and every
# route still aimed at it does not disappear: AWS keeps the entry and marks its
# state `blackhole`. Traffic matching it is then dropped silently - not refused,
# not logged, dropped - which is the worst shape a network fault can take,
# because nothing reports it and the symptom appears somewhere else entirely.
#
# Read from the live route tables rather than the plan, deliberately. A blackhole
# is a fact about what AWS currently holds, not about what Terraform intends: it
# appears *after* an apply removes a target, and a plan taken before that apply
# cannot show it. Terraform is also content to leave one in place, because the
# route still exists as far as state is concerned.
#
# Usage:
#   assert-no-blackhole-routes.sh <vpc-id>          read the live route tables
#   assert-no-blackhole-routes.sh --file <json>     read a describe-route-tables
#                                                   document, for testing the check
set -euo pipefail

if [ "${1:-}" = "--file" ]; then
  doc="$(cat "${2:?usage: --file <json>}")"
  source_desc="file ${2}"
else
  vpc="${1:?usage: assert-no-blackhole-routes.sh <vpc-id> | --file <json>}"
  doc="$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=${vpc}" --output json)"
  source_desc="live route tables in ${vpc}"
fi

bad="$(jq -r '
  .RouteTables[]? as $rt
  | $rt.Routes[]?
  | select(.State != "active")
  | "    \($rt.RouteTableId) \(
      .DestinationCidrBlock // .DestinationIpv6CidrBlock // .DestinationPrefixListId // "?"
    ) -> \(
      .NatGatewayId // .GatewayId // .TransitGatewayId // .NetworkInterfaceId //
      .VpcPeeringConnectionId // .InstanceId // "unknown target"
    )  [state: \(.State)]"' <<<"$doc")"

total="$(jq -r '[.RouteTables[]?.Routes[]?] | length' <<<"$doc")"

if [ -n "$bad" ]; then
  cat >&2 <<EOF
FAIL: a route points at a target that no longer exists.

  AWS keeps the entry and marks it blackhole; traffic matching it is dropped
  with no error anywhere. Delete the route, or restore the target.

$bad

  Checked: $source_desc
EOF
  exit 1
fi

echo "OK: all $total routes resolve to a live target ($source_desc)."
