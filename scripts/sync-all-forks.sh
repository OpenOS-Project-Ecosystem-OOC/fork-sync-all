#!/usr/bin/env bash
#
# Syncs all branches of every fork owned by GITHUB_OWNER with their upstream.
# Requires: GH_TOKEN (PAT with public_repo scope), GITHUB_OWNER, curl, jq.
#
set -uo pipefail

: "${GH_TOKEN:?GH_TOKEN is required}"
: "${GITHUB_OWNER:?GITHUB_OWNER is required}"

API="https://api.github.com"
PER_PAGE=100
HEADER_FILE=$(mktemp)
trap 'rm -f "$HEADER_FILE"' EXIT

# Counters
synced=0
failed=0
skipped=0

# ── helpers ──────────────────────────────────────────────────────────────────

gh_api() {
  local method="$1" url="$2"
  shift 2

  local max_retries=3
  local attempt=0

  while true; do
    local response http_code body

    response=$(curl -s -w "\n%{http_code}" \
      -X "$method" \
      -H "Authorization: token ${GH_TOKEN}" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      -D "$HEADER_FILE" \
      "$@" \
      "$url" 2>/dev/null) || true

    http_code=$(echo "$response" | tail -1)
    body=$(echo "$response" | sed '$d')

    if [[ "$http_code" == "403" || "$http_code" == "429" ]]; then
      (( attempt++ ))
      if (( attempt > max_retries )); then
        echo "$body"
        return 1
      fi

      local reset
      reset=$(grep -i "x-ratelimit-reset:" "$HEADER_FILE" 2>/dev/null | tr -d '\r' | awk '{print $2}')
      if [[ -n "$reset" && "$reset" =~ ^[0-9]+$ ]]; then
        local now wait_seconds
        now=$(date +%s)
        wait_seconds=$(( reset - now + 5 ))
        if (( wait_seconds > 0 && wait_seconds < 3700 )); then
          echo "  Rate limited. Waiting ${wait_seconds}s until reset..." >&2
          sleep "$wait_seconds"
          continue
        fi
      fi
      echo "  Rate limited. Backing off 60s..." >&2
      sleep 60
      continue

    elif [[ "$http_code" == "404" || "$http_code" == "409" || "$http_code" == "422" ]]; then
      echo "$body"
      return 1

    elif [[ "$http_code" -ge 500 ]]; then
      (( attempt++ ))
      if (( attempt > max_retries )); then
        echo "$body"
        return 1
      fi
      echo "  Server error ($http_code). Retrying in 10s..." >&2
      sleep 10
      continue
    fi

    echo "$body"
    return 0
  done
}

get_all_forks() {
  local page=1
  while true; do
    local result
    result=$(gh_api GET "${API}/users/${GITHUB_OWNER}/repos?type=forks&per_page=${PER_PAGE}&page=${page}&sort=full_name") || break

    local count
    count=$(echo "$result" | jq 'length' 2>/dev/null) || break

    if [[ -z "$count" || "$count" == "0" || "$count" == "null" ]]; then
      break
    fi

    echo "$result" | jq -r '.[] | .full_name' 2>/dev/null
    (( page++ ))
  done
}

get_repo_info() {
  local repo="$1"
  gh_api GET "${API}/repos/${repo}" 2>/dev/null
}

get_branches() {
  local repo="$1"
  local page=1
  while true; do
    local result
    result=$(gh_api GET "${API}/repos/${repo}/branches?per_page=${PER_PAGE}&page=${page}") || break

    local count
    count=$(echo "$result" | jq 'length' 2>/dev/null) || break

    if [[ -z "$count" || "$count" == "0" || "$count" == "null" ]]; then
      break
    fi

    echo "$result" | jq -r '.[].name' 2>/dev/null
    (( page++ ))
  done
}

sync_default_branch() {
  local fork="$1" branch="$2"

  local result
  result=$(gh_api POST "${API}/repos/${fork}/merge-upstream" \
    -H "Content-Type: application/json" \
    -d "{\"branch\":\"${branch}\"}") || {
    local msg
    msg=$(echo "$result" | jq -r '.message // empty' 2>/dev/null)
    echo "    failed (default): ${msg:-unknown error}"
    return 1
  }

  local merge_type
  merge_type=$(echo "$result" | jq -r '.merge_type // empty' 2>/dev/null)

  if [[ "$merge_type" == "fast-forward" || "$merge_type" == "none" || "$merge_type" == "merge" ]]; then
    return 0
  fi

  local message
  message=$(echo "$result" | jq -r '.message // empty' 2>/dev/null)
  if [[ -n "$message" && "$message" != "null" ]]; then
    echo "    failed (default): ${message}"
    return 1
  fi

  return 0
}

