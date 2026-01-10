# 🚀 Quick Deploy Guide

Your landing page is ready! Here's how to get it online in minutes.

## Preview Locally

```bash
cd website
python3 -m http.server 8000
# Open http://localhost:8000 in your browser
```

---

## 🎯 Fastest: Netlify Drop (1 minute)

1. Go to [https://app.netlify.com/drop](https://app.netlify.com/drop)
2. Drag the `website` folder onto the page
3. Done! You get a URL like `https://luzia-abc123.netlify.app`
4. (Optional) Add custom domain in Netlify settings

**Tip:** Netlify auto-deploys on git push if you connect your repo!

---

## ⚡ Vercel (2 minutes)

```bash
# Install Vercel CLI
npm install -g vercel

# Deploy
cd website
vercel --prod

# Follow prompts, get instant URL
```

---

## 🐙 GitHub Pages (Free hosting)

```bash
# Already committed! Just:
git push origin main

# Then:
# 1. Go to your GitHub repo settings
# 2. Pages > Source > Select "main" branch > "/website" folder
# 3. Save
# 4. Your site will be at: https://yourusername.github.io/repo-name/
```

---

## 💰 Adding Paywall (Choose One)

### Gumroad (Easiest - No coding)

1. Create product at [gumroad.com](https://gumroad.com)
2. Replace `href="#"` with your Gumroad link:
   ```html
   <a href="https://gumroad.com/l/luzia" class="btn btn-primary">Buy Now</a>
   ```

### Paddle (Professional)

1. Sign up at [paddle.com](https://paddle.com)
2. Add their script + product ID
3. Handles VAT, invoices, everything

### LemonSqueezy (Modern, dev-friendly)

1. Create product at [lemonsqueezy.com](https://lemonsqueezy.com)
2. Get checkout URL
3. Replace button links

### Stripe Checkout (Full control)

Best for custom flows, but requires backend.

---

## 📊 Add Analytics (Optional)

Add before `</body>`:

```html
<!-- Google Analytics -->
<script async src="https://www.googletagmanager.com/gtag/js?id=G-XXXXXXXXXX"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());
  gtag('config', 'G-XXXXXXXXXX');
</script>

<!-- OR Plausible (privacy-friendly) -->
<script defer data-domain="yourdomain.com" src="https://plausible.io/js/script.js"></script>
```

---

## 🎨 Customization Quick Wins

### Change Colors
Edit the gradient in CSS (line 14):
```css
background: linear-gradient(-45deg, #667eea, #764ba2, #f093fb, #4facfe);
```

### Update Pricing
Search for `<!-- Pricing Section -->` (line 450)

### Add Download Links
Replace all `href="#"` with:
- Mac App Store link
- Direct .dmg download
- Gumroad purchase link

### Add Email Capture
Before footer, add ConvertKit/Mailchimp form:
```html
<section style="padding: 4rem 2rem; background: white;">
  <div style="max-width: 600px; margin: 0 auto; text-align: center;">
    <h2>Get Early Access</h2>
    <form action="YOUR_MAILCHIMP_URL" method="post">
      <input type="email" name="EMAIL" placeholder="your@email.com" required
             style="padding: 1rem; font-size: 1.1rem; border: 2px solid #ddd;
                    border-radius: 50px; width: 300px; margin-right: 1rem;">
      <button type="submit" class="btn btn-primary">Notify Me</button>
    </form>
  </div>
</section>
```

---

## 🔥 Pro Tips

1. **Add video demo**: Record a 30-second screen recording, host on YouTube, embed above pricing
2. **Testimonials**: Add a section with quotes from beta users
3. **A/B test pricing**: Try $19 vs $29 vs $39 to find sweet spot
4. **Exit-intent popup**: Offer discount when user tries to leave
5. **Social proof**: Add "X users" counter, "As seen on" badges

---

## 📱 Test Checklist

- [ ] Mobile layout (iPhone, Android)
- [ ] Tablet layout (iPad)
- [ ] Desktop (1920px+)
- [ ] All links work
- [ ] Smooth scroll works
- [ ] Animations trigger on scroll
- [ ] Forms submit (if added)
- [ ] Buttons go to correct URLs
- [ ] Page loads fast (<2s)
- [ ] Works in Safari, Chrome, Firefox

---

## 🎬 Next Steps

1. **Deploy now** (Netlify Drop = 60 seconds)
2. **Add purchase link** (Gumroad = 5 minutes)
3. **Share on Twitter/HN** (Launch!)
4. **Collect emails** (Build waitlist)
5. **A/B test pricing** (Optimize conversions)

---

Need help? The page is self-contained HTML/CSS/JS with zero dependencies.
It'll work anywhere that serves static files!

🚀 **Now go launch that beautiful app!**
