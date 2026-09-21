# 04 — Social media accounts jodna (OAuth apps)

Postiz tab tak kuch post nahi kar sakta jab tak aap **har platform ka apna
developer app** na bana lo. Ye platforms Postiz ko apni API use karne dete hain
sirf registered apps ke through.

## Ek hi rule sabke liye

Har provider ke developer portal me app banate waqt **Redirect / Callback URI**
ye hota hai:

```
https://<aapka-postiz-url>/api/integrations/social/<provider>
```

Examples:
```
https://postiz-abcd.onrender.com/api/integrations/social/x
https://postiz-abcd.onrender.com/api/integrations/social/linkedin
https://postiz-abcd.onrender.com/api/integrations/social/instagram
https://postiz-abcd.onrender.com/api/integrations/social/youtube
https://postiz-abcd.onrender.com/api/integrations/social/facebook
https://postiz-abcd.onrender.com/api/integrations/social/threads
https://postiz-abcd.onrender.com/api/integrations/social/tiktok
https://postiz-abcd.onrender.com/api/integrations/social/pinterest
https://postiz-abcd.onrender.com/api/integrations/social/reddit
https://postiz-abcd.onrender.com/api/integrations/social/discord
https://postiz-abcd.onrender.com/api/integrations/social/slack
https://postiz-abcd.onrender.com/api/integrations/social/github
```

> ⚠️ Custom domain baad me laga rahe ho? Pehle custom domain laga lo, phir apps
> banao — warna redirect URI dobara update karni padegi.

**Har provider ka exact path Postiz ke docs me verify kar lena:**
https://docs.postiz.com/self-host/providers/overview

---

## Keys kahan jaati hain

Developer portal se keys copy karo → Render Dashboard → `postiz` service →
**Environment** → ye key-values add karo → **Save and deploy**.

| Platform | Env vars | Developer portal |
|---|---|---|
| X (Twitter) | `X_API_KEY`, `X_API_SECRET` | https://developer.x.com |
| LinkedIn | `LINKEDIN_CLIENT_ID`, `LINKEDIN_CLIENT_SECRET` | https://www.linkedin.com/developers/apps |
| Facebook Page | `FACEBOOK_APP_ID`, `FACEBOOK_APP_SECRET` | https://developers.facebook.com/apps |
| Instagram | `FACEBOOK_APP_ID`, `FACEBOOK_APP_SECRET` (same Meta app) | https://developers.facebook.com/apps |
| Threads | `THREADS_APP_ID`, `THREADS_APP_SECRET` | https://developers.facebook.com/apps |
| YouTube | `YOUTUBE_CLIENT_ID`, `YOUTUBE_CLIENT_SECRET` | https://console.cloud.google.com/apis/credentials |
| TikTok | `TIKTOK_CLIENT_ID`, `TIKTOK_CLIENT_SECRET` | https://developers.tiktok.com |
| Pinterest | `PINTEREST_CLIENT_ID`, `PINTEREST_CLIENT_SECRET` | https://developers.pinterest.com |
| Reddit | `REDDIT_CLIENT_ID`, `REDDIT_CLIENT_SECRET` | https://www.reddit.com/prefs/apps |
| GitHub | `GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET` | https://github.com/settings/developers |
| Discord | `DISCORD_CLIENT_ID`, `DISCORD_CLIENT_SECRET`, `DISCORD_BOT_TOKEN_ID` | https://discord.com/developers/applications |
| Slack | `SLACK_ID`, `SLACK_SECRET`, `SLACK_SIGNING_SECRET` | https://api.slack.com/apps |
| Mastodon | `MASTODON_URL`, `MASTODON_CLIENT_ID`, `MASTODON_CLIENT_SECRET` | apne instance ki `/settings/applications` |
| Dribbble | `DRIBBBLE_CLIENT_ID`, `DRIBBBLE_CLIENT_SECRET` | https://dribbble.com/account/applications |

Sabhi providers ek saath set karne ki zaroorat nahi — jo chahiye wahi karo.
Bina keys ke bhi Postiz chalta rahega, bas us platform ka "Add channel" button
kaam nahi karega.

---

## Platform-specific tips (jo aksar atakte hain)

**X (Twitter)**
- Free tier me sirf **read** milta hai; **post** karne ke liye paid API tier chahiye
- App settings me OAuth 1.0a + OAuth 2.0 dono set karo, permissions = **Read and write**

**LinkedIn**
- App me 2 products add karne padte hain: **Share on LinkedIn** aur
  **Sign In with LinkedIn using OpenID Connect**
- Verified company page zaroori ho sakti hai (warna sirf personal profile post karega)

**Instagram**
- Sirf **Business/Creator** account + Facebook Page linked hona chahiye
- Instagram Graph API ke permissions (instagram_content_publish etc.) ke liye
  Meta ka **App Review** chahiye — ye process kuch din leta hai
- Apna hi account use kar rahe ho to Meta app "Development" mode me bhi apne
  test users se kaam chala sakte ho

**Threads**
- Meta me alag app banani padti hai (Threads use case wala)

**YouTube**
- Google Cloud project → **OAuth consent screen** bharo (External + Test users)
- Scopes: `youtube.upload`, `youtube.readonly`
- "Testing" mode me refresh token 7 din me expire ho jata hai — production ke liye publish karna padta hai

**TikTok**
- App review ke bina sirf sandbox users par kaam karta hai
- Direct post ke liye `video.publish` scope chahiye (audit ke baad milta hai)

**Reddit / Discord / Slack / GitHub** — inme sirf redirect URI sahi hona chahiye,
process simple hai.

**Mastodon** — koi central app nahi. Jis instance par account hai
(`https://mastodon.social` etc.) uske preferences me app banao aur `MASTODON_URL`
usi instance ka rakho.

---

## Test kaise karein

1. Postiz → **Add Channel** → platform select karo
2. Popup me provider ka consent screen aayega → approve
3. Channel list me account dikhna chahiye
4. Ek chhota **Post Now** test karo (scheduled se pehle)

Error aaye to:
- `redirect_uri mismatch` → provider portal me URI bilkul same nahi hai (trailing slash, http vs https, domain)
- `invalid state` / `fetch failed` → `MAIN_URL` aur browser ka URL alag hain
- Provider docs: https://docs.postiz.com/general/troubleshooting/oauth-connect
