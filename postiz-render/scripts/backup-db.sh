#!/usr/bin/env bash
# =============================================================================
# Render Postgres backup (pg_dump) — apne laptop se
# =============================================================================
# Render ka built-in backup bhi hota hai, lekin apna local dump rakhna hamesha
# accha hota hai (Postiz upgrade se pehle ise zaroor chalao).
#
# Zaroori: Render Postgres -> Settings -> IP Allow List me apna IP add karo,
# warna external connection block hoga. (Ya `ipAllowList: []` hataye rakho.)
#
# Usage:
#   export POSTGRES_EXTERNAL_URL='postgresql://user:pass@host:5432/db'
#   ./scripts/backup-db.sh
#
# External URL kahan se: Render Dashboard -> postiz-db -> Connect -> External
# =============================================================================
set -euo pipefail

URL="${POSTGRES_EXTERNAL_URL:-}"
if [ -z "$URL" ]; then
  echo "❌ POSTGRES_EXTERNAL_URL set nahi hai. Upar wale comment padho." >&2
  exit 1
fi

mkdir -p backups
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="backups/postiz-$STAMP.sql"

echo "⏳ Dump ban raha hai -> $OUT"
if command -v pg_dump >/dev/null 2>&1; then
  pg_dump --no-owner --no-privileges "$URL" > "$OUT"
else
  echo "   pg_dump local install nahi hai, Docker se chala rahe hain..."
  docker run --rm -e PGURL="$URL" -v "$PWD/backups:/backups" postgres:17-alpine \
    sh -c 'pg_dump --no-owner --no-privileges "$PGURL"' > "$OUT"
fi

echo "✅ Backup ready: $OUT ($(du -h "$OUT" | cut -f1))"
echo
echo "Restore karna ho to:"
echo "  psql \"\$POSTGRES_EXTERNAL_URL\" < $OUT"
