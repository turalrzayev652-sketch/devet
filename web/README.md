# web

Guest invitation page and templates on Cloudflare Pages + Pages Functions. Vanilla JS (ES modules), no framework.

```
public/core/                 shared guest-page code (invite-core.js, T23)
public/templates/<id>/       one folder per template (T26+)
functions/i/[code].js        GET /i/<code> → template page or error screen
src/server/                  code used by Functions (not served)
tests/                       unit tests (node --test)
```

Error screen texts come from `/spec/i18n/invite.json` (bundled at build time).

## Local run

```bash
cd web
npm install
cp .dev.vars.example .dev.vars   # fill SUPABASE_ANON_KEY after `supabase start`
npm run dev                      # http://localhost:8788/i/test
npm test
```

Environment variables (Cloudflare Pages dashboard in production): `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `PUBLIC_BASE_URL`.
Only the anon key is used here; the service role key is added later for signed media URLs (T24) and lives only in Cloudflare env.
