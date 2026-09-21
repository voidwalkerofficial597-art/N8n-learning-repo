# 01 — Private GitHub repo banao

Render ko aapke repo se deploy karna hai, aur **repo private rakhna** bilkul
possible hai (Render private repos support karta hai).

---

## Option A — `gh` CLI se (fastest, 1 command)

```bash
cd /path/to/postiz-render          # is kit wala folder
gh repo create <username>/postiz-render --private --source=. --remote=origin --push
```

`gh` login nahi hai? `gh auth login` chala lo (browser se ek baar).

---

## Option B — Website se

1. https://github.com/new par jaao
2. **Repository name:** `postiz-render`
3. **Visibility:** ✅ **Private** (ye important hai)
4. ❌ README/gitignore/license — kuch bhi add mat karo (repo khali rakho)
5. **Create repository**

Phir apne laptop par:

```bash
cd /path/to/postiz-render
git init -b main
git add -A
git commit -m "Postiz on Render: deploy kit"
git remote add origin https://github.com/<username>/postiz-render.git
git push -u origin main
```

---

## Agar ye kit kisi doosre repo ke andar hai (jaise `N8n-learning-repo/postiz-render`)

Do tarike:

**1. Script se (recommended):**
```bash
cd N8n-learning-repo/postiz-render
./scripts/new-repo.sh ~/postiz-render        # files copy + git init + commit
cd ~/postiz-render
gh repo create <username>/postiz-render --private --source=. --remote=origin --push
```

**2. Manual copy:**
```bash
mkdir ~/postiz-render && cd ~/postiz-render
git init -b main
cp -r /path/to/N8n-learning-repo/postiz-render/{Dockerfile,entrypoint.sh,render.yaml,.env.example,.dockerignore,.gitignore,docker-compose.local.yml,README.md,docs,scripts,temporal,.github} .
git add -A && git commit -m "Postiz on Render: deploy kit"
```

> `render.yaml` **repo ke root me** rakhna sabse aasan hai. Agar aap use subfolder
> me rakhte ho, to Render me "Blueprint Path" set karna padega aur `render.yaml`
> ke andar `dockerfilePath`/`dockerContext` me prefix lagana padega (file ke top
> par likha hai).

---

## Render ko repo ka access do

1. Render Dashboard → **Account Settings → GitHub** (ya Blueprint banate waqt)
2. Render ka GitHub App install/authorize karo
3. **Important:** "Only select repositories" me apna `postiz-render` repo select karo
   (private repo tabhi dikhega jab Render ko explicit access doge)

---

## Kya commit NAHI karna

- `.env` (`.gitignore` me already hai)
- Cloudflare keys, JWT secret, database URL — ye sab **Render Dashboard → Environment** me jaate hain, git me nahi
- `backups/` folder

---

## Repo structure jo Render expect karta hai

```
postiz-render/
├── render.yaml          ← Render isi ko padhta hai (root me hona chahiye)
├── Dockerfile           ← Postiz wrapper image
├── entrypoint.sh
└── temporal/
    ├── Dockerfile
    └── entrypoint.sh
```

Ab aage: [`02-render-deploy.md`](02-render-deploy.md)
