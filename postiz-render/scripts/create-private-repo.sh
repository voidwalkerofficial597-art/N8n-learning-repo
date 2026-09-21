#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Create a PRIVATE GitHub repository containing this folder (postiz-render/)
# as its root, and push it. Idempotent-ish: refuses to overwrite an existing repo.
#
# Usage:
#   ./scripts/create-private-repo.sh                 # -> <your-github-user>/postiz-render
#   ./scripts/create-private-repo.sh my-postiz       # custom repo name
#   OWNER=my-org ./scripts/create-private-repo.sh    # create under an organization
#
# Requirements: git, GitHub CLI (https://cli.github.com). Works on macOS, Linux,
# and Windows (Git Bash / WSL).
# -----------------------------------------------------------------------------
set -euo pipefail

REPO_NAME="${1:-postiz-render}"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

say()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
fail() { printf '\n\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

command -v git >/dev/null 2>&1 || fail "git is not installed."
command -v gh  >/dev/null 2>&1 || fail "GitHub CLI (gh) is not installed. Install: https://cli.github.com  (or follow the manual steps in README.md)"

if ! gh auth status >/dev/null 2>&1; then
  say "Logging in to GitHub (a browser window will open)..."
  gh auth login --web --git-protocol https
fi

OWNER="${OWNER:-$(gh api user --jq .login)}"
FULL="${OWNER}/${REPO_NAME}"

if gh repo view "${FULL}" >/dev/null 2>&1; then
  fail "Repository ${FULL} already exists. Pick another name: $0 <name>"
fi

say "Preparing a clean copy of ${SRC_DIR}"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT
# Copy everything except any parent .git metadata.
tar -C "${SRC_DIR}" --exclude=.git -cf - . | tar -C "${TMP}" -xf -

cd "${TMP}"
git init -q
git checkout -q -b main 2>/dev/null || true
git config user.name  "$(git config --global user.name  || echo "${OWNER}")"
git config user.email "$(git config --global user.email || echo "${OWNER}@users.noreply.github.com")"
git add -A
git commit -q -m "Postiz on Render: initial Blueprint setup"

say "Creating PRIVATE repository ${FULL} and pushing..."
gh repo create "${FULL}" \
  --private \
  --description "Postiz (self-hosted social media scheduler) on Render — Blueprint" \
  --source=. \
  --remote=origin \
  --push

REPO_URL="https://github.com/${FULL}"
say "Done!"
cat <<EOF

  Repository : ${REPO_URL}   (private)

  Next step — deploy on Render:
    1. https://dashboard.render.com/blueprints  ->  "New Blueprint Instance"
    2. Connect GitHub (if asked) and give Render access to "${REPO_NAME}"
    3. Select the repo -> Render reads render.yaml -> "Apply"

  One-click alternative:
    https://render.com/deploy?repo=${REPO_URL}

EOF
