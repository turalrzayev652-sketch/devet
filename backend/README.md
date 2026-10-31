# backend

Supabase project (Postgres + RLS, Auth, Storage, Edge Functions).

Layout: `supabase/migrations`, `supabase/functions`, `supabase/seed.sql`, `supabase/tests`.

## Local run

Requires the Supabase CLI and Docker Desktop.

```bash
cd backend
supabase start
supabase db reset   # applies migrations + seed.sql
```

Seed (local only): user `demo@devet.test` / `demo-password-123`, one wedding event, 10 guests
with fixed codes (e.g. `K7D2M9QX`), templates `free-01` and `free-02`.

## Tests

pgTAP tests live in `supabase/tests/*.test.sql` (security, guest RPCs, guest limit, cohost invites,
storage, phone retention). Each file runs in a transaction and rolls back.

```bash
cd backend
supabase test db
```

## In-app purchases (T4C)

Edge Functions in `supabase/functions/` (shared code in `_shared/`, tests in `_tests/`):

- **`verify-purchase`** — the app calls it after a store purchase with the user's access token:
  `{ "store": "google", "event_id", "product_id", "purchase_token" }` or
  `{ "store": "apple", "event_id", "product_id", "transaction_id" }`.
  The function asks Google Play / the App Store Server API, then calls `record_purchase` (migration 009), which writes
  `purchases` and unlocks the template (`events.is_paid`) or raises the limit — idempotent on the store transaction id.
  Google purchases are consumed after they are recorded (products are bought once per event).
  App contract: Android passes `setObfuscatedAccountId(userId)` and `setObfuscatedProfileId(eventId)`;
  iOS passes `appAccountToken = userId`.
- **`store-notifications`** — refund webhooks: `/google?token=…` (Play RTDN via Pub/Sub push) and `/apple`
  (App Store Server Notifications V2). Each notification is confirmed with the store API before `record_refund` runs.

Secrets: `supabase/functions/.env.example`. Tests (no Deno needed):

```bash
node --experimental-strip-types --test supabase/functions/_tests/purchase.test.ts
supabase test db          # purchases.test.sql
supabase functions serve  # local run (needs Docker)
```
