# Postiz on Render 🚀

Postiz (open-source social media scheduler) ko **Render** par self-host karne ka
ready-made setup — GitHub repo + Render Blueprint + wrapper images + step-by-step docs.

> **Ye kit kis kaam ki hai:** Postiz ki official Docker image Render par *directly*
> nahi chalti (nginx port 5000 par hard-coded hai, aur Render `$PORT` expect karta hai).
> Ye repo wahi 2 problems fix karta hai, saath me Temporal server ko bhi sasta
> (Elasticsearch ke bina) chalata hai.

---

## 1. Architecture

```
                        Internet
                            │  https://postiz-xxxx.onrender.com
                            ▼
        ┌───────────────────────────────────────────────────┐
        │  postiz  (Web Service — Docker)                   │
        │  ┌─────────────────────────────────────────────┐  │
        │  │ nginx  :$PORT                               │  │
        │  │   /api/*  -> backend   localhost:3000       │  │
        │  │   /*      -> frontend  localhost:4200       │  │
        │  └─────────────────────────────────────────────┘  │
        │  backend + frontend + orchestrator (pm2)          │
        └───────┬───────────────┬───────────────┬───────────┘
                │               │               │
    private network (Render ke andar, internet par expose nahi)
                │               │               │
        ┌───────▼──────┐ ┌──────▼───────┐ ┌─────▼────────┐
        │ postiz-db    │ │ postiz-redis │ │ temporal     │
        │ (Postgres)   │ │ (Key Value)  │ │ (Private)    │
        └──────────────┘ └──────────────┘ └─────┬────────┘
                                                │
                                        ┌───────▼────────┐
                                        │ temporal-db    │
                                        │ (Postgres)     │
                                        └────────────────┘
                │
                ▼
        Cloudflare R2 (free 10 GB) — images/videos ke liye
```

**Kyun Temporal?** Postiz **v2.12.0 se Temporal zaroori** hai (scheduled posts ki
orchestration ke liye). Official compose Temporal + Elasticsearch + 4 services
chalata hai (~$100+/mo Render par). Yahan hum **ek hi `auto-setup` container,
Elasticsearch ke bina** (Postgres SQL visibility) use kar rahe hain — ~650 MB RAM
aur paisa bachta hai.

---

## 2. Kya chahiye

| Cheez | Kyun |
|---|---|
| Render account | Deploy + Postgres + Redis |
| **Private** GitHub repo | Blueprint isi repo se deploy hota hai |
| Cloudflare account (free) | R2 storage — 10 GB free, images/videos ke liye |
| ~$45/month Render budget | Neeche cost table dekho |

---

## 3. Quick start (5 steps)

### Step 1 — Is kit ko apne private repo me daalo
```bash
./scripts/new-repo.sh ../postiz-render     # folder copy + git init + commit
cd ../postiz-render
gh repo create <username>/postiz-render --private --source=. --remote=origin --push
```
Details: [`docs/01-github-private-repo.md`](docs/01-github-private-repo.md)

### Step 2 — Cloudflare R2 bucket banao (free storage)
Bucket + API token + custom domain + CORS. Poora steps: [`docs/03-storage.md`](docs/03-storage.md)

### Step 3 — Render par Blueprint deploy karo
```
Render Dashboard → New + → Blueprint → repo select → Apply
```
Render aapko 6 R2 values poochega (jo `sync: false` hain) — Step 2 ki values daal do.
Details + cost: [`docs/02-render-deploy.md`](docs/02-render-deploy.md)

> ⚠️ Agar `render.yaml` repo ke root me nahi hai (jaise `postiz-render/render.yaml`),
> to Blueprint ke `dockerfilePath` / `dockerContext` me prefix laga do —
> instructions file ke top par likhi hain.

### Step 4 — Pehla login + registration band karo
Deploy ke baad apne URL par jaao → signup karo → phir
`DISABLE_REGISTRATION=true` kar do (warna koi bhi account bana sakta hai).
Steps: [`docs/05-first-login-and-security.md`](docs/05-first-login-and-security.md)

