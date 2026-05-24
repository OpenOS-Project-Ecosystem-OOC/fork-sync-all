# Operational Reference: GitHub Actions Limits & Quotas

This document covers the GitHub Actions limits that affect fork-sync-all,
what consumes them, how to detect exhaustion, and how to recover.

---

## GitHub API Rate Limit

**Quota:** 5,000 requests/hour per authenticated user token.

**Resets:** Top of every hour (rolling window).

**What consumes it:**

| Operation | Cost |
|---|---|
| `gh api` / REST API call | 1 req |
| Listing workflow runs | 1 req per page |
| Cancelling a run | 1 req |
| Triggering a workflow dispatch | 1 req |
| Checking job status | 1 req per job |
| GraphQL query | Separate quota (5,000 points/hr) — unaffected by REST exhaustion |

**How fork-sync-all burns it:**
- Every `workflow_run` trigger fires a new run, which itself may call the API
- `rate-limit-rerun.yml` (formerly hourly) scans all recent failed runs
- `stuck-run-detector.yml` (formerly hourly) lists all queued/in-progress runs
- `translate-readmes.yml` was triggering after 10 workflows — each trigger
  consumed dozens of API calls for the org scan

**Detecting exhaustion:**
```bash
gh api rate_limit --jq '.resources.core | "remaining: \(.remaining)/\(.limit)  resets: \(.reset | todate)"'
```

**Recovery:** Wait until the top of the next hour. GraphQL remains available
during REST exhaustion and can be used for read-only queries.

---

## GitHub Actions Runner Minutes

**Free tier:** 2,000 minutes/month (resets 1st of each month).

**Paid:** Billed per minute beyond the free tier; Linux runners cost 1×,
Windows 2×, macOS 10×. All workflows in this repo use `ubuntu-latest` (Linux, 1×).

**What counts against the monthly quota:**

- Every job that runs on `ubuntu-latest` (GitHub-hosted runner)
- Time is measured from job start to job end, rounded up to the nearest minute
- Jobs that are *queued* but never start do **not** consume minutes
- Jobs that exit immediately (e.g. `if:` condition is false at the job level)
  still consume ~1 minute for runner provisioning

**What does NOT count:**

- `workflow_dispatch` triggers that are never clicked
- Runs that are cancelled before a job starts
- Skipped jobs (`if:` evaluated to false before the runner is assigned)
- Self-hosted runners (zero cost regardless of usage)

**How fork-sync-all was burning minutes:**

Before the May 2026 fixes, the following patterns caused rapid exhaustion:

1. `mirror-orgs-watchdog` fired after every mirror completion (5 workflows ×
   hourly cadence = ~120 runs/day), each consuming ~1 min even on success
2. `update-readmes` triggered after 7 workflows including high-frequency syncs
3. `inject-badges` triggered after mirror workflows that run hourly
4. `stuck-run-detector` and `rate-limit-rerun` ran hourly as meta-workflows,
   each consuming minutes to manage other workflows
5. `workflow_run` listeners fired on every `completed` event (success, failure,
   cancelled) — not just on the outcomes they actually needed

**Detecting exhaustion:**

Symptoms (in order of appearance):
1. `ubuntu-latest` jobs queue but never start
2. No in-progress runs despite many queued
3. Runs queued for hours with 0 runners active
4. Billing API returns 404 (needs `user` OAuth scope — check web UI instead)

Check via GitHub web UI: **Settings → Billing → Actions**.

**Recovery:** Wait until the 1st of the next month. In the meantime:
- Cancel all queued runs (they will never start)
- Do not push commits that trigger new workflow runs
- Use `workflow_dispatch` manually only for critical operations

---

## Concurrency Groups & Stuck Runs

**How they work:** A concurrency group allows only one run at a time for a
given key. If `cancel-in-progress: false`, a second run queues behind the
first. If the first run never finishes (e.g. runner minutes exhausted mid-job),
the queued run is permanently stuck.

