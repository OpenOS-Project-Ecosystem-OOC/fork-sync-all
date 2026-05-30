#!/usr/bin/env bash
#
# Polls the GitHub core rate limit and dispatches a target workflow once
# quota recovers above a configurable threshold.
#
# The poll interval is recalculated on every iteration based on the live
# reset epoch returned by the API — so if the reset slides (because another
# workflow fires and exhausts quota again), the sleep adjusts automatically.
#
# Algorithm:
#   1. Fetch /rate_limit.
#   2. If remaining >= MIN_QUOTA  → dispatch and exit 0.
#   3. Compute sleep = max(MIN_POLL_SEC, reset_epoch - now + BUFFER_SEC).
#      Cap at MAX_POLL_SEC so we never sleep past a reset without checking.
#   4. Sleep, then go to 1.
#   5. After TIMEOUT_MIN minutes total, exit 1.
#
# Required env vars:
#   GH_TOKEN          — token with repo + workflow scopes
#   TARGET_WORKFLOW   — workflow filename, e.g. sync-template.yml
#
# Optional env vars:
#   GITHUB_OWNER      — default: Interested-Deving-1896
#   GITHUB_REPO       — default: fork-sync-all
#   TARGET_REF        — git ref to dispatch on (default: main)
#   TARGET_INPUTS     — JSON object of workflow inputs (default: {})
#   MIN_QUOTA         — minimum remaining calls before dispatching (default: 2000)
#   BUFFER_SEC        — extra seconds to wait after reset epoch (default: 45)
#   MIN_POLL_SEC      — minimum sleep between polls in seconds (default: 30)
#   MAX_POLL_SEC      — maximum sleep between polls in seconds (default: 300)
#   TIMEOUT_MIN       — give up after this many minutes (default: 180)
#   DRY_RUN           — if "true", print what would happen without dispatching

set -uo pipefail

: "${GH_TOKEN:?GH_TOKEN is required}"
: "${TARGET_WORKFLOW:?TARGET_WORKFLOW is required (e.g. sync-template.yml)}"

OWNER="${GITHUB_OWNER:-Interested-Deving-1896}"
REPO="${GITHUB_REPO:-fork-sync-all}"
TARGET_REF="${TARGET_REF:-main}"
TARGET_INPUTS="${TARGET_INPUTS:-{}}"
MIN_QUOTA="${MIN_QUOTA:-2000}"
BUFFER_SEC="${BUFFER_SEC:-45}"
MIN_POLL_SEC="${MIN_POLL_SEC:-30}"
MAX_POLL_SEC="${MAX_POLL_SEC:-300}"
TIMEOUT_MIN="${TIMEOUT_MIN:-180}"
DRY_RUN="${DRY_RUN:-false}"

GH_API="https://api.github.com"
SUMMARY_FILE="${GITHUB_STEP_SUMMARY:-}"

info()  { echo "[quota-wait] $(date -u '+%H:%M:%S UTC')  $*"; }
warn()  { echo "[quota-wait] $(date -u '+%H:%M:%S UTC') ⚠️  $*" >&2; }

summary_append() {
  [[ -n "$SUMMARY_FILE" ]] && echo "$1" >> "$SUMMARY_FILE"
}

# ── Rate limit fetch ──────────────────────────────────────────────────────────

