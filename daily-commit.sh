#!/usr/bin/env bash
#
# daily-commit.sh — local (macOS) forward job.
#
# Mirrors the cloud workflow's ~80% logic so the contribution graph keeps
# filling from your Mac while GitHub Actions is billing-locked. Scheduled by
# ~/Library/LaunchAgents/com.yeshsanchez.keepgreen.plist (runs once a day).
#
# Env overrides (handy for testing):
#   FREQUENCY=100 MAX_COMMITS=1 ./daily-commit.sh   # force exactly one commit
#
# Note: no `set -e` on purpose — bash (( )) arithmetic returns non-zero when it
# evaluates to 0, which would kill an -e script mid-roll.

set -uo pipefail
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

REPO="/Users/yesh/programming stuffs/auto-commit"
FREQUENCY="${FREQUENCY:-67}"          # % chance of activity on a normal day (60-70 range)
MAX_COMMITS="${MAX_COMMITS:-6}"       # max commits on a normal active day (shading)
DEAD_WEEK_PCT="${DEAD_WEEK_PCT:-10}"  # % of ISO-weeks that go fully dead (natural gaps)
BURST_PCT="${BURST_PCT:-6}"           # % of active days that spike to a 15-30 burst

cd "$REPO" || { echo "cannot cd to repo"; exit 1; }

echo "[$(date '+%Y-%m-%d %H:%M:%S')] run start (freq=${FREQUENCY} max=${MAX_COMMITS})"

# Stay in sync with the remote (harmless if there's nothing to pull).
git pull --rebase --autostash origin main >/dev/null 2>&1 || true

# Dead weeks: deterministically mark ~DEAD_WEEK_PCT% of ISO-weeks as fully quiet
# so the graph has vacation-style gaps instead of a solid wall. Hashing year+week
# keeps the whole week consistently dead across the week's daily runs.
weekkey="$(date '+%G-%V')"
weekroll=$(( $(printf '%s' "$weekkey" | cksum | cut -d' ' -f1) % 100 ))
if (( weekroll < DEAD_WEEK_PCT )); then
  echo "  dead week ($weekkey) — skip"
  exit 0
fi

# ~ (100 - FREQUENCY)% of remaining days: do nothing, so weeks aren't fully packed.
if (( RANDOM % 100 >= FREQUENCY )); then
  echo "  skip day (no commits)"
  exit 0
fi

# Most active days get 1-MAX commits; a rare day spikes to a 15-30 burst.
if (( RANDOM % 100 < BURST_PCT )); then
  n=$(( RANDOM % 16 + 15 ))
  echo "  BURST day: making $n commit(s)"
else
  n=$(( RANDOM % MAX_COMMITS + 1 ))
  echo "  making $n commit(s)"
fi
for ((c=1; c<=n; c++)); do
  ts="$(date '+%Y-%m-%dT%H:%M:%S')"
  echo "$ts keepgreen $RANDOM$RANDOM" >> activity.log
  git add activity.log
  git commit -q -m "chore: activity $(date '+%F') (#$c)"
  sleep 1
done

# Push using the gh token explicitly — most reliable under launchd, where the
# git credential helper can be flaky in a non-login session.
TOKEN="$(gh auth token 2>/dev/null || true)"
if [ -n "$TOKEN" ]; then
  if git push "https://x-access-token:${TOKEN}@github.com/yeshsanchez/sniffle-green.git" HEAD:main >/dev/null 2>&1; then
    echo "  pushed"
  else
    echo "  push FAILED"; exit 1
  fi
else
  git push >/dev/null 2>&1 && echo "  pushed" || { echo "  push FAILED (no token)"; exit 1; }
fi
