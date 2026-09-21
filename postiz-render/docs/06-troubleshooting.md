# 06 — Troubleshooting

## Pehle ye 3 cheezein dekho

1. **Logs:** Render → service → **Logs**. `[postiz-render]` aur `[temporal-render]`
   prefix wali lines startup ke baare me sab kuch batati hain.
2. **Memory:** Postiz ko **2 GB** chahiye. `0.5c-512mb` par OOM/crash hoga.
   Logs me `Killed` / `out of memory` dikhe to plan badhao.
3. **URLs:** `MAIN_URL` = aapke browser ka exact URL hona chahiye
   (https, koi trailing slash nahi).

---

## `502 / Application failed to respond`

| Wajah | Fix |
|---|---|
| App abhi start ho raha hai (first boot 2–5 min leta hai) | Wait karo, logs dekho |
| Health check fail ho raha (memory) | Render → Metrics me memory 100% dekho → plan `1c-2g` karo |
| Port conflict (`EADDRINUSE`) | Ye wrapper isse handle karta hai; agar dikhe to log me `nginx listen port -> XXXX` line check karo aur issue khole |
| nginx conf sed fail (`listen 5000;` na mila) | Postiz ne nginx config badla hai — `Dockerfile` me `ARG POSTIZ_VERSION` update karke test karo |

## Container start hi nahi ho raha / restart loop

Render → Logs me dekho:

- `DATABASE_URL set nahi hai` → blueprint ka env var missing (dashboard me add karo)
- `TEMPORAL_ADDRESS set nahi hai` → `temporal` service create nahi hui / naam alag hai
  (blueprint me `name: temporal` hona chahiye)
- `prisma db push` fail → DB credentials / private network issue (dono same region hone chahiye)

## Uploads redeploy ke baad gayab

Matlab storage local hai (`STORAGE_PROVIDER=local`) aur Render filesystem ephemeral
hai. → [`03-storage.md`](03-storage.md) (Cloudflare R2 free)

## Scheduled posts chal nahi rahe / "TEMPORAL" errors

1. Render → `temporal` service → Logs check karo (`namespace default registered`?)
2. `temporal` service ka **address** lo: Dashboard → temporal → Service Address
   (`temporal-xxxx:7233` jaisa) aur usse compare karo jo `postiz` service ke
   `TEMPORAL_ADDRESS` env var me hai
3. Mismatch ho to `postiz` service me manually set karo:
   ```
   TEMPORAL_ADDRESS = temporal-xxxx:7233
   ```
4. Temporal crash ho raha ho (OOM) to plan `1c-2g` karo
5. **Pehli baar** Temporal schema setup 1–3 min leta hai — us waqt errors normal hain

## Redis errors / random logouts

- `postiz-redis` ka free plan sirf **25 MB** hai. `noeviction`/full errors aayein to:
  Render → `postiz-redis` → plan `256mb` (~$10/mo)
- Connection string galat ho to Postiz env me `REDIS_URL` check karo
  (`redis://red-xxxx:6379` format)

## OAuth: `redirect_uri mismatch` / `invalid state`

1. Provider portal me redirect URI: `https://<aapka-url>/api/integrations/social/<provider>`
   — character by character same hona chahiye
2. `MAIN_URL` env var apne asli URL se match kare
3. Custom domain ka `www` vs non-`www`, ya `http` vs `https` — mismatch aksar yahin hota hai

## Database connection errors (`Can't reach database server`)

- `postiz` aur `postiz-db` **same region** me hone chahiye (blueprint me sab `singapore`)
- `ipAllowList: []` set kiya hai? Iska matlab sirf **private network** se connection.
  Bahar se (laptop/pgAdmin) connect karna ho to Render Dashboard → DB → Settings me
  apna IP add karo
- Postgres restart ho raha ho / disk full: Render → DB → Metrics dekho

## Deploy bahut slow / `pnpm dlx prisma` par atka

Pehli boot me Prisma CLI download hota hai — ye normal hai aur 2–5 min leta hai.
Uske baad har restart par bhi thoda time lagta hai (image me wo CLI cache nahi hoti).

Agar Render health check ki wajah se container ko maar raha ho to:
1. Deploy ko **cancel mat karo**, logs me progress dekho
2. `render.yaml` se `healthCheckPath: /` **temporarily** hata do → Render phir
   sirf "process chalu hai" check karega
3. Sab theek chalne ke baad `healthCheckPath` wapas add kar do aur ek baar
   redeploy karke confirm karo

## Shell access chahiye (debug)

Render paid services par **Shell** milta hai: service → **Shell** → andar jaakar:

```bash
env | grep -E 'MAIN_URL|PORT|TEMPORAL|STORAGE'
ps aux | head -30
tail -50 /var/log/nginx/error.log
curl -s localhost:3000/health 2>/dev/null || echo "backend not up"
```

## Poora reset karna ho

- **App reset:** Render → `postiz` → Manual Deploy → Deploy latest commit
- **DB reset:** ⚠️ sab data delete hoga. Render → `postiz-db` → Danger Zone,
  ya naya DB bana ke `DATABASE_URL` badal do (Postiz khud schema bana lega)
- **Temporal reset:** `temporal-db` ko recreate karo; Temporal khud schema bana
  lega, lekin pending workflows ki history chali jayegi

---

## Aur madad

- Postiz docs: https://docs.postiz.com/general/troubleshooting/overview
- Postiz GitHub issues: https://github.com/gitroomhq/postiz-app/issues
- Render docs: https://render.com/docs
