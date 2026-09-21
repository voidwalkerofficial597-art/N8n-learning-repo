#!/usr/bin/env bash
# =============================================================================
# Postiz secrets generator
# =============================================================================
# Render par JWT_SECRET automatically generate hota hai (render.yaml me
# `generateValue: true`). Ye script tab kaam aata hai jab aap:
#   - local docker-compose chala rahe ho, ya
#   - khud ka .env bana rahe ho
#
# Usage: ./scripts/secrets.sh
# =============================================================================
set -euo pipefail

gen() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 32 | tr -d '\n'
  else
    head -c 32 /dev/urandom | base64 | tr -d '\n'
  fi
}

cat <<EOF
# ---- Postiz secrets (ye copy karke Render Dashboard -> Environment / .env me daalo) ----
JWT_SECRET="$(gen)"

# Render blueprint khud handle karta hai, lekin manual setup ke liye:
# DATABASE_URL="postgresql://USER:PASSWORD@HOST:5432/DB"
# REDIS_URL="redis://HOST:6379"
# TEMPORAL_ADDRESS="HOST:7233"
EOF
