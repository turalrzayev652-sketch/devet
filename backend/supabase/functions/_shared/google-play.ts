// Google Play Developer API (purchases.products, voidedpurchases) with a service account.
import { importRsaPrivateKey, sha256Hex, signJwt } from './jwt.ts';

export type Fetch = typeof fetch;

export interface GoogleConfig {
  packageName: string;
  clientEmail: string;
  privateKey: string;
  allowTestPurchases: boolean;
}

export class StoreError extends Error {
  code: string;
  constructor(code: string, message?: string) {
    super(message ?? code);
    this.code = code;
  }
}

const API = 'https://androidpublisher.googleapis.com/androidpublisher/v3/applications';
const TOKEN_URL = 'https://oauth2.googleapis.com/token';
let cached: { token: string; expires: number; email: string } | null = null;

export function resetGoogleTokenCache() {
  cached = null;
}

export async function googleAccessToken(cfg: GoogleConfig, fetchImpl: Fetch, now = Date.now()): Promise<string> {
  if (cached && cached.email === cfg.clientEmail && cached.expires > now + 60_000) return cached.token;
  const iat = Math.floor(now / 1000);
  const assertion = await signJwt(
    { alg: 'RS256', typ: 'JWT' },
    { iss: cfg.clientEmail, scope: 'https://www.googleapis.com/auth/androidpublisher', aud: TOKEN_URL, iat, exp: iat + 3600 },
    await importRsaPrivateKey(cfg.privateKey),
  );
  const res = await fetchImpl(TOKEN_URL, {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion }).toString(),
  });
  if (!res.ok) throw new StoreError('store_unavailable', `google token ${res.status}`);
  const json = await res.json();
  cached = { token: json.access_token, expires: now + (json.expires_in ?? 3600) * 1000, email: cfg.clientEmail };
  return cached.token;
}

async function authed(cfg: GoogleConfig, fetchImpl: Fetch, url: string, init: RequestInit = {}) {
  const token = await googleAccessToken(cfg, fetchImpl);
  return fetchImpl(url, { ...init, headers: { ...(init.headers ?? {}), authorization: `Bearer ${token}` } });
}

const tokenUrl = (cfg: GoogleConfig, productId: string, purchaseToken: string) =>
  `${API}/${encodeURIComponent(cfg.packageName)}/purchases/products/${encodeURIComponent(productId)}/tokens/${encodeURIComponent(purchaseToken)}`;

export interface ProductPurchase {
  purchaseState?: number;        // 0 purchased, 1 cancelled, 2 pending
  consumptionState?: number;     // 0 yet to be consumed, 1 consumed
  acknowledgementState?: number;
  orderId?: string;
  purchaseType?: number;         // 0 test (license tester), 1 promo, 2 rewarded; absent = real
  obfuscatedExternalAccountId?: string;
  obfuscatedExternalProfileId?: string;
  productId?: string;
}

export async function getProductPurchase(cfg: GoogleConfig, productId: string, purchaseToken: string, fetchImpl: Fetch): Promise<ProductPurchase> {
  const res = await authed(cfg, fetchImpl, tokenUrl(cfg, productId, purchaseToken));
  if (res.status === 404 || res.status === 400 || res.status === 410) throw new StoreError('purchase_not_found');
  if (!res.ok) throw new StoreError('store_unavailable', `google purchase ${res.status}`);
  return await res.json();
}

// All products are consumable: a paid template or an add-on is bought again for the next event.
export async function consumePurchase(cfg: GoogleConfig, productId: string, purchaseToken: string, fetchImpl: Fetch): Promise<boolean> {
  const res = await authed(cfg, fetchImpl, `${tokenUrl(cfg, productId, purchaseToken)}:consume`, { method: 'POST' });
  return res.ok;
}

// Transaction id stored in purchases.store_transaction_id. Test purchases may have no orderId.
export async function googleTransactionId(orderId: string | undefined, purchaseToken: string): Promise<string> {
  return orderId && orderId.trim() ? orderId.trim() : `token:${await sha256Hex(purchaseToken)}`;
}

export function checkGooglePurchase(
  p: ProductPurchase,
  expected: { userId: string; eventId: string; allowTestPurchases: boolean },
): { ok: true } | { ok: false; error: string } {
  if (p.purchaseState === 2) return { ok: false, error: 'purchase_pending' };
  if (p.purchaseState !== 0) return { ok: false, error: 'purchase_cancelled' };
  if (p.purchaseType === 0 && !expected.allowTestPurchases) return { ok: false, error: 'test_purchase_not_allowed' };
  if (p.purchaseType === 1 || p.purchaseType === 2) return { ok: false, error: 'purchase_mismatch' };
  // The app passes the user id / event id as obfuscated account / profile id when launching the purchase.
  if (p.obfuscatedExternalAccountId && p.obfuscatedExternalAccountId !== expected.userId) return { ok: false, error: 'purchase_mismatch' };
  if (p.obfuscatedExternalProfileId && p.obfuscatedExternalProfileId !== expected.eventId) return { ok: false, error: 'purchase_mismatch' };
  return { ok: true };
}

// Confirms a refund notification against the Voided Purchases API (last 30 days).
export async function isVoided(cfg: GoogleConfig, orderId: string | undefined, purchaseToken: string | undefined, fetchImpl: Fetch, now = Date.now()): Promise<boolean> {
  let pageToken: string | undefined;
  const startTime = now - 30 * 24 * 3600 * 1000;
  for (let page = 0; page < 20; page++) {
    const qs = new URLSearchParams({ startTime: String(startTime), maxResults: '1000' });
    if (pageToken) qs.set('token', pageToken);
    const res = await authed(cfg, fetchImpl, `${API}/${encodeURIComponent(cfg.packageName)}/purchases/voidedpurchases?${qs}`);
    if (!res.ok) throw new StoreError('store_unavailable', `google voided ${res.status}`);
    const json = await res.json();
    for (const v of json.voidedPurchases ?? []) {
      if ((orderId && v.orderId === orderId) || (purchaseToken && v.purchaseToken === purchaseToken)) return true;
    }
    pageToken = json.tokenPagination?.nextPageToken;
    if (!pageToken) return false;
  }
  return false;
}
