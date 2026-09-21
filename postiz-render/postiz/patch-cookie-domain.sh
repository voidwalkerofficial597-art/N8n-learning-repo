#!/bin/bash
# -----------------------------------------------------------------------------
# Build-time patch: make Postiz auth cookies work on *.onrender.com
#
# Why: Postiz sets its cookies on the "registrable domain" of FRONTEND_URL,
# computed with the `tldts` library (libraries/helpers/src/subdomain/
# subdomain.management.ts). By default tldts ignores the PRIVATE section of the
# Public Suffix List, so for https://my-app.onrender.com it returns
# `.onrender.com`. `onrender.com` IS a public suffix, browsers refuse cookies
# scoped to it, and login silently loops back to /auth.
#
# Fix: flip tldts' default `allowPrivateDomains` from false to true (i.e. behave
# like a browser). Result:
#   https://my-app.onrender.com  ->  .my-app.onrender.com   (works)
#   https://postiz.example.com   ->  .example.com           (unchanged)
#
# Patched in two places, because the backend/orchestrator load tldts from
# node_modules at runtime while the pre-built Next.js frontend has it inlined.
# tldts is used by Postiz only for this cookie-domain helper.
#
# Disable with the SKIP_COOKIE_PATCH=true env var (e.g. when you use a custom
# domain and want the untouched upstream image).
# -----------------------------------------------------------------------------
set -euo pipefail

log() { printf '[cookie-patch] %s\n' "$*"; }

if [[ "${SKIP_COOKIE_PATCH:-false}" == "true" ]]; then
  log "SKIP_COOKIE_PATCH=true — leaving upstream image untouched."
  exit 0
fi

# Matches minified (`allowPrivateDomains:t=!1`, `allowPrivateDomains:!1`) and
# plain (`allowPrivateDomains = false`) forms.
SED_EXPR='s/allowPrivateDomains(:[A-Za-z_$][A-Za-z0-9_$]*)?[[:space:]]*=[[:space:]]*(!1|false)/allowPrivateDomains\1 = true/g
s/allowPrivateDomains:(!1|false)([,}])/allowPrivateDomains:true\2/g'

patched=0
patch_file() {
  local f="$1"
  if grep -qE 'allowPrivateDomains(:[A-Za-z_$][A-Za-z0-9_$]*)?[[:space:]]*=[[:space:]]*(!1|false)|allowPrivateDomains:(!1|false)[,}]' "$f"; then
    sed -i -E "${SED_EXPR}" "$f"
    log "patched: $f"
    patched=$((patched + 1))
  fi
}

# 1) node_modules (backend + orchestrator require tldts at runtime; pnpm hoisted layout,
#    but also handle the isolated .pnpm store layout).
node_patched_before=$patched
while IFS= read -r -d '' f; do patch_file "$f"; done < <(
  find /app/node_modules -type f \( -path '*/tldts/dist/cjs/*.js' -o -path '*/tldts-core/dist/cjs/*.js' \
                                 -o -path '*/tldts/dist/es6/*.js' -o -path '*/tldts-core/dist/es6/*.js' \) -print0 2>/dev/null
)
node_patched=$((patched - node_patched_before))

# 2) Next.js server bundles (frontend proxy sets/clears cookies too).
FE_DIR=/app/apps/frontend/.next/server
fe_files=0
fe_patched_before=$patched
while IFS= read -r -d '' f; do
  fe_files=$((fe_files + 1))
  patch_file "$f"
done < <(grep -rlZ --include='*.js' 'allowPrivateDomains' "${FE_DIR}" 2>/dev/null || true)
fe_patched=$((patched - fe_patched_before))
fe_remaining="$(grep -rlE --include='*.js' 'allowPrivateDomains(:[A-Za-z_$][A-Za-z0-9_$]*)?[[:space:]]*=[[:space:]]*(!1|false)|allowPrivateDomains:(!1|false)[,}]' "${FE_DIR}" 2>/dev/null | wc -l || true)"

log "node_modules files patched: ${node_patched}; frontend bundles containing tldts: ${fe_files}, patched now: ${fe_patched}, still unpatched: ${fe_remaining}"

# 3) Verify the runtime behaviour the backend will see.
if ! node -e '
  const { parse } = require("/app/node_modules/tldts");
  const r = parse("https://my-app.onrender.com");
  if (r.domain !== "my-app.onrender.com") { console.error("unexpected:", r); process.exit(1); }
  const c = parse("https://postiz.example.com");
  if (c.domain !== "example.com") { console.error("unexpected:", c); process.exit(1); }
'; then
  log "ERROR: verification failed — tldts still treats onrender.com as a registrable domain."
  log "       Login on *.onrender.com would not work. Either fix this script for the new"
  log "       Postiz version, or use a custom domain (MAIN_URL) and set SKIP_COOKIE_PATCH=true."
  exit 1
fi

if (( fe_files == 0 )) || (( fe_remaining > 0 )); then
  log "ERROR: frontend bundle check failed (found: ${fe_files}, unpatched: ${fe_remaining})."
  log "       Logout/org cookies would be set on the wrong domain on *.onrender.com."
  log "       Set SKIP_COOKIE_PATCH=true to build anyway (custom domain only)."
  exit 1
fi

log "OK — cookies will be scoped to the full hostname on *.onrender.com."
