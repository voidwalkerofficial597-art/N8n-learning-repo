# -----------------------------------------------------------------------------
# Postiz for Render
#
# Thin wrapper around the official image. It adds:
#   1. entrypoint.sh — derives MAIN_URL / FRONTEND_URL / NEXT_PUBLIC_BACKEND_URL
#      from RENDER_EXTERNAL_URL, builds TEMPORAL_ADDRESS from the private hostname
#      Render injects, waits for Postgres / Redis / Temporal, then starts the app
#      exactly like upstream does (nginx + pm2).
#   2. patch-cookie-domain.sh — build-time fix so login cookies work on
#      *.onrender.com (a Public Suffix List domain). See the script for details.
#      Opt out with the SKIP_COOKIE_PATCH=true env var.
#
# POSTIZ_VERSION is set in render.yaml (Render passes env vars as build args).
# Releases: https://github.com/gitroomhq/postiz-app/releases
# -----------------------------------------------------------------------------
ARG POSTIZ_VERSION=v2.23.0
FROM ghcr.io/gitroomhq/postiz-app:${POSTIZ_VERSION}

# Upstream image: Debian bookworm-slim, node 22, pnpm, pm2, nginx, WORKDIR /app, runs as root.
COPY entrypoint.sh patch-cookie-domain.sh /render/
RUN chmod +x /render/entrypoint.sh /render/patch-cookie-domain.sh \
    && mkdir -p /uploads /config

ARG SKIP_COOKIE_PATCH=false
RUN SKIP_COOKIE_PATCH=${SKIP_COOKIE_PATCH} /render/patch-cookie-domain.sh

# Public traffic: Render -> $PORT (5000) -> nginx -> Next.js (4200) / Nest backend (3000, under /api)
EXPOSE 5000

# Same effect as upstream's `sh -c "nginx && pnpm run pm2"`, plus Render-specific env wiring.
CMD ["/render/entrypoint.sh"]