# Outputs: "<remaining> <reset_epoch>"
fetch_quota() {
  local raw
  raw=$(curl -sf \
    -H "Authorization: token ${GH_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    "${GH_API}/rate_limit") || { warn "rate_limit fetch failed"; echo "0 0"; return; }

  python3 -c "
import sys, json
d = json.loads(sys.argv[1])
core = d.get('resources', {}).get('core', {})
print(core.get('remaining', 0), core.get('reset', 0))
" "$raw"
}

# ── Dispatch ──────────────────────────────────────────────────────────────────

dispatch_workflow() {
  local payload
  payload=$(python3 -c "
import sys, json
ref    = sys.argv[1]
inputs = json.loads(sys.argv[2])
print(json.dumps({'ref': ref, 'inputs': inputs}))
" "$TARGET_REF" "$TARGET_INPUTS")

  local http_status
  http_status=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST \
    -H "Authorization: token ${GH_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "${GH_API}/repos/${OWNER}/${REPO}/actions/workflows/${TARGET_WORKFLOW}/dispatches")

  echo "$http_status"
}

# ── Main loop ─────────────────────────────────────────────────────────────────

START_EPOCH=$(date +%s)
TIMEOUT_SEC=$(( TIMEOUT_MIN * 60 ))
DEADLINE=$(( START_EPOCH + TIMEOUT_SEC ))

info "Waiting for GitHub core quota >= ${MIN_QUOTA}"
info "Target: ${OWNER}/${REPO} @ ${TARGET_REF} → ${TARGET_WORKFLOW}"
info "Inputs: ${TARGET_INPUTS}"
info "Timeout: ${TIMEOUT_MIN}m  buffer: ${BUFFER_SEC}s  poll: ${MIN_POLL_SEC}–${MAX_POLL_SEC}s"
info ""

summary_append "## Quota Wait + Trigger"
summary_append ""
summary_append "| Time (UTC) | Remaining | Reset at | Sleep |"
summary_append "|---|---|---|---|"

attempt=0
while true; do
  (( attempt++ )) || true
  NOW=$(date +%s)

  # Timeout guard
  if [[ "$NOW" -ge "$DEADLINE" ]]; then
    warn "Timed out after ${TIMEOUT_MIN}m — giving up."
    summary_append ""
    summary_append "> ❌ Timed out after ${TIMEOUT_MIN}m without reaching quota threshold."
    exit 1
  fi

  # Fetch current quota
  read -r remaining reset_epoch < <(fetch_quota)
  remaining="${remaining:-0}"
  reset_epoch="${reset_epoch:-0}"

  # Human-readable reset time
  reset_str=$(python3 -c "
from datetime import datetime, timezone
print(datetime.fromtimestamp(${reset_epoch}, tz=timezone.utc).strftime('%H:%M:%S UTC'))
" 2>/dev/null || echo "${reset_epoch}")

  # Compute adaptive sleep:
  #   - If reset is in the future: sleep until reset + BUFFER_SEC
  #   - Cap between MIN_POLL_SEC and MAX_POLL_SEC
  reset_in=$(( reset_epoch - NOW ))
  if [[ "$reset_in" -gt 0 ]]; then
    raw_sleep=$(( reset_in + BUFFER_SEC ))
  else
    raw_sleep="$MIN_POLL_SEC"
  fi
  sleep_sec=$(( raw_sleep < MIN_POLL_SEC ? MIN_POLL_SEC : raw_sleep ))
  sleep_sec=$(( sleep_sec > MAX_POLL_SEC ? MAX_POLL_SEC : sleep_sec ))

  info "Attempt #${attempt}: remaining=${remaining}  reset=${reset_str}  sleep=${sleep_sec}s"
  summary_append "| $(date -u '+%H:%M:%S') | ${remaining} | ${reset_str} | ${sleep_sec}s |"

  if [[ "$remaining" -ge "$MIN_QUOTA" ]]; then
    info "Quota sufficient (${remaining} >= ${MIN_QUOTA}) — dispatching ${TARGET_WORKFLOW}..."

    if [[ "$DRY_RUN" == "true" ]]; then
      info "DRY RUN — would dispatch ${TARGET_WORKFLOW} with inputs: ${TARGET_INPUTS}"
      summary_append ""
      summary_append "> 🔍 Dry run — dispatch skipped. Would have triggered \`${TARGET_WORKFLOW}\`."
      exit 0
    fi

    http_status=$(dispatch_workflow)

    if [[ "$http_status" == "204" ]]; then
      info "✅ Dispatched ${TARGET_WORKFLOW} (HTTP 204)"
      summary_append ""
      summary_append "> ✅ Dispatched \`${TARGET_WORKFLOW}\` after ${attempt} poll(s). Quota at dispatch: **${remaining}**."
      exit 0
    else
      warn "Dispatch returned HTTP ${http_status} — will retry next poll"
      summary_append ""
      summary_append "> ⚠️  Dispatch attempt returned HTTP ${http_status} — retrying."
    fi
  fi

  info "  -> sleeping ${sleep_sec}s (reset in ${reset_in}s + ${BUFFER_SEC}s buffer)"
  sleep "$sleep_sec"
done
