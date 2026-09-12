#!/usr/bin/env bash
#
# Warn on Actions minutes while there is still margin, not after they run out.
#
# Between 7 and 11 September 2026 the account hit its spending limit. Jobs did
# not fail - they never started, in two to three seconds, with zero steps and no
# log. Five substantial pull requests merged with nothing verified, and the first
# run that actually executed afterwards came back red.
#
# **That failure mode is worse now, not better.** Branch protection makes the
# required checks binding, so the next time minutes run out nothing merges at
# all, on either repository, and the only symptom is a check that never reports.
#
# Nothing warns today. Consumption is invisible until it stops the world, so this
# reads it and objects while there is still room to act.
#
# Exit codes: 0 under the warn line, 0 with a warning between warn and fail,
# 1 at or above the fail line. Unreadable is exit 1 as well: a watcher that
# cannot see is not a watcher that says everything is fine.
#
set -euo pipefail

ORG="${ORG:-kloudnat-digital}"
# GitHub Team includes 3000 minutes a month for private repositories. The API
# reports consumption but NOT the allowance and NOT the spending limit, so this
# is the plan's published figure rather than a number read back - see the
# --explain output.
ALLOWANCE="${ALLOWANCE:-3000}"
WARN_PCT="${WARN_PCT:-70}"
FAIL_PCT="${FAIL_PCT:-85}"

year="$(date -u +%Y)"; month="$(date -u +%-m)"

if ! raw="$(gh api "organizations/${ORG}/settings/billing/usage?year=${year}&month=${month}" 2>&1)"; then
  cat >&2 <<EOF
FAIL: cannot read Actions usage for ${ORG}.

  ${raw}

  This check refuses rather than passing. The whole point is to see a limit
  coming; a watcher that cannot read must not report healthy.

  The workflow token is repository-scoped and has no org billing access. This
  needs a secret holding a token with read:org. It is a credential operation and
  belongs to Visquis, not to CI.
EOF
  exit 1
fi

used="$(jq -r '[.usageItems[] | select(.unitType=="Minutes") | .quantity] | add // 0' <<<"$raw")"
used_i="$(printf '%.0f' "$used")"
pct="$(awk -v u="$used_i" -v a="$ALLOWANCE" 'BEGIN{printf "%.1f", (u/a)*100}')"
left="$(( ALLOWANCE - used_i ))"

# Burn rate over elapsed days of the month, and what margin that leaves.
day="$(date -u +%-d)"
burn="$(awk -v u="$used_i" -v d="$day" 'BEGIN{printf "%.1f", u/d}')"
margin="$(awk -v l="$left" -v b="$burn" 'BEGIN{ if (b<=0) print "n/a"; else printf "%.1f", l/b }')"

echo "Actions minutes, ${ORG}, ${year}-${month}:"
echo "  used       ${used_i} of ${ALLOWANCE}  (${pct}%)"
echo "  remaining  ${left} minutes"
echo "  burn       ${burn} min/day over ${day} elapsed days"
echo "  margin     ${margin} days at that rate"

over_fail="$(awk -v p="$pct" -v t="$FAIL_PCT" 'BEGIN{print (p>=t)?1:0}')"
over_warn="$(awk -v p="$pct" -v t="$WARN_PCT" 'BEGIN{print (p>=t)?1:0}')"

if [ "$over_fail" = "1" ]; then
  cat >&2 <<EOF

FAIL: Actions minutes are at ${pct}% of the included allowance (threshold ${FAIL_PCT}%).

  When they run out, jobs do not fail - they never start, and a check that never
  reports leaves every pull request on both repositories unmergeable, because the
  required checks can never arrive. There is no error to read in that state.

  Acting now means raising the limit, or cutting what a run costs. Acting later
  is not an option, because the mechanism that would tell you is the one that
  stops.
EOF
  exit 1
fi

if [ "$over_warn" = "1" ]; then
  echo
  echo "WARNING: ${pct}% of the allowance used, past the ${WARN_PCT}% line with ${margin} days of margin."
  echo "Not failing yet. It fails at ${FAIL_PCT}%."
fi
