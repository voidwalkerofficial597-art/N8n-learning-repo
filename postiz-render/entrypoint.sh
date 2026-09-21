#!/bin/sh
# =============================================================================
# Postiz on Render — entrypoint
# =============================================================================
# Kaam:
#   1. nginx ko Render ke $PORT par shift karna
#   2. Postiz backend ko wapas 3000 par force karna (nginx /api/ -> :3000 proxy)
#   3. Public URLs (MAIN_URL / FRONTEND_URL / NEXT_PUBLIC_BACKEND_URL) ko
#      Render ke RENDER_EXTERNAL_URL se auto-derive karna (manual copy-paste nahi!)
#   4. DATABASE_URL / REDIS_URL / TEMPORAL_ADDRESS ko normalise karna
#   5. nginx + pm2 (backend, frontend, orchestrator) start karna
# =============================================================================
set -e

log() { echo "[postiz-render] $*"; }
warn() { echo "[postiz-render] WARNING: $*" >&2; }

# -----------------------------------------------------------------------------
# 1) PORT mapping  (nginx = Render ka PORT, backend = 3000)
# -----------------------------------------------------------------------------
APP_PORT="${PORT:-5000}"
NGINX_CONF="${NGINX_CONF:-/etc/nginx/nginx.conf}"

if [ -f "$NGINX_CONF" ]; then
  # idempotent: pehle 5000 -> APP_PORT, warna agar dobara chale to kuch na kare
  sed -i "s/listen 5000;/listen ${APP_PORT};/g" "$NGINX_CONF"
  log "nginx listen port -> ${APP_PORT}"

  # /healthz endpoint add karo — Render isko hit karke service ko "Live" maanta hai.
  # Faayda: nginx 1 second me up ho jata hai, isliye Postiz ke 2-5 min wale
  # first-boot ke dauran bhi deploy fail nahi hota.
  if ! grep -q "location = /healthz" "$NGINX_CONF"; then
    sed -i 's|^\( *\)location / {|\1location = /healthz { access_log off; return 200 "ok"; }\n\n\1location / {|' "$NGINX_CONF"
    log "nginx /healthz endpoint add kiya (Render health check)"
  fi
else
  warn "$NGINX_CONF nahi mila. Postiz image ka layout badla ho sakta hai."
fi

mkdir -p /uploads /config /var/log/nginx /var/lib/nginx/tmp /run 2>/dev/null || true

# -----------------------------------------------------------------------------
# 2) Public URLs — Render khud RENDER_EXTERNAL_URL deta hai
#    (jaise https://postiz-abcd.onrender.com)
#    Custom domain use kar rahe ho to render.yaml/dashboard me MAIN_URL set karo,
#    wo yahan override nahi hoga.
# -----------------------------------------------------------------------------
if [ -z "${MAIN_URL:-}" ] && [ -n "${RENDER_EXTERNAL_URL:-}" ]; then
  MAIN_URL="$RENDER_EXTERNAL_URL"
  log "MAIN_URL auto-derived from RENDER_EXTERNAL_URL"
fi

if [ -z "${MAIN_URL:-}" ]; then
  warn "MAIN_URL set nahi hai. OAuth redirects aur links toot sakte hain."
  MAIN_URL="http://localhost:${APP_PORT}"
fi

# trailing slash hata do (Postiz exact URL match karta hai)
MAIN_URL="${MAIN_URL%/}"
export MAIN_URL
export FRONTEND_URL="${FRONTEND_URL:-$MAIN_URL}"
FRONTEND_URL="${FRONTEND_URL%/}"
export FRONTEND_URL
export NEXT_PUBLIC_BACKEND_URL="${NEXT_PUBLIC_BACKEND_URL:-$FRONTEND_URL/api}"
log "MAIN_URL=$MAIN_URL"
log "FRONTEND_URL=$FRONTEND_URL"
log "NEXT_PUBLIC_BACKEND_URL=$NEXT_PUBLIC_BACKEND_URL"

# -----------------------------------------------------------------------------
# 3) DATABASE_URL normalise (Prisma ke liye postgresql:// scheme)
# -----------------------------------------------------------------------------
if [ -n "${DATABASE_URL:-}" ]; then
  case "$DATABASE_URL" in
    postgres://*)
      DATABASE_URL="postgresql://${DATABASE_URL#postgres://}"
      export DATABASE_URL
      log "DATABASE_URL scheme postgres:// -> postgresql:// convert kiya"
      ;;
  esac
else
  warn "DATABASE_URL set nahi hai — Postiz start nahi hoga."
fi

# -----------------------------------------------------------------------------
# 4) REDIS_URL — agar blueprint se host/port alag mile to URL bana do
# -----------------------------------------------------------------------------
if [ -z "${REDIS_URL:-}" ] && [ -n "${REDIS_HOST:-}" ]; then
  if [ -n "${REDIS_PASSWORD:-}" ]; then
    REDIS_URL="redis://:${REDIS_PASSWORD}@${REDIS_HOST}:${REDIS_PORT:-6379}"
  else
    REDIS_URL="redis://${REDIS_HOST}:${REDIS_PORT:-6379}"
  fi
  export REDIS_URL
fi
[ -n "${REDIS_URL:-}" ] || warn "REDIS_URL set nahi hai."

# -----------------------------------------------------------------------------
# 5) TEMPORAL_ADDRESS — Postiz v2.12+ ke liye Temporal ZAROORI hai
# -----------------------------------------------------------------------------
if [ -z "${TEMPORAL_ADDRESS:-}" ] && [ -n "${TEMPORAL_HOST:-}" ]; then
  TEMPORAL_ADDRESS="${TEMPORAL_HOST}:${TEMPORAL_PORT:-7233}"
  export TEMPORAL_ADDRESS
fi
if [ -n "${TEMPORAL_ADDRESS:-}" ]; then
  log "TEMPORAL_ADDRESS=$TEMPORAL_ADDRESS"
else
  warn "TEMPORAL_ADDRESS set nahi hai. Postiz v2.12+ me scheduled posts kaam nahi karenge."
fi

# -----------------------------------------------------------------------------
# 6) Self-hosting defaults
# -----------------------------------------------------------------------------
export IS_GENERAL="${IS_GENERAL:-true}"
export BACKEND_INTERNAL_URL="${BACKEND_INTERNAL_URL:-http://localhost:3000}"
export STORAGE_PROVIDER="${STORAGE_PROVIDER:-local}"
export UPLOAD_DIRECTORY="${UPLOAD_DIRECTORY:-/uploads}"
export NEXT_PUBLIC_UPLOAD_DIRECTORY="${NEXT_PUBLIC_UPLOAD_DIRECTORY:-/uploads}"
export TZ="${TZ:-UTC}"

if [ "${STORAGE_PROVIDER}" = "local" ]; then
  warn "STORAGE_PROVIDER=local hai — Render par filesystem EPHEMERAL hai. Redeploy/restart par uploads MIT jayenge. Cloudflare R2 (free) ya persistent disk use karo: docs/03-storage.md"
fi

# -----------------------------------------------------------------------------
# 7) Start — nginx (background) + pm2 (foreground)
#    Dhyan do: ab PORT ko 3000 kar dete hain, warna NestJS backend Render ka
#    10000 bind karne ki koshish karega aur nginx se conflict hoga.
# -----------------------------------------------------------------------------
export PORT=3000
log "backend PORT -> 3000 (nginx ${APP_PORT} se proxy karega)"

nginx
log "nginx started"

log "Postiz start ho raha hai (pehli baar prisma db push + npm downloads ki wajah se 2-5 min lag sakte hain)..."
exec pnpm run pm2
