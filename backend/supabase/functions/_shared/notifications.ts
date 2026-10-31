// POST /functions/v1/store-notifications/google?token=<STORE_NOTIFICATION_TOKEN>  (Play RTDN via Pub/Sub push)
// POST /functions/v1/store-notifications/apple                                    (App Store Server Notifications V2)
//
// A notification is only a trigger: the refund is recorded after the store's own API confirms it, so a forged
// notification cannot revoke anyone's purchase. Unknown or irrelevant notifications get 200 so stores stop retrying.
import type { Config } from './config.ts';
import { googleTransactionId, isVoided, type Fetch } from './google-play.ts';
import { getTransaction } from './app-store.ts';
import { recordRefund } from './db.ts';
import { decodeJwsPayload, base64urlDecode, timingSafeEqual } from './jwt.ts';

export interface NotificationResult {
  status: number;
  body: Record<string, unknown>;
}

const done = (outcome: string, extra: Record<string, unknown> = {}): NotificationResult => ({ status: 200, body: { ok: true, outcome, ...extra } });
const bad = (status: number, error: string): NotificationResult => ({ status, body: { ok: false, error } });

export async function handleGoogleNotification(cfg: Config, token: string | null, body: unknown, fetchImpl: Fetch): Promise<NotificationResult> {
  if (!cfg.notificationToken || !token || !timingSafeEqual(token, cfg.notificationToken)) return bad(401, 'unauthorized');
  if (!cfg.google) return bad(503, 'store_not_configured');

  let data: Record<string, any>;
  try {
    const encoded = (body as any)?.message?.data;
    data = JSON.parse(new TextDecoder().decode(base64urlDecode(String(encoded))));
  } catch {
    return bad(400, 'invalid_request');
  }
  if (data.packageName !== cfg.google.packageName) return done('ignored_package');
  const voided = data.voidedPurchaseNotification;
  if (!voided) return done('ignored_type'); // test notifications, subscriptions, one-time product events

  const { orderId, purchaseToken } = voided;
  if (!(await isVoided(cfg.google, orderId, purchaseToken, fetchImpl))) return done('not_confirmed');
  const result = await recordRefund(cfg.db, 'google', await googleTransactionId(orderId, purchaseToken), fetchImpl);
  return done(result?.ok ? result.status : result?.error ?? 'unknown', { event_id: result?.event_id });
}

const APPLE_REFUND_TYPES = new Set(['REFUND', 'REVOKE']);

export async function handleAppleNotification(cfg: Config, body: unknown, fetchImpl: Fetch): Promise<NotificationResult> {
  if (!cfg.apple) return bad(503, 'store_not_configured');

  let payload: Record<string, any>;
  let transactionId: string;
  try {
    payload = decodeJwsPayload((body as any)?.signedPayload);
    if (!APPLE_REFUND_TYPES.has(payload.notificationType)) return done('ignored_type');
    if (payload.data?.bundleId && payload.data.bundleId !== cfg.apple.bundleId) return done('ignored_bundle');
    transactionId = String(decodeJwsPayload<any>(payload.data?.signedTransactionInfo).transactionId ?? '');
  } catch {
    return bad(400, 'invalid_request');
  }

  // Confirm with Apple: the transaction must exist for our app and carry a revocation date.
  const tx = await getTransaction(cfg.apple, transactionId, fetchImpl);
  if (!tx || tx.bundleId !== cfg.apple.bundleId || !tx.revocationDate) return done('not_confirmed');
  const result = await recordRefund(cfg.db, 'apple', transactionId, fetchImpl);
  return done(result?.ok ? result.status : result?.error ?? 'unknown', { event_id: result?.event_id });
}
