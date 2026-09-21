# =============================================================================
# Temporal server on Render — wrapper image
# =============================================================================
# Postiz v2.12.0+ ke liye Temporal ZAROORI hai (official requirement):
#   https://docs.postiz.com/self-host/installation/system-requirements
#
# Render Blueprint me Postgres ka sirf `connectionString` property milta hai,
# lekin temporalio/auto-setup ko POSTGRES_SEEDS / POSTGRES_USER / POSTGRES_PWD /
# DB_PORT alag-alag chahiye. Isliye ye wrapper connection-string ko tod kar
# auto-setup ke env vars me convert karta hai.
#
# Fayda: Elasticsearch ki zaroorat NAHI (ENABLE_ES=false) -> Temporal SQL
# visibility (Postgres) use karta hai. Isse ~650MB RAM aur ek extra service
# bachti hai. Chhote/single-user Postiz ke liye ye bilkul kaafi hai.
# =============================================================================

ARG TEMPORAL_VERSION=1.28.1
FROM temporalio/auto-setup:${TEMPORAL_VERSION}

COPY temporal/entrypoint.sh /etc/temporal/render-entrypoint.sh
RUN chmod +x /etc/temporal/render-entrypoint.sh

# Temporal frontend gRPC port — Render ko batane ke liye render.yaml me
# PORT=7233 set kiya gaya hai (isse `hostport` reference sahi banta hai).
EXPOSE 7233

ENTRYPOINT ["/etc/temporal/render-entrypoint.sh"]
CMD ["autosetup"]
