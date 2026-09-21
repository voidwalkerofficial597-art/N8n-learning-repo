# 07 — Cost, sasti tricks, aur alternatives

## Current setup ka kharcha (Render, 2026)

| Resource | Plan | ~$/month |
|---|---|---|
| `postiz` web service | `1c-2g` (1 CPU / 2 GB) | 25 |
| `temporal` private service | `0.5c-512mb` | 7 |
| `postiz-db` (Postgres) | `0.1c-256mb` | ~6–7 |
| `temporal-db` (Postgres) | `0.1c-256mb` | ~6–7 |
| `postiz-redis` (Key Value) | `free` (25 MB) | 0 |
| Cloudflare R2 | 10 GB free | 0 |
| **Total** | | **≈ $45/mo** |

Bandwidth: 100 GB/mo included (uske baad $0.10/GB). Disk: $0.25/GB/mo (agar
Render disk use karo).

---

## Paise bachane ke tarike (badle me kya milega)

### 1. Temporal Cloud use karo (2 services kam)
Postiz me native support hai:
```
TEMPORAL_ADDRESS   = <namespace>.<region>.temporal.io:7233
TEMPORAL_TLS       = true
TEMPORAL_API_KEY   = <key>
```
Isse apna `temporal` private service + `temporal-db` **dono** hata sakte ho
(~$13-14/mo bachat), lekin Temporal Cloud ka apna usage-based bill aayega
(free trial credits milte hain, phir paid).

### 2. Dono databases ek hi Postgres instance me
Render Postgres me multiple databases bana sakte ho:
1. Render → `postiz-db` → **Connect → PSQL Command** copy karo
2. Us command se connect karke chalao:
   ```sql
   CREATE DATABASE temporal;
   CREATE DATABASE temporal_visibility;
   ```
3. `temporal` service me `TEMPORAL_DATABASE_URL` ko usi instance ka connection
   string do aur `temporal-db` service delete kar do → **~$6-7/mo bachat**
   (trade-off: connection limits shared, ek hi jagah failure)

### 3. Key Value paid karna **tabhi** jab errors aayein
Free 25 MB se bahut kaam chal jata hai. `OOM command not allowed` / random
logouts aayein to `256mb` (~$10/mo) par jao.

### 4. Postiz plan chhota (⚠️ risky)
`0.5c-512mb` ($7) par Postiz **crash/OOM** hota hai — Node ke 3 process + nginx
ke liye 512 MB kam hai. Sirf test ke liye.

---

## ⚠️ Free tier ka sach

Render free tier Postiz ke liye **kaam nahi karega**:

| Free tier | Problem |
|---|---|
| Free web service | 15 min inactivity par **spin down** → Temporal worker band → **scheduled posts nahi chalenge** |
| Free web service | 512 MB RAM, disk nahi, shell nahi, 750 instance-hours/mo |
| Free Postgres | **30 din baad database delete** ho jata hai (data gaya!) |
| Free Key Value | 25 MB, persistence off |
| Private services / workers | free plan me hi **available nahi** (Temporal ke liye paid zaroori) |

Yani: agar aapka goal "scheduled posts bahut sahi se chalein" hai, to **kam se kam
~$32/mo** (postiz 1c-2g + 2 DBs + free redis) lagenge. Test ke liye free tier
theek hai, production ke liye nahi.

---

## Alternatives (agar $45/mo zyada lage)

| Option | Cost | Pros | Cons |
|---|---|---|---|
| **VPS + official docker-compose** (Hetzner/Contabo/DigitalOcean) | **$5–10/mo** | Poora stack (Postiz + PG + Redis + Temporal + ES), koi service limit nahi | Server khud maintain karna (updates, SSL, backups), Docker sikhna padega |
| **Coolify / Dokploy on VPS** | **$5–10/mo** + UI free | Render jaisa UI, git push deploy, one-click Postiz | Same VPS maintenance |
| **Railway** | ~$10–20/mo usage-based | Simple, Temporal template available | Usage-based bill unpredictable |
| **Postiz Cloud (official hosted)** | plan-dependent | Zero maintenance | Self-host nahi hai, data unke paas |
| **Render (ye setup)** | ~$45/mo | Managed, auto-deploy, private networking, backups | Sabse mehnga option |

**Seedha comparison:** agar aapko sirf Postiz chahiye aur maintenance ka time nahi
hai → Render (ye kit). Agar paisa matter karta hai aur thoda seekhne ko ready ho →
**$6 ka VPS + official `postiz-docker-compose` = 4x sasta**.

---

## Render par kharcha kam karne ka checklist

- [ ] R2 use karo (Render disk ki jagah) → disk cost zero
- [ ] Key Value `free` hi rakho jab tak error na aaye
- [ ] Temporal Cloud ya shared DB (upar wale tricks)
- [ ] Workspace **Hobby** ($0) hi rakho — Pro ($25) ki zaroorat nahi
- [ ] Render Dashboard → **Billing → Spend limits** set kar do (surprise bill se bachne ke liye)
- [ ] Bandwidth monitor karo (100 GB included)

---

## Reference

- Render pricing: https://render.com/pricing
- Render compute plans: https://render.com/docs/compute-plans
- Render free tier limitations: https://render.com/docs/free
