# -----------------------------------------------------------------------------
# Temporal server for Postiz on Render
#
# Based on the same image Postiz's official docker-compose uses
# (temporalio/auto-setup), plus:
#   - psql, so the entrypoint can create the `temporal` and `temporal_visibility`
#     databases inside the Render Postgres instance (Render gives us one DB by
#     default; Temporal's own db-create step needs the `postgres` maintenance DB,
#     which is not reliably available on managed Postgres).
#   - Render-friendly defaults (bind on 0.0.0.0, SQL visibility, low connection counts).
#
# TEMPORAL_VERSION is set in render.yaml (Render passes env vars as build args).
# -----------------------------------------------------------------------------
ARG TEMPORAL_VERSION=1.28.1
FROM temporalio/auto-setup:${TEMPORAL_VERSION}

USER root
RUN apk add --no-cache postgresql-client

# Dynamic config (same values as Postiz's official compose file).
COPY dynamicconfig/render-sql.yaml /etc/temporal/config/dynamicconfig/render-sql.yaml
COPY entrypoint.sh /etc/temporal/render-entrypoint.sh
RUN chmod +x /etc/temporal/render-entrypoint.sh \
    && chown -R temporal:temporal /etc/temporal/config/dynamicconfig

USER temporal
WORKDIR /etc/temporal

# gRPC frontend used by Postiz (7233). Membership/other ports stay internal.
EXPOSE 7233

ENTRYPOINT ["/etc/temporal/render-entrypoint.sh"]
CMD ["autosetup"]
