#!/bin/bash
# -----------------------------------------------------------------------------
# Render entrypoint for Temporal (wraps /etc/temporal/entrypoint.sh of the
# official temporalio/auto-setup image).
#
# What it does before handing over to the official auto-setup:
#   1. Applies Render-friendly defaults.
#   2. Waits for Postgres.
#   3. Creates the `temporal` and `temporal_visibility` databases if missing
#      (via psql, connecting to the DB Render already created for Postiz).
#   4. Tells auto-setup to skip its own CREATE DATABASE step (SKIP_DB_CREATE)
#      — schema setup/upgrade still runs on every start, as upstream intends.
# -----------------------------------------------------------------------------
set -euo pipefail

log() { printf '[render-temporal] %s\n' "$*"; }

# --- 1) Defaults ---------------------------------------------------------------
: "${DB:=postgres12}"
: "${DB_PORT:=5432}"
: "${DBNAME:=temporal}"
: "${VISIBILITY_DBNAME:=temporal_visibility}"
: "${ADMIN_DB:=postgres}"                       # existing DB we connect to for CREATE DATABASE
: "${ENABLE_ES:=false}"                          # SQL-based visibility (no Elasticsearch)
: "${BIND_ON_IP:=0.0.0.0}"                       # listen on all interfaces (Render private network)
: "${TEMPORAL_ADDRESS:=127.0.0.1:7233}"          # used by the in-container `temporal` CLI / health checks
: "${TEMPORAL_CLI_ADDRESS:=${TEMPORAL_ADDRESS}}"
: "${SKIP_DB_CREATE:=true}"                      # we create the DBs ourselves (step 3)
: "${SKIP_DEFAULT_NAMESPACE_CREATION:=false}"    # Postiz uses the `default` namespace
: "${DEFAULT_NAMESPACE_RETENTION:=3d}"
: "${DYNAMIC_CONFIG_FILE_PATH:=/etc/temporal/config/dynamicconfig/render-sql.yaml}"
: "${SQL_MAX_CONNS:=10}"                          # Render Postgres small plans allow ~100 connections
: "${SQL_MAX_IDLE_CONNS:=${SQL_MAX_CONNS}}"
: "${SQL_VIS_MAX_CONNS:=5}"
: "${SQL_VIS_MAX_IDLE_CONNS:=${SQL_VIS_MAX_CONNS}}"
: "${NUM_HISTORY_SHARDS:=4}"
: "${LOG_LEVEL:=info}"
export DB DB_PORT DBNAME VISIBILITY_DBNAME ADMIN_DB ENABLE_ES BIND_ON_IP TEMPORAL_ADDRESS \
       TEMPORAL_CLI_ADDRESS SKIP_DB_CREATE SKIP_DEFAULT_NAMESPACE_CREATION \
       DEFAULT_NAMESPACE_RETENTION DYNAMIC_CONFIG_FILE_PATH SQL_MAX_CONNS SQL_MAX_IDLE_CONNS \
       SQL_VIS_MAX_CONNS SQL_VIS_MAX_IDLE_CONNS NUM_HISTORY_SHARDS LOG_LEVEL

# Render sets PORT for the service; Temporal's frontend gRPC port is fixed at 7233.
if [[ "${PORT:-7233}" != "7233" ]]; then
  log "WARN: PORT=${PORT} but Temporal's frontend listens on 7233. Set PORT=7233 in render.yaml."
fi

# Optional convenience: derive POSTGRES_* from a single connection string.
#   POSTIZ_DATABASE_URL=postgresql://user:pass@host:5432/dbname
if [[ -n "${POSTIZ_DATABASE_URL:-}" && -z "${POSTGRES_SEEDS:-}" ]]; then
  rest="${POSTIZ_DATABASE_URL#*://}"
  creds="${rest%%@*}"; hostpart="${rest#*@}"
  export POSTGRES_USER="${POSTGRES_USER:-${creds%%:*}}"
  export POSTGRES_PWD="${POSTGRES_PWD:-${creds#*:}}"
  hostport="${hostpart%%/*}"
  export POSTGRES_SEEDS="${hostport%%:*}"
  if [[ "${hostport}" == *:* ]]; then export DB_PORT="${hostport##*:}"; fi
  dbpath="${hostpart#*/}"; dbpath="${dbpath%%\?*}"
  [[ -n "${dbpath}" ]] && export ADMIN_DB="${dbpath}"
fi

for v in POSTGRES_SEEDS POSTGRES_USER POSTGRES_PWD; do
  if [[ -z "${!v:-}" ]]; then
    log "ERROR: ${v} is not set. Check the fromDatabase entries in render.yaml."
    exit 1
  fi
done

# --- 2) Wait for Postgres ------------------------------------------------------
export PGPASSWORD="${POSTGRES_PWD}"
export PGCONNECT_TIMEOUT=5
psql_admin() {
  psql -X -q -v ON_ERROR_STOP=1 -h "${POSTGRES_SEEDS}" -p "${DB_PORT}" -U "${POSTGRES_USER}" -d "${ADMIN_DB}" "$@"
}

log "Waiting for Postgres at ${POSTGRES_SEEDS}:${DB_PORT} (db: ${ADMIN_DB}, user: ${POSTGRES_USER})..."
waited=0
until psql_admin -tAc 'SELECT 1' >/dev/null 2>&1; do
  if (( waited >= 300 )); then
    log "ERROR: Postgres not reachable after ${waited}s. Giving up (Render will restart this service)."
    exit 1
  fi
  sleep 5; waited=$(( waited + 5 ))
done
log "Postgres is reachable."

# --- 3) Create Temporal databases if missing -----------------------------------
for db in "${DBNAME}" "${VISIBILITY_DBNAME}"; do
  if [[ ! "${db}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    log "ERROR: invalid database name '${db}' (letters, digits, underscore only)."
    exit 1
  fi
  exists="$(psql_admin -tAc "SELECT 1 FROM pg_database WHERE datname = '${db}'" || true)"
  if [[ "${exists}" == "1" ]]; then
    log "Database '${db}' already exists."
  else
    log "Creating database '${db}'..."
    if ! psql_admin -c "CREATE DATABASE \"${db}\""; then
      log "ERROR: could not create database '${db}'."
      log "       Create it manually (Render dashboard -> postiz-db -> Connect -> PSQL):"
      log "         CREATE DATABASE \"${db}\";"
      log "       or point Temporal at a separate Postgres instance (see README)."
      exit 1
    fi
    log "Database '${db}' created."
  fi
done
unset PGPASSWORD

# --- 4) Hand over to the official auto-setup entrypoint -----------------------
log "Starting Temporal ${TEMPORAL_VERSION:-} (shards: ${NUM_HISTORY_SHARDS}, sql conns: ${SQL_MAX_CONNS}/${SQL_VIS_MAX_CONNS})..."
exec /etc/temporal/entrypoint.sh "$@"