**The cascade pattern:**
1. Runner minutes exhaust mid-job → job hangs in `in_progress`
2. Next scheduled run queues behind it (`cancel-in-progress: false`)
3. The in-progress run never finishes → queue grows indefinitely
4. API calls to cancel are themselves rate-limited → nothing can be cleared

**Fix applied (May 2026):** All workflows in this repo now use
`cancel-in-progress: true`. A newer run always supersedes a queued one.

**Detecting stuck runs:**
```bash
gh api "repos/Interested-Deving-1896/fork-sync-all/actions/runs?per_page=100" \
  --jq '[.workflow_runs[] | select(.status == "queued")] | length'
```

**Bulk cancel (requires API quota):**
```bash
gh api "repos/Interested-Deving-1896/fork-sync-all/actions/runs?per_page=100" \
  --jq '[.workflow_runs[] | select(.status == "queued") | .id] | .[]' | \
  xargs -I{} gh api -X POST "repos/Interested-Deving-1896/fork-sync-all/actions/runs/{}/cancel"
```

---

## workflow_run Trigger Cost Model

`workflow_run` fires on every `completed` event regardless of conclusion
(success, failure, cancelled, skipped). A listener that only needs to act
on failures still consumes a runner minute for every successful upstream run
unless gated at the job level.

**Pattern used in this repo:**

```yaml
# For workflows that act on upstream SUCCESS (content processors):
jobs:
  my-job:
    if: |
      github.event_name != 'workflow_run' ||
      github.event.workflow_run.conclusion == 'success'

# For workflows that act on upstream FAILURE (watchdogs/retriers):
jobs:
  retry:
    if: |
      github.event_name == 'workflow_dispatch' ||
      github.event.workflow_run.conclusion == 'failure'
```

This exits immediately (no runner cost) when the conclusion doesn't match,
while keeping the trigger automatic.

---

## Current Workflow Schedule Summary

Workflows that run on a schedule and their cadence after May 2026 fixes:

| Workflow | Schedule | Notes |
|---|---|---|
| `mirror-to-osp` | Hourly `:00` | Core mirror |
| `mirror-releases` | Hourly `:00` | |
| `mirror-artifacts` | Hourly `:08` | |
| `mirror-osp-to-gitlab` | Hourly `:24` | |
| `upstream-prs` | Hourly `:32` | |
| `upstream-commits` | Hourly `:40` | |
| `reconcile-org-refs` | Hourly `:56` | |
| `sync-pieroproietti-forks` | Hourly `:05` | |
| `notify-poller` | Every 30 min | |
| `stuck-run-detector` | Every 6h `:20` | Reduced from hourly |
| `rate-limit-rerun` | Every 6h `:12` | Reduced from hourly |
| `rate-limit-budget-report` | Daily 11:00 | Reduced from every 2h |
| `update-readmes` | Daily 10:20 | |
| `create-readmes` | Daily 10:30 | |
| `inject-badges` | Daily 10:40 | |
| `translate-readmes` | Daily 10:50 | |
| `sync-forks` | Daily 11:30 | |
| `mirror-orgs-full` | Daily 10:00 | |
| `lts-readmes` | Monthly 1st | |

Hourly workflows are the primary minute consumers. At ~1 min/run, 7 hourly
workflows = ~168 min/day = ~5,040 min/month — well over the 2,000 min free
tier. **A paid plan or self-hosted runner is required for this repo's workload.**

---

## Self-Hosted Runner Setup (Recommended)

To eliminate the monthly minute cap entirely, add a self-hosted runner:

1. Go to **Settings → Actions → Runners → New self-hosted runner**
2. Follow the setup instructions for your host OS
3. Change workflow `runs-on` from `ubuntu-latest` to `self-hosted` (or add
   a label and use that label)

Self-hosted runners have no minute cost and no concurrent job cap beyond
what the host machine can handle.

---

## Quick Reference: Limit Reset Times

| Limit | Resets |
|---|---|
| GitHub API rate limit (REST) | Top of every hour |
| GitHub API rate limit (GraphQL) | Top of every hour (separate quota) |
| GitHub Actions minutes | 1st of each month |
| GitHub Actions concurrent jobs (free) | N/A — blocked by minute exhaustion |
