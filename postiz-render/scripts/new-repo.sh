#!/usr/bin/env bash
# =============================================================================
# Postiz-on-Render kit -> naya PRIVATE GitHub repo (ek command me)
# =============================================================================
# Ye script is folder ka saara content ek naye local folder me copy karta hai,
# usme git init karke pehla commit bana deta hai, aur aapko `gh repo create`
# ka ready-made command dikhata hai (private repo ke saath).
#
# Usage:
#   ./scripts/new-repo.sh ../postiz-render          # default: sibling folder
#   ./scripts/new-repo.sh ~/projects/postiz-render
# =============================================================================
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${1:-$SRC/../postiz-render-repo}"

echo "Source : $SRC"
echo "Target : $DEST"
echo

if [ -e "$DEST" ] && [ -n "$(ls -A "$DEST" 2>/dev/null || true)" ]; then
  echo "❌ Target folder khali nahi hai: $DEST"
  echo "   Koi aur path do ya us folder ko hata do."
  exit 1
fi

mkdir -p "$DEST"

# rsync ho to best, warna cp fallback
if command -v rsync >/dev/null 2>&1; then
  rsync -a --exclude '.git' --exclude '.env' --exclude 'backups' "$SRC"/ "$DEST"/
else
  (cd "$SRC" && tar --exclude='./.git' --exclude='./.env' --exclude='./backups' -cf - .) | (cd "$DEST" && tar -xf -)
fi

cd "$DEST"
git init -q -b main
git add -A
git -c user.email="you@example.com" -c user.name="$(git config user.name 2>/dev/null || echo 'You')" \
  commit -q -m "Postiz on Render: deploy kit (Blueprint + Docker wrapper + docs)"

chmod +x scripts/*.sh entrypoint.sh temporal/entrypoint.sh 2>/dev/null || true

cat <<EOF

✅ Naya repo ban gaya: $DEST

Ab GitHub par PRIVATE repo banao aur push karo (gh CLI se):

    cd "$DEST"
    gh repo create <aapka-username>/postiz-render --private --source=. --remote=origin --push

Ya GitHub website se:
    1. https://github.com/new -> Repository name: postiz-render -> Private -> Create
    2. phir ye chalao:
       git remote add origin https://github.com/<aapka-username>/postiz-render.git
       git push -u origin main

Uske baad Render par: docs/02-render-deploy.md
EOF
