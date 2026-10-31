// Reads Edge Function secrets. SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are injected by Supabase;
// the store keys are set with `supabase secrets set` (see backend/README.md). Nothing here is ever sent to clients.
import type { DbConfig } from './db.ts';
import type { GoogleConfig } from './google-play.ts';
import type { AppleConfig } from './app-store.ts';

export interface Config {
  db: DbConfig;
  google: GoogleConfig | null;
  apple: AppleConfig | null;
  notificationToken: string | null;
}

const flag = (v: string | undefined) => v === 'true' || v === '1';

export function loadConfig(get: (name: string) => string | undefined): Config {
  const url = get('SUPABASE_URL');
  const serviceKey = get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !serviceKey) throw new Error('SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY missing');

  let google: GoogleConfig | null = null;
  const sa = get('GOOGLE_SERVICE_ACCOUNT_JSON');
  const pkg = get('GOOGLE_PLAY_PACKAGE_NAME');
  if (sa && pkg) {
    const parsed = JSON.parse(sa);
    google = {
      packageName: pkg,
      clientEmail: parsed.client_email,
      privateKey: parsed.private_key,
      allowTestPurchases: flag(get('GOOGLE_ALLOW_TEST_PURCHASES')),
    };
  }

  let apple: AppleConfig | null = null;
  const bundleId = get('APPLE_BUNDLE_ID');
  const issuerId = get('APPLE_ISSUER_ID');
  const keyId = get('APPLE_KEY_ID');
  const privateKey = get('APPLE_PRIVATE_KEY');
  if (bundleId && issuerId && keyId && privateKey) {
    apple = { bundleId, issuerId, keyId, privateKey, allowSandbox: flag(get('APPLE_ALLOW_SANDBOX')) };
  }

  return { db: { url, serviceKey }, google, apple, notificationToken: get('STORE_NOTIFICATION_TOKEN') || null };
}

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });
}
