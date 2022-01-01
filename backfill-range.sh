#!/usr/bin/env bash
#
# backfill-range.sh — fill commits between two explicit dates (inclusive) at a
# given frequency. Good for a sparse, "scattered" look over an older period,
# vs. the dense trailing-year fill that backfill.sh does.
#
# Usage:
#   ./backfill-range.sh START END [FREQUENCY] [MAX_COMMITS]
#
#   START/END    YYYY-MM-DD (inclusive)
#   FREQUENCY    % chance a given day gets any commits   (default 35 = scattered)
#   MAX_COMMITS  max commits on an active day (shading)  (default 3)
#
# Example (scatter 2024 through mid-2025):
#   ./backfill-range.sh 2024-01-01 2025-07-23 35 3
#
# Uses BSD `date` (macOS). Run locally, then push.

set -uo pipefail
cd "$(dirname "$0")"

START="${1:?usage: backfill-range.sh START END [FREQUENCY] [MAX_COMMITS]}"
END="${2:?usage: backfill-range.sh START END [FREQUENCY] [MAX_COMMITS]}"
FREQUENCY="${3:-35}"
MAX_COMMITS="${4:-3}"

# Anchor each day at noon so DST shifts never bump a commit onto the wrong date.
cur=$(date -j -f "%Y-%m-%d %H:%M:%S" "$START 12:00:00" +%s)
end=$(date -j -f "%Y-%m-%d %H:%M:%S" "$END 12:00:00" +%s)

echo "Scattering ${START} -> ${END} at ~${FREQUENCY}% (up to ${MAX_COMMITS} commits/day)..."

total=0
while [ "$cur" -le "$end" ]; do
  day=$(date -r "$cur" +%Y-%m-%d)

  if (( RANDOM % 100 < FREQUENCY )); then
    n=$(( RANDOM % MAX_COMMITS + 1 ))
    for ((c=1; c<=n; c++)); do
      hh=$(printf "%02d" $(( RANDOM % 18 + 6 )))
      mm=$(printf "%02d" $(( RANDOM % 60 )))
      ss=$(printf "%02d" $(( RANDOM % 60 )))
      stamp="${day}T${hh}:${mm}:${ss}"

      echo "${stamp} keepgreen ${RANDOM}${RANDOM}" >> activity.log
      git add activity.log
      GIT_AUTHOR_DATE="$stamp" GIT_COMMITTER_DATE="$stamp" \
        git commit -q -m "chore: activity ${day} (#${c})"
      total=$(( total + 1 ))
    done
  fi

  cur=$(( cur + 86400 ))
done

echo "Done. Created ${total} scattered commits from ${START} to ${END}."
