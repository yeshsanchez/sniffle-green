#!/usr/bin/env bash
#
# repaint-history.sh — ONE-SHOT, DESTRUCTIVE history rebuild.
#
# Rebuilds the whole commit history chronologically on a fresh orphan branch:
#   * every commit with author-date < WINDOW_START is reproduced exactly (same
#     per-day counts) so older years' graph is untouched;
#   * WINDOW_START..today is repainted with a natural profile — ~FREQ_NORMAL%
#     active-day frequency, a few fully-dead and sparse weeks to break up the
#     wall, and the occasional 15-30 commit burst day.
#
# It does NOT push and does NOT move `main`. It leaves the result on a branch
# called `repaint` for review. A backup branch (`backup-pre-repaint`) and a
# bundle should exist before running. To adopt:
#   git branch -M repaint main && git push --force-with-lease origin main
#
# Uses BSD `date` (macOS). No `set -e`: bash (( )) returns non-zero on a 0 value.

set -uo pipefail
cd "$(dirname "$0")"

WINDOW_START="2025-07-25"          # first day of the region we repaint (inclusive)
TODAY="$(date +%F)"
FREQ_NORMAL=67                     # active-day % on a normal week
FREQ_SPARSE=30                     # active-day % on a sparse week
DEAD_WEEK_PCT=10                  # chance a week is fully dead (a gap)
SPARSE_WEEK_PCT=8                 # chance a week is sparse
BURST_DAY_PCT=6                   # chance an active day is a 15-30 burst
MAXC=6                            # max commits on a normal active day

PROJECT_FILES=(.github/workflows/keepgreen.yml .gitignore README.md \
  backfill-range.sh backfill.sh burst-fill.sh daily-commit.sh repaint-history.sh \
  launchd/com.yeshsanchez.keepgreen.plist)

# 1. Capture the keep-region author-dates (one line per commit), sorted ascending.
git log --pretty=%ad --date=format:%Y-%m-%d | awk -v w="$WINDOW_START" '$0 < w' | sort > /tmp/keep_dates.txt
keepn=$(wc -l < /tmp/keep_dates.txt | tr -d ' ')
echo "Keep region: ${keepn} commits (< ${WINDOW_START}) reproduced exactly."

first=1
mkcommit() {  # $1 = day (YYYY-MM-DD)
  local day="$1" hh mm ss stamp
  hh=$(printf "%02d" $(( RANDOM % 18 + 6 )))
  mm=$(printf "%02d" $(( RANDOM % 60 )))
  ss=$(printf "%02d" $(( RANDOM % 60 )))
  stamp="${day}T${hh}:${mm}:${ss}"
  echo "${stamp} keepgreen ${RANDOM}${RANDOM}" >> activity.log
  git add activity.log
  if [ "$first" = 1 ]; then
    git add "${PROJECT_FILES[@]}"
    first=0
  fi
  GIT_AUTHOR_DATE="$stamp" GIT_COMMITTER_DATE="$stamp" \
    git commit -q -m "chore: activity ${day}"
}

# 2. Fresh orphan history (keeps working-tree files; clears the index).
git checkout -q --orphan repaint
git rm -rq --cached . >/dev/null 2>&1 || true
: > activity.log

# 3. Reproduce the keep region verbatim (already sorted ascending).
echo "Reproducing keep region..."
while IFS= read -r day; do
  mkcommit "$day"
done < /tmp/keep_dates.txt

# 4. Repaint WINDOW_START..TODAY with weekly dead/sparse decisions.
echo "Repainting ${WINDOW_START} -> ${TODAY}..."
cur=$(date -j -f "%Y-%m-%d %H:%M:%S" "$WINDOW_START 12:00:00" +%s)
end=$(date -j -f "%Y-%m-%d %H:%M:%S" "$TODAY 12:00:00" +%s)

cur_week=""
week_freq=$FREQ_NORMAL
week_dead=0
dead_weeks=0
sparse_weeks=0
total_new=0
active_days=0
window_days=0
burst_days=0

while [ "$cur" -le "$end" ]; do
  day=$(date -r "$cur" +%Y-%m-%d)
  wk=$(date -r "$cur" +%G-%V)
  window_days=$(( window_days + 1 ))

  if [ "$wk" != "$cur_week" ]; then
    cur_week="$wk"
    r=$(( RANDOM % 100 ))
    if (( r < DEAD_WEEK_PCT )); then
      week_dead=1; week_freq=0; dead_weeks=$(( dead_weeks + 1 ))
    elif (( r < DEAD_WEEK_PCT + SPARSE_WEEK_PCT )); then
      week_dead=0; week_freq=$FREQ_SPARSE; sparse_weeks=$(( sparse_weeks + 1 ))
    else
      week_dead=0; week_freq=$FREQ_NORMAL
    fi
  fi

  if [ "$week_dead" = 0 ] && (( RANDOM % 100 < week_freq )); then
    active_days=$(( active_days + 1 ))
    if (( RANDOM % 100 < BURST_DAY_PCT )); then
      n=$(( RANDOM % 16 + 15 )); burst_days=$(( burst_days + 1 ))
    else
      n=$(( RANDOM % MAXC + 1 ))
    fi
    for ((c=1; c<=n; c++)); do mkcommit "$day"; done
    total_new=$(( total_new + n ))
  fi

  cur=$(( cur + 86400 ))
done

echo ""
echo "Window ${WINDOW_START}..${TODAY}:"
echo "  ${active_days}/${window_days} active days (~$(( active_days * 100 / window_days ))%), ${total_new} commits"
echo "  ${dead_weeks} dead week(s), ${sparse_weeks} sparse week(s), ${burst_days} burst day(s)"
echo "Total history now: $(git rev-list --count HEAD) commits."
echo ""
echo "Review, then adopt with:"
echo "  git branch -M repaint main && git push --force-with-lease origin main"
