#!/usr/bin/env bash
# =============================================================================
# Temporal (auto-setup) wrapper for Render
# =============================================================================
# Render Blueprint se humein ek `TEMPORAL_DATABASE_URL` milta hai
# (postgresql://user:pass@host:port/db). auto-setup ko alag-alag vars chahiye,
# isliye yahan parse karke export karte hain aur phir original entrypoint
# (`/etc/temporal/entrypoint.sh autosetup`) ko chalate hain.
#
# auto-setup khud ye kaam karta hai:
#   - `temporal` aur `temporal_visibility` databases create karna
#   - schema setup / upgrade
#   - `default` namespace register karna  (Postiz isi namespace ka use karta hai)
#
# Note: Render Postgres ka user nayi databases create kar sakta hai
# ("Adding multiple databases to a single instance" — Render docs), isliye
# SKIP_DB_CREATE=false (default) theek rehta hai.
# =============================================================================
set -euo pipefail

log() { echo "[temporal-render] $*"; }

if [[ -n "${TEMPORAL_DATABASE_URL:-}" ]]; then
  url="${TEMPORAL_DATABASE_URL#*://}"      # user:pass@host:port/db?params
  creds="${url%%@*}"                       # user:pass
  rest="${url#*@}"                         # host:port/db?params
  hostport="${rest%%/*}"                   # host:port

  export POSTGRES_USER="${creds%%:*}"
  export POSTGRES_PWD="${creds#*:}"
  export POSTGRES_SEEDS="${hostport%%:*}"
  export DB_PORT="${hostport##*:}"
  DB_PORT="${DB_PORT%%\?*}"                # agar port me ?params ho to hata do

  log "Postgres seed: ${POSTGRES_SEEDS}:${DB_PORT} (user: ${POSTGRES_USER})"
  log "Password URL-decoded nahi kiya gaya — agar password me % jaisa encoded character ho to dashboard me khud POSTGRES_* vars set karo."
fi

# --- Sensible defaults for a small single-node Temporal -----------------------
export DB="${DB:-postgres12}"
export ENABLE_ES="${ENABLE_ES:-false}"                 # Elasticsearch OFF = sasta + halka
export DBNAME="${DBNAME:-temporal}"
export VISIBILITY_DBNAME="${VISIBILITY_DBNAME:-temporal_visibility}"
export BIND_ON_IP="${BIND_ON_IP:-0.0.0.0}"             # Render private network par sab jagah se reachable
export TEMPORAL_BROADCAST_ADDRESS="${TEMPORAL_BROADCAST_ADDRESS:-}"
export DEFAULT_NAMESPACE="${DEFAULT_NAMESPACE:-default}"
export DEFAULT_NAMESPACE_RETENTION="${DEFAULT_NAMESPACE_RETENTION:-24h}"

# Empty TEMPORAL_BROADCAST_ADDRESS auto-setup ko confuse na kare
if [[ -z "${TEMPORAL_BROADCAST_ADDRESS}" ]]; then
  unset TEMPORAL_BROADCAST_ADDRESS
fi

if [[ -z "${POSTGRES_SEEDS:-}" ]]; then
  log "ERROR: TEMPORAL_DATABASE_URL (ya POSTGRES_SEEDS) set nahi hai." >&2
  exit 1
fi

log "Temporal start ho raha hai (pehli baar schema setup me 1-3 min lag sakte hain)..."
exec /etc/temporal/entrypoint.sh "$@"
