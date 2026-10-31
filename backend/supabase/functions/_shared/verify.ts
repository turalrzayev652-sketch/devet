// POST /functions/v1/verify-purchase — called by the app after a successful store purchase.
//
// Request (Authorization: Bearer <user access token>):
//   { "store": "google", "event_id": "<uuid>", "product_id": "template_premium_01", "purchase_token": "<token>" }
//   { "store": "apple",  "event_id": "<uuid>", "product_id": "limit_addon_200",     "transaction_id": "2000000…" }
// Response 200: { ok: true, status: "created" | "already_recorded", kind, is_paid, guest_limit }
// Errors:       { ok: false, error } with the HTTP status below.
import type { Config } from './config.ts';
import { checkGooglePurchase, consumePurchase, getProductPurchase, googleTransactionId, StoreError, type Fetch } from './google-play.ts';
import { appleAmountMinor, checkAppleTransaction, getTransaction } from './app-store.ts';
import { getUserId, recordPurchase } from './db.ts';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const PRODUCT_RE = /^[a-z0-9_.]{1,100}$/;

export const ERROR_STATUS: Record<string, number> = {
  invalid_request: 400,
  unauthorized: 401,
  not_member: 403,
  purchase_not_found: 404,
  transaction_used: 409,
  refunded: 409,
  purchase_pending: 422,
  purchase_cancelled: 422,
  purchase_mismatch: 422,
  test_purchase_not_allowed: 422,
  revoked: 422,
  unknown_product: 422,
  template_mismatch: 422,
  store_unavailable: 502,
  store_not_configured: 503,
};

export interface VerifyResult {
  status: number;
  body: Record<string, unknown>;
}

const fail = (error: string): VerifyResult => ({ status: ERROR_STATUS[error] ?? 500, body: { ok: false, error } });

export async function verifyPurchase(cfg: Config, request: { authorization: string | null; body: unknown }, fetchImpl: Fetch): Promise<VerifyResult> {
  const b = (request.body ?? {}) as Record<string, unknown>;
  const store = b.store;
  const eventId = typeof b.event_id === 'string' ? b.event_id : '';
  const productId = typeof b.product_id === 'string' ? b.product_id : '';
  if ((store !== 'google' && store !== 'apple') || !UUID_RE.test(eventId) || !PRODUCT_RE.test(productId)) return fail('invalid_request');

  const userId = await getUserId(cfg.db, request.authorization, fetchImpl);
  if (!userId) return fail('unauthorized');

  try {
    if (store === 'google') {
      const token = typeof b.purchase_token === 'string' ? b.purchase_token : '';
      if (!token || token.length > 4096) return fail('invalid_request');
      if (!cfg.google) return fail('store_not_configured');

      const purchase = await getProductPurchase(cfg.google, productId, token, fetchImpl);
      const check = checkGooglePurchase(purchase, { userId, eventId, allowTestPurchases: cfg.google.allowTestPurchases });
      if (!check.ok) return fail(check.error);

      const result = await recordPurchase(cfg.db, {
        userId, eventId, productId, store, transactionId: await googleTransactionId(purchase.orderId, token), amountMinor: null, currency: null,
      }, fetchImpl);
      if (!result?.ok) return fail(result?.error ?? 'store_unavailable');
      // Consume only after the purchase is safely recorded; an unconsumed purchase is refunded by Google after 3 days,
      // and a failed consume is retried when the app calls again (record_purchase is idempotent).
      if (purchase.consumptionState !== 1) {
        try {
          await consumePurchase(cfg.google, productId, token, fetchImpl);
        } catch (e) {
          console.error('consume failed (purchase is recorded; retried on next call)', e);
        }
      }
      return { status: 200, body: result };
    }

    const transactionId = typeof b.transaction_id === 'string' ? b.transaction_id : '';
    if (!/^\d{1,30}$/.test(transactionId)) return fail('invalid_request');
    if (!cfg.apple) return fail('store_not_configured');

    const tx = await getTransaction(cfg.apple, transactionId, fetchImpl);
    if (!tx) return fail('purchase_not_found');
    const check = checkAppleTransaction(tx, { transactionId, productId, bundleId: cfg.apple.bundleId, userId, allowSandbox: cfg.apple.allowSandbox });
    if (!check.ok) return fail(check.error);

    const result = await recordPurchase(cfg.db, {
      userId, eventId, productId, store, transactionId, amountMinor: appleAmountMinor(tx.price), currency: tx.currency ?? null,
    }, fetchImpl);
    if (!result?.ok) return fail(result?.error ?? 'store_unavailable');
    return { status: 200, body: result };
  } catch (e) {
    if (e instanceof StoreError) return fail(e.code);
    console.error('verify-purchase failed', e);
    return fail('store_unavailable');
  }
}
