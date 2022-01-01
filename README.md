# keep-green

Keeps a GitHub contribution graph looking busy — green squares on ~80% of days
with varied shading, not a perfect wall. Two moving parts:

- **`backfill.sh`** — run once, locally, to paint the *past* year of history.
- **`.github/workflows/keepgreen.yml`** — a daily job that runs in GitHub's
  cloud to keep the graph going *forward* (works even when your laptop is off).

## How contributions actually count

A commit turns a square green when **all** of these are true:

1. The commit's author email is verified on your GitHub account.
2. The commit is on the repo's **default branch** (`main` here).
3. The repo is **not a fork**.

This repo is set up for account **`yeshsanchez`** (id `104058809`) using email
`yeshuaaeons@gmail.com`. That email is already verified on the account, so the
commits count — including the ones the cloud job makes (the *pusher* being the
GitHub Actions bot doesn't matter; only the commit's author email does).

> If squares somehow don't turn green, the bulletproof fallback is GitHub's
> noreply email: `104058809+yeshsanchez@users.noreply.github.com`. Swap it into
> `backfill.sh` and `keepgreen.yml` and you're guaranteed attribution.

## First-time setup

```sh
# 1. Fill in the past year (~80% of days, up to 6 commits/day)
./backfill.sh

# 2. Create the public repo and push everything
gh repo create keep-green --public --source=. --remote=origin --push
```

The daily job starts running automatically once the workflow file is on GitHub
**and GitHub Actions is enabled on the account**.

> ⚠️ Actions is currently **billing-locked** on this account, so the cloud job
> won't run until that's cleared at <https://github.com/settings/billing>
> (Actions is free on public repos, so this is usually a stale payment method or
> unpaid invoice, not real charges). Until then, the local scheduler below keeps
> the graph going.

## Forward job: local scheduler (macOS)

`daily-commit.sh` is the same ~80% logic driven from your Mac via `launchd`,
independent of GitHub Actions. Files:

- `daily-commit.sh` — rolls the dice daily, commits, and pushes.
- `launchd/com.yeshsanchez.keepgreen.plist` — schedules it (11:30 local daily;
  runs on next wake if the Mac was asleep). A copy is installed at
  `~/Library/LaunchAgents/com.yeshsanchez.keepgreen.plist`.

```sh
# Install / reload the scheduler
cp launchd/com.yeshsanchez.keepgreen.plist ~/Library/LaunchAgents/
launchctl bootout  gui/$(id -u)/com.yeshsanchez.keepgreen 2>/dev/null || true
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.yeshsanchez.keepgreen.plist

# Run it by hand any time (force exactly one commit for a quick test)
FREQUENCY=100 MAX_COMMITS=1 ./daily-commit.sh

# See what it did
tail -f keepgreen.local.log
```

The Mac must be on (or asleep, not shut down) around the scheduled time. If you
later clear the Actions billing lock, you can run both — just expect more
commits on days they both fire.

## Tuning the look

- **Frequency (how many days are green):** the `80` in `backfill.sh` args and the
  `FREQUENCY` env in `keepgreen.yml`. Lower = more gaps.
- **Shade intensity (darkness):** `MAX_COMMITS`. GitHub shades a square relative
  to your busiest day, so a higher max gives a wider light→dark range.
- **Time of day:** `keepgreen.yml`'s `cron` (UTC). Change `17 3 * * *`.

## Pausing / stopping

- **Pause the local scheduler:** `launchctl bootout gui/$(id -u)/com.yeshsanchez.keepgreen`
  (re-run the `bootstrap` line to resume).
- **Pause the cloud job:** Actions tab → *keep-green* → `•••` → **Disable workflow**.
- **Stop entirely:** delete the repo. Backfilled squares vanish with it since the
  commits live only here.

## Re-running backfill

`backfill.sh` appends new commits each time you run it; it won't remove old ones.
To start the history over, delete the repo (or `rm activity.log` and reset the
branch) before re-running.
