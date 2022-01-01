#!/usr/bin/env bash
#
# burst-fill.sh — sprinkle occasional *heavy* days (15-30 commits) across a date
# range, layered on top of whatever backfill already exists. Where backfill.sh /
# backfill-range.sh give a steady 1-6 commits/day, this creates the rare dark
# burst day so the graph reads as natural rather than uniform.
#
# Usage:
#   ./burst-fill.sh [START] [END] [FREQUENCY] [MIN_COMMITS] [MAX_COMMITS]
#
#   START        YYYY-MM-DD (inclusive)  (default 2026-01-01)
#   END          YYYY-MM-DD (inclusive)  (default today)
#   FREQUENCY    % chance a given day becomes a burst day  (default 7 = sparse)
#   MIN_COMMITS  min commits on a burst day                (default 15)
#   MAX_COMMITS  max commits on a burst day                (default 30)
#
# Example (default: scatter ~7% of 2026-so-far with 15-30 commit bursts):
#   ./burst-fill.sh
#   ./burst-fill.sh 2026-01-01 2026-07-24 10 15 30
#
# Uses BSD `date` (macOS). Run locally, then push. No `set -e`: bash (( ))
# returns non-zero when it evaluates to 0, which would kill an -e script.

set -uo pipefail
cd "$(dirname "$0")"

START="${1:-2026-01-01}"
END="${2:-$(date +%F)}"
FREQUENCY="${3:-7}"
MIN_COMMITS="${4:-15}"
MAX_COMMITS="${5:-30}"

# Anchor each day at noon so DST shifts never bump a commit onto the wrong date.
cur=$(date -j -f "%Y-%m-%d %H:%M:%S" "$START 12:00:00" +%s)
end=$(date -j -f "%Y-%m-%d %H:%M:%S" "$END 12:00:00" +%s)

span=$(( MAX_COMMITS - MIN_COMMITS + 1 ))
echo "Bursting ${START} -> ${END} at ~${FREQUENCY}% of days (${MIN_COMMITS}-${MAX_COMMITS} commits/burst)..."

total=0
days=0
while [ "$cur" -le "$end" ]; do
  day=$(date -r "$cur" +%Y-%m-%d)

  if (( RANDOM % 100 < FREQUENCY )); then
    n=$(( RANDOM % span + MIN_COMMITS ))
    days=$(( days + 1 ))
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
    echo "  ${day}: +${n} commits"
  fi

  cur=$(( cur + 86400 ))
done

echo "Done. ${total} commits across ${days} burst day(s), ${START} -> ${END}."
