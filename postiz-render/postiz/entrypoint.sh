#!/bin/bash
# -----------------------------------------------------------------------------
# Render entrypoint for Postiz.
# Wraps the official image's start command (`nginx && pnpm run pm2`) with the
# environment wiring Render needs. Everything here is idempotent and safe to
# re-run on every container start.
# -----------------------------------------------------------------------------
set -euo pipefail

log() { printf '[render-entrypoint] %s\n' "$*"; }

cd /app

# -----------------------------------------------------------------------------
# 1) Public URL
#    Priority: MAIN_URL (custom domain) > FRONTEND_URL > RENDER_EXTERNAL_URL
#    RENDER_EXTERNAL_URL is injected by Render: https://<service-name>.onrender.com
# -----------------------------------------------------------------------------
PUBLIC_URL="${MAIN_URL:-${FRONTEND_URL:-${RENDER_EXTERNAL_URL:-}}}"
PUBLIC_URL="${PUBLIC_URL%/}"   # strip trailing slash
if [[ -z "${PUBLIC_URL}" ]]; then
  log "ERROR: cannot determine the public URL."
  log "       Set MAIN_URL=https://your-domain.com in the Render dashboard (Environment tab)."
  exit 1
fi
export MAIN_URL="${MAIN_URL:-${PUBLIC_URL}}"
export FRONTEND_URL="${FRONTEND_URL:-${PUBLIC_URL}}"
export NEXT_PUBLIC_BACKEND_URL="${NEXT_PUBLIC_BACKEND_URL:-${PUBLIC_URL}/api}"
export BACKEND_INTERNAL_URL="${BACKEND_INTERNAL_URL:-http://localhost:3000}"

# -----------------------------------------------------------------------------
# 2) Temporal address (TEMPORAL_HOST comes from render.yaml: fromService -> host)
# -----------------------------------------------------------------------------
if [[ -z "${TEMPORAL_ADDRESS:-}" && -n "${TEMPORAL_HOST:-}" ]]; then
  export TEMPORAL_ADDRESS="${TEMPORAL_HOST}:${TEMPORAL_PORT:-7233}"
fi
export TEMPORAL_ADDRESS="${TEMPORAL_ADDRESS:-localhost:7233}"
export TEMPORAL_NAMESPACE="${TEMPORAL_NAMESPACE:-default}"

# -----------------------------------------------------------------------------
# 3) Ports
#    Render routes public traffic to $PORT (5000 = nginx, see render.yaml).
#    The Nest backend ALSO reads $PORT, but nginx proxies /api -> localhost:3000,
#    so the backend must stay on 3000. Re-pin it here, after Render has used it.
# -----------------------------------------------------------------------------
export PORT=3000

# -----------------------------------------------------------------------------
# 4) Storage
# -----------------------------------------------------------------------------
export STORAGE_PROVIDER="${STORAGE_PROVIDER:-local}"
export UPLOAD_DIRECTORY="${UPLOAD_DIRECTORY:-/uploads}"
export NEXT_PUBLIC_UPLOAD_DIRECTORY="${NEXT_PUBLIC_UPLOAD_DIRECTORY:-/uploads}"
mkdir -p "${UPLOAD_DIRECTORY}" /config

# -----------------------------------------------------------------------------
# 5) Wait for dependencies (bounded; never blocks forever)
# -----------------------------------------------------------------------------
# url_hostport <url> -> prints "host port" (defaults port to $2 when the URL has none)
url_hostport() {
  local url="$1" default_port="$2" rest hostport host port
  rest="${url#*://}"           # drop scheme
  rest="${rest%%/*}"           # drop path
  rest="${rest%%\?*}"          # drop query
  hostport="${rest##*@}"       # drop credentials
  host="${hostport%%:*}"
  if [[ "${hostport}" == *:* ]]; then port="${hostport##*:}"; else port="${default_port}"; fi
  printf '%s %s\n' "${host}" "${port}"
}

tcp_open() {  # host port
  timeout 3 bash -c "exec 3<>/dev/tcp/$1/$2" 2>/dev/null
}

wait_for() {  # label host port max_seconds
  local label="$1" host="$2" port="$3" max="$4" waited=0
  if [[ -z "${host}" || -z "${port}" ]]; then
    log "WARN: ${label}: no host/port to wait for, skipping."
    return 0
  fi
  log "Waiting for ${label} at ${host}:${port} (max ${max}s)..."
  until tcp_open "${host}" "${port}"; do
    if (( waited >= max )); then
      log "WARN: ${label} still not reachable after ${max}s — starting anyway (Postiz will retry)."
      return 0
    fi
    sleep 3
    waited=$(( waited + 3 ))
  done
  log "${label} is reachable."
}

if [[ -n "${DATABASE_URL:-}" ]]; then
  read -r pg_host pg_port < <(url_hostport "${DATABASE_URL}" 5432)
  wait_for "Postgres" "${pg_host}" "${pg_port}" 180
fi

if [[ -n "${REDIS_URL:-}" ]]; then
  read -r redis_host redis_port < <(url_hostport "${REDIS_URL}" 6379)
  wait_for "Redis" "${redis_host}" "${redis_port}" 120
fi

if [[ -n "${TEMPORAL_HOST:-}" ]]; then
  # Temporal's first boot (schema setup) can take a few minutes.
  wait_for "Temporal" "${TEMPORAL_HOST}" "${TEMPORAL_PORT:-7233}" 300
fi

# -----------------------------------------------------------------------------
# 6) Summary (no secrets) + start
# -----------------------------------------------------------------------------
log "MAIN_URL=${MAIN_URL}"
log "NEXT_PUBLIC_BACKEND_URL=${NEXT_PUBLIC_BACKEND_URL}"
log "TEMPORAL_ADDRESS=${TEMPORAL_ADDRESS} (namespace: ${TEMPORAL_NAMESPACE})"
log "UPLOAD_DIRECTORY=${UPLOAD_DIRECTORY} (provider: ${STORAGE_PROVIDER})"
log "Starting nginx + Postiz (pm2)..."

# Identical to the upstream CMD: nginx daemonizes, pm2 runs in the foreground.
nginx
exec pnpm run pm2
