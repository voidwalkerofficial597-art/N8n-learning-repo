# 05 — Pehla login + security

## 1. Pehla account banao

1. Apna Postiz URL kholo (`https://postiz-abcd.onrender.com`)
2. **Register / Sign up** karo — pehla user automatically **owner/super-admin** hota hai
3. Login karke Settings → **Organization** me naam etc. set kar lo

> Email verification: agar `RESEND_API_KEY` set nahi hai to users automatically
> activated ho jaate hain (official `.env.example` kehta hai: "If this variable
> exists, user activation is required"). Chhote setup me ise khaali hi rakho.

---

## 2. Registration BAND karo (important!)

Default me `DISABLE_REGISTRATION=false` hai — matlab **jo bhi aapka URL jaanta hai,
account bana sakta hai**.

1. Render Dashboard → `postiz` service → **Environment**
2. `DISABLE_REGISTRATION` → value `false` se **`true`** karo
3. **Save and deploy** (ya "Save, rebuild, and deploy")
4. Logout karke check karo — signup page par naya account nahi ban paana chahiye

Baad me team member add karna ho to:
- Temporarily `DISABLE_REGISTRATION=false` karo → account banao → wapas `true` kar do, **ya**
- Postiz ke Settings → Team / Client groups se invite link bhejo

---

## 3. Secrets aur env vars (rules)

**Git me kabhi na daalo:** `JWT_SECRET`, `DATABASE_URL`, Cloudflare keys, provider
secrets. Ye sab Render Dashboard → Environment me jaate hain.

**`JWT_SECRET` rotate karne ka matlab:** sabhi users logout ho jayenge aur
pending sessions invalid ho jayenge. Rotate karna ho to soch samajh kar karo
(secret change → redeploy).

**`generateValue: true`** — JWT secret Render ne khud generate kiya hai, wo
Dashboard me visible hai (reveal karke copy kar sakte ho).

**Env var save karne ke 3 options:**

| Option | Kab use karo |
|---|---|
| Save, rebuild, and deploy | Dockerfile/blueprint badla ho |
| **Save and deploy** | Sirf env var badla ho (fast — rebuild nahi hota) |
| Save only | Abhi deploy nahi chahiye |

---

## 4. Access control ka basic checklist

- [ ] `DISABLE_REGISTRATION=true`
- [ ] `postiz-db` / `temporal-db` ka **IP allow list** ya to khali hai, ya usme sirf
      apna IP hai (Render → database → Settings)
- [ ] `postiz-redis` ka `ipAllowList: []` (private-only) hi rehne do
- [ ] Render account par **2FA** on karo (Account Settings → Two-Factor Auth)
- [ ] GitHub repo **private** hai
- [ ] Kisi ko Postiz API key do to Settings → Developers me scope/expiry set karo
- [ ] Custom domain + HTTPS (Render khud Let's Encrypt certificate lagata hai)

---

## 5. Backups (hafta me ek baar)

```bash
export POSTGRES_EXTERNAL_URL='postiz-db ka External Connection URL'
./scripts/backup-db.sh
```

- URL kahan se: Render → `postiz-db` → **Connect → External**
- External connection tabhi chalega jab us IP ko DB ke allow list me ho (Render
  default me sab allow karta hai jab tak `ipAllowList: []` na karo)
- Render khud bhi daily backup rakhta hai (paid plans), lekin apna dump rakhna safe hai
- **Upgrade se pehle** backup zaroor lo

---

## 6. Team use kar raha hai? (optional)

Postiz me multi-tenant support hai:
- **Client groups** — ek client ke channels alag group me
- **Invite links** — client khud apna account jodta hai

Docs: https://docs.postiz.com/general/channels/customers
