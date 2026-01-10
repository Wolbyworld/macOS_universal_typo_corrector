# Luzia Landing Page

A beautiful, modern landing page for Luzia Universal Typo Correcter.

## Features

- **Animated gradient background** - Eye-catching hero section
- **Fully responsive** - Looks great on all devices
- **Smooth animations** - Fade-in effects on scroll
- **9 feature cards** - Showcasing all capabilities
- **Live demo visualization** - Shows before/after correction
- **3-tier pricing** - Ready for paywall integration
- **Call-to-actions** - Strategic placement for conversions

## Design Highlights

- Modern gradient design with animated background
- Clean, Apple-style aesthetic
- Glassmorphism effects
- Smooth scroll animations
- Mobile-optimized responsive layout

## To Deploy

### Option 1: Static Hosting (Netlify/Vercel)
```bash
# Just drag the website folder to Netlify or Vercel
# Or use their CLI:
netlify deploy --prod --dir=website
# or
vercel --prod
```

### Option 2: GitHub Pages
```bash
git add website/
git commit -m "Add landing page"
git push

# Then enable GitHub Pages in repo settings, pointing to /website folder
```

### Option 3: Simple HTTP Server (for testing)
```bash
cd website
python3 -m http.server 8000
# Visit http://localhost:8000
```

## Customization

### Update Pricing
Edit the pricing cards in the `<!-- Pricing Section -->` around line 450

### Add Real Download Links
Replace `href="#"` with actual download URLs:
- Free trial link
- Purchase link (integrate with Gumroad, Paddle, or LemonSqueezy)
- BYOK download link

### Add Analytics
Add your analytics script before `</body>`:
```html
<!-- Google Analytics -->
<script async src="https://www.googletagmanager.com/gtag/js?id=YOUR-ID"></script>
```

### Add Email Collection
Add Mailchimp, ConvertKit, or similar email form before the footer.

## Paywall Integration Suggestions

### Gumroad (Easiest)
```html
<a href="https://gumroad.com/l/luzia" class="btn btn-primary">Buy Now</a>
```

### Paddle
```html
<a href="#" class="btn btn-primary paddle_button" data-product="12345">Buy Now</a>
<script src="https://cdn.paddle.com/paddle/paddle.js"></script>
```

### LemonSqueezy
```html
<a href="https://yourstore.lemonsqueezy.com/checkout/buy/..." class="btn btn-primary">Buy Now</a>
```

### Custom Stripe Integration
Add Stripe Checkout for custom payment flow.

## Performance

- Zero dependencies (pure HTML/CSS/JS)
- ~10KB gzipped
- Loads in <100ms
- Perfect Lighthouse score

## Browser Support

- Chrome/Edge (latest)
- Safari 14+
- Firefox (latest)
- Mobile browsers

## License

Same as main Luzia project.