### Step 5 — Social accounts jodo
Developer portal par apps banao (X, LinkedIn, Instagram, YouTube...) aur unki keys
Render ke Environment me daalo. Redirect URL hamesha:
`https://<aapka-url>/api/integrations/social/<provider>`
Details: [`docs/04-social-providers.md`](docs/04-social-providers.md)

---

## 4. Cost (Render, 2026)

| Service | Plan | ~Price/month |
|---|---|---|
| `postiz` (web) | `1c-2g` — 1 CPU / 2 GB | **$25** |
| `temporal` (private service) | `0.5c-512mb` | **$7** |
| `postiz-db` (Postgres) | `0.1c-256mb` | **~$6–7** |
| `temporal-db` (Postgres) | `0.1c-256mb` | **~$6–7** |
| `postiz-redis` (Key Value) | `free` (25 MB) | **$0** |
| Cloudflare R2 | 10 GB free | **$0** |
| **Total** | | **≈ $45/month** |

Sasta karna hai? [`docs/07-cost-and-alternatives.md`](docs/07-cost-and-alternatives.md)
(free Postgres ka 30-din wala trap, sasti VPS option, kya-kya kam kar sakte ho).

---

## 5. Files

| File | Kaam |
|---|---|
| `render.yaml` | Render Blueprint — saari services, env vars, DB/Redis |
| `Dockerfile` | Postiz wrapper image (nginx `$PORT` fix + backend 3000 par fix) |
| `entrypoint.sh` | URL auto-derive (`RENDER_EXTERNAL_URL`) + safety checks + start |
| `temporal/Dockerfile` | Temporal auto-setup wrapper (connection string → POSTGRES_* vars) |
| `temporal/entrypoint.sh` | Wahi parsing logic |
| `.env.example` | Saare env vars ka reference (Hinglish comments) |
| `docker-compose.local.yml` | Laptop par test karne ke liye (Render par zaroorat nahi) |
| `scripts/new-repo.sh` | Kit ko naye private repo me le jao |
| `scripts/secrets.sh` | JWT secret generator |
| `scripts/backup-db.sh` | Apne laptop se pg_dump backup |
| `.github/workflows/render-deploy.yml` | (Optional) push par Render deploy trigger |

---

## 6. Update kaise karein

**Postiz ka naya version:**
1. `Dockerfile` me `POSTIZ_VERSION` badlo (aur `docker-compose.local.yml` me image tag)
2. Deploy se pehle backup lo: `./scripts/backup-db.sh`
3. Commit + push → Render auto-deploy karega (Blueprint me `autoDeployTrigger: commit` hai)
4. Startup par Postiz khud `prisma db push` chalata hai → schema migrate ho jata hai

**Temporal ka naya version:** `temporal/Dockerfile` me `TEMPORAL_VERSION` badlo.
(Ek major jump se pehle backup lena, kyunki schema upgrade hote hain.)

---

## 7. Troubleshooting

Common errors + fix: [`docs/06-troubleshooting.md`](docs/06-troubleshooting.md)

Sabse pehle ye 3 cheezein dekho (90% problems yahin hoti hain):
1. **Logs** — Render Dashboard → service → Logs. `[postiz-render]` prefix wali lines startup ke bare me batati hain
2. **Memory** — Postiz ko 2 GB chahiye. 512 MB plan par OOM/crash hoga
3. **URLs** — `MAIN_URL` aur aapke browser ka URL bilkul same hone chahiye (OAuth isi par depend karta hai)

---

## 8. License / credits

- Postiz: [gitroomhq/postiz-app](https://github.com/gitroomhq/postiz-app) — **AGPL-3.0**. Self-host free hai, lekin agar aap ise kisi public service ke roop me bechte ho to AGPL ki shartein padho.
- Temporal: [temporalio/docker-builds](https://github.com/temporalio/docker-builds) — MIT
- Ye repo sirf deployment wrapper + docs deta hai; Postiz ka code modify nahi karta.
