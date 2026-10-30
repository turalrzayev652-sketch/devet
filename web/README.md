# web

Guest invitation page and templates on Cloudflare Pages + Pages Functions. Vanilla JS (ES modules), no framework.

```
public/core/                 guest-page runtime (loaded by every template)
  invite-core.js             entry: live mode (get_invite / submit_rsvp) and ?preview=1 mode
  blocks.js                  countdown, gallery, music, map, table, rsvp, watermark
  i18n.js, format.js, api.js helpers
  strings.js                 GENERATED from /spec/i18n/invite.json (npm run build) — do not edit
public/templates/<id>/       one folder per template (T26+), contract in /spec/templates.md
functions/i/[code].js        GET /i/<code> → template page (+ <base>, #invite-config) or error screen
src/server/                  code used by Functions (not served)
scripts/build-strings.mjs    invite.json → public/core/strings.js
tests/                       unit tests (node --test); tests/fixtures/template = test template (not deployed)
```

## Local run

```bash
cd web
npm install
cp .dev.vars.example .dev.vars   # fill SUPABASE_ANON_KEY after `supabase start`
npm run dev                      # runs npm run build first; http://localhost:8788/i/<code>
npm test
```

After editing `/spec/i18n/invite.json` run `npm run build` and commit `public/core/strings.js`
(a test fails if it is out of sync).

Environment variables (Cloudflare Pages dashboard in production): `SUPABASE_URL`, `SUPABASE_ANON_KEY`,
`PUBLIC_BASE_URL`, `BRAND_NAME` (optional, default `Devet`). Only the anon key is used here; the service role key
is added for signed media URLs in T24 and lives only in Cloudflare env.
