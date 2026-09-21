# 02 — Render par deploy karo

## Pehle ye kar lo

- [ ] Private GitHub repo ready (→ [`01-github-private-repo.md`](01-github-private-repo.md))
- [ ] Cloudflare R2 bucket + keys ready (→ [`03-storage.md`](03-storage.md))
- [ ] Render account (email/GitHub se signup)

---

## Step 1 — Blueprint deploy

1. Render Dashboard → **New +** → **Blueprint**
2. Repo list me apna **private** repo select karo (dikhe nahi to "Configure account" → Render ko us repo ka access do)
3. **Blueprint Path:** default `render.yaml` hi rehne do (agar file root me hai)
4. Naam/region confirm karo → **Apply / Create**

Render ab ye 5 resources banayega:

| # | Resource | Type | Kaam |
|---|---|---|---|
| 1 | `postiz` | Web Service (Docker) | Poora Postiz app (nginx + frontend + backend + worker) |
| 2 | `temporal` | Private Service (Docker) | Postiz v2.12+ ka workflow engine |
| 3 | `postiz-db` | Postgres | App ka data |
| 4 | `temporal-db` | Postgres | Workflow history |
| 5 | `postiz-redis` | Key Value | Cache / queues |

**Env var prompts:** Render 6 values poochega (Cloudflare R2 wale — `sync: false`).
Wahan Step 2 ki values daal do. (Prompt sirf *pehli baar* aata hai.)

---

## Step 2 — Pehla deploy (5–10 min lagta hai)

Order aise chalta hai:

1. **Postgres + Redis** ready hote hain (~2 min)
2. **Temporal** build + start — pehli baar schema setup (1–3 min)
3. **Postiz** image build — wrapper `FROM ghcr.io/...` hai, isliye build fast (~1–2 min)
4. **Postiz container start** — Prisma `db push` + `pnpm dlx` download ki wajah se
   first boot me **2–5 min** lagte hain. Logs me `[postiz-render]` lines dikhengi.

> Agar aapko `health check failed` dikh raha hai lekin logs me kaam chal raha hai —
> thoda wait karo. Render service ko **Live** hone me 1-3 attempts lag sakte hain.
> Bahut zyada problem ho to `render.yaml` se `healthCheckPath: /` hata do (temporarily).

---

## Step 3 — URL check karo

1. Render Dashboard → `postiz` service → upar ka URL (jaise `https://postiz-abcd.onrender.com`)
2. Browser me kholo → Postiz ka landing page
3. Ek HTTP 200 aana chahiye. `502` aa raha hai? → [`06-troubleshooting.md`](06-troubleshooting.md)

**URL set karne ki zaroorat nahi** — `entrypoint.sh` Render ke `RENDER_EXTERNAL_URL`
se `MAIN_URL` / `FRONTEND_URL` / `NEXT_PUBLIC_BACKEND_URL` khud bana leta hai.

---

## Step 4 — Custom domain (optional, recommended)

Custom domain se OAuth redirect URLs stable rehte hain (onrender.com naam badla to
saare provider settings dobara karni padengi).

1. Render → `postiz` → **Settings → Custom Domains → Add**
2. `postiz.yourdomain.com` daalo → Render DNS record (CNAME/A) dikhayega → apne domain provider me add karo
3. Certificate auto-issue ho jayega
4. Phir Render → `postiz` → **Environment** me add karo:
   ```
   MAIN_URL = https://postiz.yourdomain.com
   ```
   (`FRONTEND_URL` aur `NEXT_PUBLIC_BACKEND_URL` khud derive ho jayenge)
5. **Save and deploy**
6. Har social provider ke developer portal me redirect URI update karo:
   `https://postiz.yourdomain.com/api/integrations/social/<provider>`

---

## Step 5 — Verify (Temporal + DB)

**Temporal check:**
- Render → `temporal` service → Logs → `namespace default registered` jaise lines dikhni chahiye
- Postiz app ke andar: Settings → **Developer** / ya koi scheduled post banao aur
  "next run" time dekho — scheduled posts chalne ka matlab Temporal theek hai

**DB check:**
- Render → `postiz-db` → **Info** me connection details
- Ya `scripts/backup-db.sh` chalakar ek dump le lo — connection kaam kar raha hai ya nahi turant pata chal jayega

---

## Deploy settings (jo render.yaml me hain)

| Setting | Value | Kyun |
|---|---|---|
| `region` | `singapore` | India se sabse kam latency |
| `plan` (postiz) | `1c-2g` | Postiz ko 2 GB RAM chahiye — 512 MB par OOM/crash |
| `plan` (temporal) | `0.5c-512mb` | Single-user ke liye kaafi; load badhe to `1c-2g` |
| `healthCheckPath` | `/healthz` | Wrapper entrypoint nginx me ye endpoint add karta hai — nginx 1 sec me up hota hai, isliye Postiz ke slow first-boot me bhi deploy fail nahi hota |
| `autoDeployTrigger` | `commit` | Push par auto deploy |
| `maxShutdownDelaySeconds` | `120` | Graceful shutdown (kaam beech me na chhoote) |

---

## Deploy ke baad ke kaam

1. Pehla account banao + registration band karo → [`05-first-login-and-security.md`](05-first-login-and-security.md)
2. Social platforms jodo → [`04-social-providers.md`](04-social-providers.md)
3. Backup schedule kar lo → `scripts/backup-db.sh`

---

## Update / rollback

**Update:** GitHub me push karo → Render auto-deploy. (Ya Dashboard → Manual Deploy)

**Rollback:** Render → service → **Deploys** → purana deploy → **Rollback**.
Postiz image tag `Dockerfile` me pinned hai, isliye ek commit revert karne se
version bhi wapas aa jata hai.
