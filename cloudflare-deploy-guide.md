# Cloudflare Deployment Guide

## Option 1: Cloudflare Pages + R2 (Recommended)

### Step 1: Upload DMG to Cloudflare R2

1. Go to Cloudflare Dashboard → R2 Object Storage
2. Create a bucket: `luzia-enterprise-files`
3. Upload `Luzia-Enterprise.dmg`
4. Make it public or create a public download URL
5. Copy the public URL (e.g., `https://pub-xxxxx.r2.dev/Luzia-Enterprise.dmg`)

### Step 2: Deploy HTML to Cloudflare Pages

```bash
# Create a wrangler.toml if needed
cd website
npx wrangler pages deploy . --project-name=luzia-enterprise
```

Or manually:
1. Go to Cloudflare Dashboard → Pages
2. Click "Create a project"
3. Upload the `website` folder
4. Deploy!

Your site will be at: `https://luzia-enterprise.pages.dev`

### Step 3: Update Download Link

Update the download button in `enterprise.html` to point to your R2 URL.

---

## Option 2: GitHub Releases (Free & Easy)

### Step 1: Create a GitHub Release

```bash
# Tag the release
git tag -a v1.0.0 -m "Enterprise Edition v1.0.0"
git push origin v1.0.0

# Go to GitHub → Releases → Create New Release
# Upload Luzia-Enterprise.dmg as an asset
```

You'll get a URL like:
`https://github.com/[user]/[repo]/releases/download/v1.0.0/Luzia-Enterprise.dmg`

### Step 2: Update HTML

Use the GitHub release URL in your download button.

### Step 3: Deploy HTML to Cloudflare Workers

```bash
cd website
npx wrangler pages deploy . --project-name=luzia-enterprise
```

---

## Option 3: Simple Cloudflare Worker (HTML only)

If you want to host just the HTML and link to an external DMG:

```bash
# Create worker.js
cat > worker.js << 'EOF'
export default {
  async fetch(request) {
    const html = `[PASTE ENTERPRISE.HTML CONTENT HERE]`;

    return new Response(html, {
      headers: {
        'content-type': 'text/html;charset=UTF-8',
      },
    });
  },
};
EOF

# Deploy
npx wrangler deploy
```

---

## Quick Deploy: Cloudflare Pages (Simplest)

1. Create a `website` directory with just `enterprise.html`
2. Run: `npx wrangler pages deploy website --project-name=luzia-enterprise`
3. Done! Your site is live at `luzia-enterprise.pages.dev`

Then host the DMG file on:
- R2 (best if staying in Cloudflare ecosystem)
- GitHub Releases (easiest and free)
- Your company's file server/shared drive

---

## Pricing Notes

**Cloudflare Pages:** Free for unlimited static sites
**Cloudflare R2:**
- 10 GB storage free
- 1M Class A operations/month free (uploads)
- 10M Class B operations/month free (downloads)
- No egress fees!

**GitHub Releases:** Free and unlimited
