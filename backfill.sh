#!/usr/bin/env bash
#
# backfill.sh — one-time script to paint the past N days of your contribution
# graph at a natural-looking frequency. Run this once, locally (macOS).
#
# Usage:
#   ./backfill.sh [DAYS_BACK] [FREQUENCY] [MAX_COMMITS]
#
#   DAYS_BACK    how many days of history to fill        (default 365)
#   FREQUENCY    % chance a given day gets any commits   (default 80)
#   MAX_COMMITS  max commits on an active day (shading)  (default 6)
#
# Examples:
#   ./backfill.sh                # last 365 days, ~80% of days green
#   ./backfill.sh 730 70 8       # last 2 years, ~70% frequency, darker peaks
#
# NOTE: uses BSD `date` (macOS). The daily cloud job in .github/workflows
# handles keeping the graph going forward — this is just the historical fill.

set -euo pipefail
cd "$(dirname "$0")"

DAYS_BACK=${1:-365}
FREQUENCY=${2:-80}
MAX_COMMITS=${3:-6}

echo "Backfilling ~${DAYS_BACK} days at ~${FREQUENCY}% frequency (up to ${MAX_COMMITS} commits/day)..."

total=0
for ((i=DAYS_BACK; i>=0; i--)); do
  day=$(date -v-"${i}"d +%Y-%m-%d)

  # Roll the dice: skip ~ (100 - FREQUENCY)% of days so it isn't a perfect wall.
  if (( RANDOM % 100 >= FREQUENCY )); then
    continue
  fi

  # Random number of commits => varied shades of green.
  n=$(( RANDOM % MAX_COMMITS + 1 ))
  for ((c=1; c<=n; c++)); do
    hh=$(printf "%02d" $(( RANDOM % 18 + 6 )))   # 06:00–23:59, waking hours
    mm=$(printf "%02d" $(( RANDOM % 60 )))
    ss=$(printf "%02d" $(( RANDOM % 60 )))
    stamp="${day}T${hh}:${mm}:${ss}"

    echo "${stamp} keepgreen ${RANDOM}${RANDOM}" >> activity.log
    git add activity.log
    GIT_AUTHOR_DATE="$stamp" GIT_COMMITTER_DATE="$stamp" \
      git commit -q -m "chore: activity ${day} (#${c})"
    total=$(( total + 1 ))
  done
done

echo "Done. Created ${total} backdated commits."
echo "Next: create the remote and push (see README), then the daily job takes over."