sync_non_default_branch() {
  local fork="$1" branch="$2" upstream="$3"

  # Check if upstream has this branch
  local upstream_info
  upstream_info=$(gh_api GET "${API}/repos/${upstream}/branches/${branch}") || return 2

  local upstream_sha
  upstream_sha=$(echo "$upstream_info" | jq -r '.commit.sha // empty' 2>/dev/null)

  if [[ -z "$upstream_sha" || "$upstream_sha" == "null" ]]; then
    return 2
  fi

  # Compare
  local compare
  compare=$(gh_api GET "${API}/repos/${fork}/compare/${branch}...${upstream}:${branch}") || {
    echo "    failed (compare): could not compare ${branch}"
    return 1
  }

  local status_val
  status_val=$(echo "$compare" | jq -r '.status // empty' 2>/dev/null)

  if [[ "$status_val" == "identical" || "$status_val" == "behind" ]]; then
    return 0
  fi

  # Merge
  local merge_result
  merge_result=$(gh_api POST "${API}/repos/${fork}/merges" \
    -H "Content-Type: application/json" \
    -d "{\"base\":\"${branch}\",\"head\":\"${upstream_sha}\",\"commit_message\":\"Sync branch ${branch} from upstream ${upstream}\"}") || {
    local msg
    msg=$(echo "$merge_result" | jq -r '.message // empty' 2>/dev/null)
    echo "    failed (merge): ${msg:-unknown error}"
    return 1
  }

  local merge_sha
  merge_sha=$(echo "$merge_result" | jq -r '.sha // empty' 2>/dev/null)

  if [[ -n "$merge_sha" && "$merge_sha" != "null" ]]; then
    return 0
  fi

  local merge_msg
  merge_msg=$(echo "$merge_result" | jq -r '.message // empty' 2>/dev/null)
  if [[ -n "$merge_msg" && "$merge_msg" != "null" ]]; then
    echo "    failed (merge): ${merge_msg}"
    return 1
  fi

  return 0
}

# ── main ─────────────────────────────────────────────────────────────────────

echo "Fetching all forks for ${GITHUB_OWNER}..."
mapfile -t forks < <(get_all_forks)
echo "Found ${#forks[@]} forks."
echo ""

for fork in "${forks[@]}"; do
  [[ -z "$fork" ]] && continue

  echo "Syncing ${fork}..."

  repo_info=$(get_repo_info "$fork") || {
    echo "  Could not fetch repo info, skipping."
    (( skipped++ ))
    continue
  }

  upstream=$(echo "$repo_info" | jq -r '.parent.full_name // empty' 2>/dev/null)
  default_branch=$(echo "$repo_info" | jq -r '.default_branch // empty' 2>/dev/null)

  if [[ -z "$upstream" || "$upstream" == "null" ]]; then
    echo "  No upstream found, skipping."
    (( skipped++ ))
    continue
  fi

  mapfile -t branches < <(get_branches "$fork")

  if [[ ${#branches[@]} -eq 0 ]]; then
    echo "  No branches found, skipping."
    (( skipped++ ))
    continue
  fi

  repo_ok=true
  for branch in "${branches[@]}"; do
    [[ -z "$branch" ]] && continue

    rc=0
    if [[ "$branch" == "$default_branch" ]]; then
      sync_default_branch "$fork" "$branch" || rc=$?
    else
      sync_non_default_branch "$fork" "$branch" "$upstream" || rc=$?
    fi

    if [[ "$rc" -eq 0 ]]; then
      (( synced++ ))
    elif [[ "$rc" -eq 2 ]]; then
      :
    else
      (( failed++ ))
      repo_ok=false
    fi
  done

  if $repo_ok; then
    echo "  done."
  fi
done

echo ""
echo "========================================"
echo "  Sync complete"
echo "  Branches synced:   ${synced}"
echo "  Branches failed:   ${failed}"
echo "  Repos skipped:     ${skipped}"
echo "========================================"

# Exit 0 even if some branches failed — individual failures are expected
exit 0
