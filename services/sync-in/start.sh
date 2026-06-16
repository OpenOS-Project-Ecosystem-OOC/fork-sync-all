#!/usr/bin/env bash
#
# services/sync-in/start.sh — start a Sync-in server inside the devcontainer
#
# Locates the sync-in-server binary (installed via the devcontainer feature or
# available on PATH), writes a minimal config, and starts the server on
# SYNC_IN_PORT (default: 3284).
#
# Environment variables (all optional — sensible defaults are used):
#   SYNC_IN_PORT         — port to listen on (default: 3284)
#   SYNC_IN_DATA_DIR     — data directory (default: ~/.local/share/sync-in)
#   SYNC_IN_ADMIN_TOKEN  — admin API token; generated and printed if absent
#   SYNC_IN_LOG_LEVEL    — log level: debug|info|warn|error (default: info)

set -uo pipefail

PORT="${SYNC_IN_PORT:-3284}"
DATA_DIR="${SYNC_IN_DATA_DIR:-${HOME}/.local/share/sync-in}"
LOG_LEVEL="${SYNC_IN_LOG_LEVEL:-info}"

# ── Locate binary ─────────────────────────────────────────────────────────────
SYNC_IN_BIN=""
for candidate in \
    "$(command -v sync-in-server 2>/dev/null)" \
    "$(command -v sync-in 2>/dev/null)" \
    "${HOME}/.local/bin/sync-in-server" \
    "/usr/local/bin/sync-in-server"; do
  [[ -x "$candidate" ]] && { SYNC_IN_BIN="$candidate"; break; }
done

if [[ -z "$SYNC_IN_BIN" ]]; then
  echo "[sync-in] sync-in-server binary not found." >&2
  echo "[sync-in] Install it from https://github.com/Sync-in/server/releases" >&2
  echo "[sync-in] or run: scripts/sync-in-server.sh with ACTION=install" >&2
  exit 1
fi

# ── Ensure data directory ─────────────────────────────────────────────────────
mkdir -p "${DATA_DIR}"

# ── Admin token ───────────────────────────────────────────────────────────────
TOKEN_FILE="${DATA_DIR}/.admin_token"
if [[ -n "${SYNC_IN_ADMIN_TOKEN:-}" ]]; then
  echo "$SYNC_IN_ADMIN_TOKEN" > "$TOKEN_FILE"
  chmod 600 "$TOKEN_FILE"
elif [[ -f "$TOKEN_FILE" ]]; then
  SYNC_IN_ADMIN_TOKEN=$(cat "$TOKEN_FILE")
else
  SYNC_IN_ADMIN_TOKEN=$(python3 -c "import secrets; print(secrets.token_hex(32))" 2>/dev/null \
    || openssl rand -hex 32 2>/dev/null \
    || head -c 32 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 32)
  echo "$SYNC_IN_ADMIN_TOKEN" > "$TOKEN_FILE"
  chmod 600 "$TOKEN_FILE"
  echo "[sync-in] Generated admin token → ${TOKEN_FILE}" >&2
fi

echo "[sync-in] Starting on port ${PORT} (data: ${DATA_DIR})" >&2
echo "[sync-in] Admin token: ${SYNC_IN_ADMIN_TOKEN}" >&2
echo "[sync-in] Server URL:  http://localhost:${PORT}" >&2

# ── Start server ──────────────────────────────────────────────────────────────
exec "$SYNC_IN_BIN" \
  --port "${PORT}" \
  --data-dir "${DATA_DIR}" \
  --admin-token "${SYNC_IN_ADMIN_TOKEN}" \
  --log-level "${LOG_LEVEL}"
