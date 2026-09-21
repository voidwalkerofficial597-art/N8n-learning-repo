# =============================================================================
# Postiz on Render — wrapper image
# =============================================================================
# Official Postiz image ko as-is Render par chalane me 2 problems aati hain:
#
#   1) Postiz image me bundled nginx port 5000 par hard-coded listen karta hai,
#      jabki Render apne container se $PORT (default 10000) par traffic bhejta hai.
#   2) Postiz ka NestJS backend `process.env.PORT || 3000` padhta hai. Agar hum
#      PORT=10000 chhod dein to backend bhi 10000 par bind karne ki koshish karega
#      aur nginx se takra kar crash ho jayega (EADDRINUSE).
#
# Isliye ye chhota sa wrapper image banaya gaya hai:
#   nginx  -> $PORT (Render ka port)
#   backend-> 3000 (fix), frontend -> 4200 (fix), orchestrator -> 3002 (fix)
#
# Version pin karna zaroori hai — `latest` tag Render ke image cache ki wajah se
# purana mil sakta hai (Render docs: "pulling an image with a mutable tag might
# result in a build that uses a cached, less recent version").
# =============================================================================

ARG POSTIZ_VERSION=v2.23.0
FROM ghcr.io/gitroomhq/postiz-app:${POSTIZ_VERSION}

# Wrapper entrypoint (nginx port fix + URL auto-derive + process start)
COPY entrypoint.sh /usr/local/bin/postiz-render-entrypoint.sh
RUN chmod +x /usr/local/bin/postiz-render-entrypoint.sh \
 && mkdir -p /uploads /config

# Render health checks HTTP se karta hai (render.yaml -> healthCheckPath),
# ye Docker-level healthcheck local `docker compose` testing ke liye hai.
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=5 \
  CMD node -e "const p=process.env.PORT||5000;const r=require('http').get('http://127.0.0.1:'+p+'/healthz',res=>process.exit(res.statusCode<400?0:1));r.on('error',()=>process.exit(1));r.setTimeout(5000,()=>{r.destroy();process.exit(1)})"

CMD ["/usr/local/bin/postiz-render-entrypoint.sh"]
