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
