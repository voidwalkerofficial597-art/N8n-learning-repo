# Postiz on Render 🚀

[Postiz](https://postiz.com) (open-source social media scheduler) ko **Render** par self-host karne ka ready-made kit — ek `render.yaml` Blueprint se poora stack ek click mein ban jaata hai.

[![Deploy to Render](https://render.com/images/deploy-to-render-button.svg)](https://render.com/deploy?repo=https://github.com/YOUR_GITHUB_USERNAME/postiz-render)

> Button use karne se pehle `YOUR_GITHUB_USERNAME` ko apne GitHub username se replace karo (Step 1 ke baad).

---

## Ye kit kya banata hai?

```
                 Internet
                    │  https://postiz.onrender.com
                    ▼
┌───────────────────────────────────────────┐
│  postiz  (Web Service, Docker, 1c-2g)      │
│  nginx:5000 ─► Next.js frontend :4200      │
│            └─► Nest backend    :3000 /api  │
│                orchestrator (Temporal wkr) │
│  disk: /uploads (5 GB) ── media files      │
└──────┬───────────────┬───────────────┬─────┘
       │ private net   │               │
       ▼               ▼               ▼
┌─────────────┐ ┌────────────┐ ┌──────────────────────────┐
│ postiz-db   │ │postiz-redis│ │ postiz-temporal          │
│ Postgres 17 │ │ Key Value  │ │ (Private Service, Docker)│
│ 3 databases │ │ (free)     │ │ Temporal 1.28 gRPC :7233 │
└─────────────┘ └────────────┘ └────────────┬─────────────┘
       ▲                                     │
       └─────────── temporal + temporal_visibility DBs
```

| Resource | Render type | Kaam |
|---|---|---|
| `postiz` | Web Service (Docker) | Postiz app — official image `ghcr.io/gitroomhq/postiz-app` + chhota sa Render entrypoint |
| `postiz-temporal` | Private Service (Docker) | Temporal workflow engine (Postiz v2.12+ ke liye **zaroori**) |
| `postiz-redis` | Key Value | Redis — cache, rate-limit, OAuth state |
| `postiz-db` | Postgres | Ek instance, teen databases: `postiz`, `temporal`, `temporal_visibility` |

Sab kuch **ek region** (default: `singapore`) mein hai taaki private network par baat kar sakein.

---

## 💰 Kharcha (honest estimate)

Postiz **Render ke free tier par nahi chalta** — app ko ~1.5 GB RAM chahiye, free/512 MB instances par OOM ho jaata hai.

| Resource | Plan (default) | ~Price / month |
|---|---|---|
| `postiz` web service | `1c-2g` (1 CPU, 2 GB) | $25 |
| `postiz-temporal` private service | `0.5c-512mb` | $7 |
| `postiz-db` Postgres | `0.1c-256mb` | $6 |
| `postiz-uploads` disk | 5 GB | $1.25 |
| `postiz-redis` Key Value | `free` (25 MB) | $0 |
| **Total** | | **≈ $39 / month** |

Sasta karne ke options:
- Postgres `plan: free` kar sakte ho **sirf trial ke liye** — Render ka free Postgres **30 din baad expire ho kar delete ho jaata hai** (data bhi). Production ke liye paid rakho.
- Ek workspace mein sirf **ek** free Postgres aur **ek** free Key Value ho sakta hai.
- Render par card add karna padega (paid plans ke liye).

---

## ✅ Prerequisites

1. GitHub account
2. Render account → https://dashboard.render.com (GitHub se sign-in karo, aasaan rahega)
3. Local machine par `git` + [GitHub CLI (`gh`)](https://cli.github.com) — sirf Step 1 ke script ke liye (manual option bhi hai)

---

## Step 1 — GitHub par PRIVATE repo banao

Is folder ko ek **alag private repo** banana hai (Render Blueprint repo root mein `render.yaml` dhoondta hai).

### Option A — script (recommended)

```bash
cd postiz-render
chmod +x scripts/create-private-repo.sh
./scripts/create-private-repo.sh            # repo: <tumhara-username>/postiz-render (private)
# ya custom naam:  ./scripts/create-private-repo.sh mera-postiz
```

Script: `gh auth login` (browser) → folder ki clean copy → `git init` → **private** repo create → push.
Windows par **Git Bash** ya **WSL** mein chalao.

### Option B — manually (bina gh ke)

1. https://github.com/new → Repository name `postiz-render` → **Private** select karo → *Create repository* (README/gitignore mat add karo).
2. Terminal mein:
   ```bash
   cd postiz-render
   git init
   git add -A
   git commit -m "Postiz on Render: initial setup"
   git branch -M main
   git remote add origin https://github.com/<username>/postiz-render.git
   git push -u origin main
   ```

> ⚠️ Is folder ko kisi **public** repo mein mat rakho agar tum baad mein isme koi secret daal do. Waise render.yaml mein koi secret nahi hai (JWT Render khud generate karta hai, DB/Redis credentials Render inject karta hai).

---

## Step 2 — Render par deploy karo

1. https://dashboard.render.com/blueprints → **New Blueprint Instance**
2. GitHub connect karo (pehli baar) aur Render ko `postiz-render` repo ka access do
   (*Only select repositories* → `postiz-render`).
3. Repo select karo → Render `render.yaml` padhega aur 4 resources dikhayega → **Apply**.
4. Wait karo ⏳ **10–15 minute**:
   - Postgres + Key Value turant ban jaate hain
   - `postiz-temporal` build → start → `temporal` / `temporal_visibility` DBs banata hai → schema setup (2–3 min)
   - `postiz` build → start → Temporal ka wait karta hai → `prisma db push` → app up
5. `postiz` service ka URL kholo: `https://postiz-XXXX.onrender.com` 🎉

**Logs dekhne ke liye:** Dashboard → service → *Logs*. Pehle boot par `[render-entrypoint] Waiting for Temporal...` normal hai.

---

## Step 3 — Pehla login (admin account)

1. URL kholo → **Register** karo (email + password).
2. Bas — ye account owner hai. `DISABLE_REGISTRATION=true` already set hai, isliye **pehle account ke baad sign-up page band ho jaata hai** (Postiz first user ko allow karta hai jab tak 0 organizations hain).
3. Team members chahiye? Postiz ke andar se **Settings → Team → Add Member → Copy Link** karo (invite link se woh join kar sakte hain), ya temporarily `DISABLE_REGISTRATION=false` karo.

Email verification **off** hai (koi `RESEND_API_KEY` nahi) — login turant ho jaata hai.

---

## Step 4 — Social accounts connect karo (API keys)

Postiz har platform ke liye **tumhari apni developer app** use karta hai. Jo platform chahiye, uska client id/secret lo aur Render mein daalo:

1. Render Dashboard → `postiz` → **Environment** → *Add Environment Variable* (ya **Add from .env** aur `providers.env.example` se lines paste karo).
2. Save → service auto-redeploy hota hai (~2 min).
3. Postiz mein **Add Channel** → platform select → OAuth se connect.

Har platform ki developer app mein **Redirect / Callback URL** ye dalo:

```
https://<tumhara-postiz-domain>/integrations/social/<provider>
```
e.g. `https://postiz-xxxx.onrender.com/integrations/social/linkedin`

| Platform | Env vars | Guide |
|---|---|---|
| X (Twitter) | `X_API_KEY`, `X_API_SECRET` | https://docs.postiz.com/self-host/providers/x |
| LinkedIn | `LINKEDIN_CLIENT_ID`, `LINKEDIN_CLIENT_SECRET` | https://docs.postiz.com/self-host/providers/linkedin |
| Facebook + Instagram | `FACEBOOK_APP_ID`, `FACEBOOK_APP_SECRET` | https://docs.postiz.com/self-host/providers/facebook |
| Threads | `THREADS_APP_ID`, `THREADS_APP_SECRET` | https://docs.postiz.com/self-host/providers/threads |
| YouTube | `YOUTUBE_CLIENT_ID`, `YOUTUBE_CLIENT_SECRET` | https://docs.postiz.com/self-host/providers/youtube |
| TikTok | `TIKTOK_CLIENT_ID`, `TIKTOK_CLIENT_SECRET` | https://docs.postiz.com/self-host/providers/tiktok |
| Pinterest | `PINTEREST_CLIENT_ID`, `PINTEREST_CLIENT_SECRET` | https://docs.postiz.com/self-host/providers/pinterest |
| Reddit | `REDDIT_CLIENT_ID`, `REDDIT_CLIENT_SECRET` | https://docs.postiz.com/self-host/providers/reddit |
| AI features | `OPENAI_API_KEY` | — |

Poori list: [`providers.env.example`](./providers.env.example) aur https://docs.postiz.com/self-host/configuration/reference

> Ye keys **jaan-boojh kar** `render.yaml` mein nahi hain: dashboard mein daalo, taaki Blueprint sync kabhi unhe overwrite na kare aur repo mein secrets na aayein.

---

## 🌐 Custom domain

1. Render → `postiz` → **Settings → Custom Domains** → domain add karo (CNAME instructions milenge).
2. **Environment** → `MAIN_URL=https://postiz.tumharadomain.com` add karo → save (redeploy).
3. Social apps ke callback URLs bhi naye domain par update karo.

Bina `MAIN_URL` ke entrypoint automatically `RENDER_EXTERNAL_URL` (`*.onrender.com`) use karta hai.

> ℹ️ **`*.onrender.com` par login kaise chalta hai:** Postiz apni auth cookie `FRONTEND_URL` ke *root domain* par set karta hai. `onrender.com` [Public Suffix List](https://publicsuffix.org) mein hai, isliye stock image `Domain=.onrender.com` cookie set karta jo browser reject kar deta (login loop). `postiz/patch-cookie-domain.sh` build ke waqt ye fix karta hai — cookie poore hostname (`postiz-xxxx.onrender.com`) par set hoti hai. Custom domain par behaviour bilkul same rehta hai jaisa upstream ka.

---

## ⬆️ Postiz update karna

Version pinned hai taaki koi surprise breaking update na aaye.

1. Latest release dekho: https://github.com/gitroomhq/postiz-app/releases
2. `render.yaml` mein `POSTIZ_VERSION` badlo (e.g. `v2.24.0`) → commit → push → Render auto-deploy.
   *Ya* Dashboard → `postiz` → Environment → `POSTIZ_VERSION` edit → **Manual Deploy → Clear build cache & deploy**.
3. DB migrations start par khud chalti hain (`prisma db push`).

Temporal ke liye `TEMPORAL_VERSION` same tarah (zaroorat kam padti hai; Postiz ke official compose se match rakho).

---

## 💾 Data & backups

| Data | Kahan | Backup |
|---|---|---|
| Posts, users, tokens | `postiz-db` (Postgres) | Render paid Postgres: daily backups + point-in-time recovery (dashboard → Recovery) |
| Uploaded media | `postiz-uploads` disk (`/uploads`) | Render disk snapshots (dashboard → Disk → Snapshots) |
| Temporal workflows | `postiz-db` (`temporal*` DBs) | Same instance |
| Redis | `postiz-redis` | Cache only — loss safe hai |

Media ko disk ke bajaye **Cloudflare R2** par rakhna ho to `providers.env.example` ka Cloudflare block dekho (`STORAGE_PROVIDER=cloudflare`).

> Disk waale web service **ek instance** tak limited hote hain aur zero-downtime deploy nahi hota (deploy ke waqt ~1–2 min downtime). Postiz single-instance ke liye ye theek hai.

---

## 🔧 Troubleshooting

| Symptom | Reason / Fix |
|---|---|
| `postiz` deploy fail: **Out of memory** / instance restart loop | Plan chhota hai. `1c-2g` minimum; heavy use par `2c-4g`. |
| Logs: `Waiting for Temporal ... still not reachable` | `postiz-temporal` abhi start ho raha hai (first boot 2–4 min) ya crash hua. Uske logs dekho. |
| Temporal logs: `could not create database` | DB user ko CREATE DATABASE permission nahi mili. Dashboard → `postiz-db` → **Connect → PSQL** → `CREATE DATABASE temporal; CREATE DATABASE temporal_visibility;` → Temporal redeploy. |
| Temporal logs: `too many connections` / Postgres slow | `0.1c-256mb` Postgres chhota hai (97 connections, 256 MB). `postiz-db` ka plan `0.5c-1g` (~$19) kar do, ya Temporal ko alag Postgres instance do (`POSTGRES_SEEDS`/`POSTGRES_USER`/`POSTGRES_PWD`/`ADMIN_DB` env vars badal kar). |
| Login ke baad blank page / API errors | `NEXT_PUBLIC_BACKEND_URL` galat. Custom domain use kar rahe ho to `MAIN_URL` set karo (Step Custom domain). |
| Register/login ke baad wapas `/auth` par aa jaata hai (loop) | Cookie set nahi ho rahi. `*.onrender.com` par ye tabhi hota hai jab `postiz/patch-cookie-domain.sh` apply nahi hua — build logs mein `[cookie-patch] OK` dhoondo. Custom domain par `MAIN_URL` sahi hona chahiye (https, bina trailing slash). |
| Build fail: `[cookie-patch] ERROR` | Naye Postiz version mein file layout badla. Custom domain use karo + env `SKIP_COOKIE_PATCH=true`, ya issue report karo. |
| Images upload hoti hain par dikhti nahi | Disk mount `/uploads` check karo (Dashboard → Disk). `UPLOAD_DIRECTORY=/uploads` hona chahiye. |
| Register page: "Registration is disabled" | Expected hai pehle user ke baad. Naya user chahiye → invite karo ya `DISABLE_REGISTRATION=false`. |
| Free Postgres 30 din baad gayab | Free Postgres expire ho gaya. Paid plan use karo (`0.1c-256mb`). |
| OAuth connect par provider error | Callback URL mismatch. Format: `https://<domain>/integrations/social/<provider>`. |
| Temporal ko debug karna hai | Dashboard → `postiz-temporal` → **Shell** → `temporal workflow list --address 127.0.0.1:7233` |

Temporal ki **Web UI** jaan-boojh kar include nahi ki (public web service par bina auth ke risky hai). Chahiye to `temporalio/ui` image ko `runtime: image` web service ki tarah add karo with `TEMPORAL_ADDRESS=<postiz-temporal host>:7233` aur OIDC auth env vars — ya sirf zaroorat par suspend/resume karo.

---

## 🔐 Security notes

- Ye `render.yaml` **koi secret store nahi karta**. `JWT_SECRET` Render generate karta hai; DB/Redis creds Render inject karta hai.
- Postgres by default public internet se (credentials ke saath) accessible hai. Sirf Render services se access chahiye to Dashboard → `postiz-db` → **Access Control** → sab IP ranges hata do (internal connections chalte rahenge).
- `postiz-temporal` private service hai — bahar se reachable nahi.
- Postiz updates regularly follow karo (security fixes).

---

## 🧪 Local testing (optional)

Local par pehle try karna ho to Postiz ka official docker-compose use karo — wahi versions yahan pinned hain:
https://github.com/gitroomhq/postiz-docker-compose

---

## 📁 Files

```
postiz-render/
├── render.yaml                     # Render Blueprint — poora stack
├── postiz/
│   ├── Dockerfile                  # official image + entrypoint + cookie patch
│   ├── entrypoint.sh               # URLs derive, Temporal address, wait-for deps, start
│   ├── patch-cookie-domain.sh      # *.onrender.com par login cookies theek karta hai (build time)
│   └── .dockerignore
├── temporal/
│   ├── Dockerfile                  # temporalio/auto-setup + psql
│   ├── entrypoint.sh               # temporal DBs create, then official auto-setup
│   ├── dynamicconfig/render-sql.yaml
│   └── .dockerignore
├── scripts/
│   ├── create-private-repo.sh      # Step 1 automation
│   └── validate-render-yaml.py     # render.yaml ko Render ke official schema se check karo
├── .github/workflows/validate.yml  # har push par validation
├── providers.env.example           # optional env vars (social keys etc.) — reference
├── .gitattributes                  # LF line endings (Windows safe)
└── .gitignore
```

`render.yaml` change karne ke baad local check:

```bash
pip install jsonschema pyyaml
python scripts/validate-render-yaml.py render.yaml
```

---

## Credits

- [Postiz](https://github.com/gitroomhq/postiz-app) — AGPL-3.0, by Gitroom
- [Temporal](https://temporal.io)
- Render docs: [Blueprints](https://render.com/docs/blueprint-spec), [Docker](https://render.com/docs/docker), [Disks](https://render.com/docs/disks)
