# Dəvətnamə — MVP Deployment Checklist

## ✅ Code Complete (Main Branch)
- [x] Android app: T41-T48 features complete
- [x] iOS app: T41-T48 features complete  
- [x] Backend (Supabase): migrations, RLS, Edge Functions (partial)
- [x] Web (Cloudflare Pages): guest site with templates

## 🔧 Pre-Deployment (Infra Setup)

### 1. Supabase Project
- [ ] Create production Supabase project
- [ ] Run migrations:
  - `/backend/supabase/migrations/001-*.sql` → 009
  - Verify: `guests`, `events`, `event_members`, `accounts`, `purchases` tables
  - Verify RLS policies enabled
- [ ] Upload Edge Functions:
  - `backend/supabase/functions/verify-purchase/` (T4C — minimal version)
  - Deploy as `verify-purchase` function

### 2. Storage
- [ ] Create `previews` bucket (public, auto-expire after 7 days)
- [ ] Create `templates` bucket (public, for OG images)

### 3. Cloudflare Pages (Web)
- [ ] Link `/web` directory to Cloudflare Pages
- [ ] Configure environment:
  - `SUPABASE_URL`
  - `SUPABASE_ANON_KEY`
  - `PUBLIC_BASE_URL` (e.g., https://devet.az)
- [ ] Deploy `/web/public` (guest site)
- [ ] Deploy `/web/functions` (Edge Functions for `/i/<code>`)

### 4. Domain
- [ ] Point `devet.az` to Cloudflare nameservers
- [ ] Configure DNS for API (if needed)

### 5. Environment Variables

**Android** (`android/local.properties`):
```
SUPABASE_URL=https://<project>.supabase.co
SUPABASE_ANON_KEY=<anon-key>
DEVET_DEMO=false  # Disable demo mode for production
```

**iOS** (`ios/Devet/Config.swift` or similar):
```swift
let SUPABASE_URL = "https://<project>.supabase.co"
let SUPABASE_ANON_KEY = "<anon-key>"
```

### 6. Mobile App Signing & Stores

**Android:**
- [ ] Generate release keystore
- [ ] Sign APK/AAB
- [ ] Upload to Google Play Console
  - Create app (Dəvətnamə)
  - Upload AAB
  - Fill store listing (description, screenshots)
  - Request Google Play billing API access
  - Submit for review

**iOS:**
- [ ] Request iOS developer certificate
- [ ] Create App ID in Apple Developer
- [ ] Upload to App Store Connect
  - Create app (Dəvətnamə)
  - Upload build (via Xcode/Transporter)
  - Fill app info (description, screenshots)
  - Request App Store Server API access
  - Submit for review

## 🧪 Pre-Launch Testing

### Functional
- [ ] Android: Full flow (create event → add guests → send WhatsApp)
- [ ] iOS: Same flow
- [ ] Web: Guest opens link, RSVP works
- [ ] Supabase: Data persists correctly
- [ ] Preview images: Generate, upload, load in WhatsApp

### Security
- [ ] RLS policies: Users can only see their own events
- [ ] Auth: Session persists, logout clears data
- [ ] Storage: `previews` bucket only readable via signed URLs
- [ ] API: No exposed secrets in client code

## 📝 Launch Checklist

- [ ] Create admin account (test@devet.az)
- [ ] Test 10-guest send flow on real devices
- [ ] Check WhatsApp link opens correctly
- [ ] Verify guest page loads (check Cloudflare cache)
- [ ] Test on 4G/LTE (not just WiFi)
- [ ] Screenshot: iOS App Store + Google Play listing

## 🔄 Post-Launch

**Week 1:**
- Monitor Supabase logs for errors
- Check storage usage (previews size)
- Respond to feedback

**Next Features (Post-MVP):**
- T49: Statistics dashboard
- T4AA: Co-host invites  
- T4B: Export to Excel/PDF
- T4C: Payment verification (sandbox testing)
- T4D: In-app purchases (template upgrades)

## Notes

- **Testing**: All code tested with demo data; real Supabase interaction not verified
- **Limits**: Free tier OK for MVP (limited functions, storage, auth)
- **Performance**: WhatsApp preview loading may be slow (pre-compress images)
- **Billing**: No payment integration yet; all premium features locked
- **Translations**: Full i18n (az/ru/en/tr) implemented in app; web uses event's lang

---

**Status:** Ready for staging deployment. Production deployment contingent on infra setup.

**Estimated time:** 2-3 hours (Supabase + Cloudflare + mobile app stores)

