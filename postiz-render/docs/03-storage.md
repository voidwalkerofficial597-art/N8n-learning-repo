# 03 — Storage: uploaded images/videos kahan jaayein

## Problem

Render ka container filesystem **ephemeral** hai. Matlab: har **redeploy, restart
ya crash** par `/uploads` folder khali ho jata hai — user ke upload kiye gaye
images/videos gayab. Isliye Postiz ke liye permanent storage chahiye.

Do options:

| Option | Cost | Recommendation |
|---|---|---|
| **Cloudflare R2** | **Free** (10 GB storage, zero egress) | ✅ Default (render.yaml me set hai) |
| Render persistent disk | ~$0.25/GB/mo (paid service only) | Simple, lekin paisa aur single-instance lock-in |

---

## A) Cloudflare R2 (free) — setup

### 1. Bucket banao
1. [Cloudflare Dashboard → R2](https://dash.cloudflare.com/r2/overview) → login/signup
2. **Create bucket**
3. Name: `postiz` · Location: **Automatic** · Default storage class: **Standard** → Create

### 2. API token banao
1. R2 → **API** dropdown → **Manage API tokens** → **Create API token**
2. Type: **Account API token**
3. Permissions: **Object Read & Write**
4. Specify bucket(s): apna `postiz` bucket select karo
5. Create → ab ye 3 cheezein copy karo:

```
Account ID          -> CLOUDFLARE_ACCOUNT_ID
Access Key ID       -> CLOUDFLARE_ACCESS_KEY
Secret Access Key   -> CLOUDFLARE_SECRET_ACCESS_KEY
```

Bucket name bhi yaad rakho → `CLOUDFLARE_BUCKETNAME=postiz`

### 3. Public URL (custom domain) + CORS
1. Bucket → **Settings → Custom Domains → Connect Domain**
2. Apna subdomain do (jaise `media.yourdomain.com`) — free Cloudflare domain bhi chalega
   (R2 jo `r2.dev` URL deta hai wo rate-limited hai, isliye custom domain better hai)
3. Wo URL copy karo → `CLOUDFLARE_BUCKET_URL="https://media.yourdomain.com"`
4. Usi page par **CORS policy** edit karke ye JSON daalo:

```json
[
  {
    "AllowedOrigins": [
      "https://postiz-abcd.onrender.com",
      "https://postiz.yourdomain.com",
      "http://localhost:4200"
    ],
    "AllowedMethods": ["GET", "POST", "HEAD", "PUT", "DELETE"],
    "AllowedHeaders": ["Authorization", "x-amz-date", "x-amz-content-sha256", "content-type"],
    "ExposeHeaders": ["ETag", "Location"],
    "MaxAgeSeconds": 3600
  }
]
```

> `AllowedOrigins` me apne asli Postiz URL(s) daalna — warna browser upload block karega.

### 4. Render me values daalo
Render Dashboard → `postiz` service → **Environment → Add Environment Variable**:

```
STORAGE_PROVIDER            = cloudflare
CLOUDFLARE_ACCOUNT_ID       = <account id>
CLOUDFLARE_ACCESS_KEY       = <access key>
CLOUDFLARE_SECRET_ACCESS_KEY= <secret key>
CLOUDFLARE_BUCKETNAME       = postiz
CLOUDFLARE_BUCKET_URL       = https://media.yourdomain.com
CLOUDFLARE_REGION           = auto
```

(Blueprint banate waqt ye prompt me bhi pooch liya jayega.)

Phir **Save and deploy** → Postiz → Settings → Media / ek post me image upload
karke test karo.

**Region value:** Cloudflare dashboard jo region dikhata hai (`auto`, `wnam`, `enam`,
`weur`, `eeur`, `apac`) — `auto` safe hai.

---

## B) Render persistent disk (paid, simple)

1. `render.yaml` me `postiz` service ke andar disk block uncomment karo:
   ```yaml
   disk:
     name: postiz-uploads
     mountPath: /uploads
     sizeGB: 5
   ```
2. `STORAGE_PROVIDER` ko `local` kar do
3. Upar wale R2 vars hata do (ya khaali chhod do)

**Dhyan do:**
- Disk sirf **paid** service plans par milta hai (free web service par nahi)
- **Disk wale service ko scale nahi kar sakte** (Render limitation) — single instance hi rahega
- Disk lagane ke baad Render deploy ke waqt service ko restart karega, data safe rahega

---

## Optional: public URL se files serve karna

Agar aap chahte ho ki uploads Cloudflare ke public domain se serve hon (aur
Postiz ke through na jaayein), to ye env var bhi add kar do:

```
NEXT_PUBLIC_UPLOAD_STATIC_DIRECTORY = https://media.yourdomain.com
```

(Aksar zaroorat nahi padti — bina iske bhi kaam chalta hai.)

---

## Verify

1. Postiz me login → koi bhi post banao → image attach karo
2. Cloudflare R2 bucket → **Objects** me file dikhni chahiye
3. Post preview me image load ho rahi ho
4. Render par `postiz` service **redeploy** karo → image abhi bhi dikhani chahiye
   (ye asli test hai — local storage par ye step fail hota hai)
