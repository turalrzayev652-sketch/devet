// Supabase calls from Edge Functions over HTTP (no client library): Auth user lookup and service-role RPCs.
import type { Fetch } from './google-play.ts';

export interface DbConfig {
  url: string;
  serviceKey: string;
}

// Resolves the signed-in user from the app's "Authorization: Bearer <access token>" header.
export async function getUserId(cfg: DbConfig, authorization: string | null, fetchImpl: Fetch): Promise<string | null> {
  if (!authorization?.startsWith('Bearer ')) return null;
  const res = await fetchImpl(`${cfg.url}/auth/v1/user`, {
    headers: { apikey: cfg.serviceKey, authorization },
  });
  if (!res.ok) return null;
  const user = await res.json();
  return typeof user?.id === 'string' ? user.id : null;
}

async function rpc(cfg: DbConfig, fn: string, args: Record<string, unknown>, fetchImpl: Fetch) {
  const res = await fetchImpl(`${cfg.url}/rest/v1/rpc/${fn}`, {
    method: 'POST',
    headers: {
      apikey: cfg.serviceKey,
      authorization: `Bearer ${cfg.serviceKey}`,
      'content-type': 'application/json',
    },
    body: JSON.stringify(args),
  });
  if (!res.ok) throw new Error(`${fn} failed: ${res.status}`);
  return await res.json();
}

export function recordPurchase(
  cfg: DbConfig,
  args: { userId: string; eventId: string; productId: string; store: 'google' | 'apple'; transactionId: string; amountMinor: number | null; currency: string | null },
  fetchImpl: Fetch,
) {
  return rpc(cfg, 'record_purchase', {
    p_user_id: args.userId,
    p_event_id: args.eventId,
    p_product_id: args.productId,
    p_store: args.store,
    p_transaction_id: args.transactionId,
    p_amount_minor: args.amountMinor,
    p_currency: args.currency,
  }, fetchImpl);
}

export function recordRefund(cfg: DbConfig, store: 'google' | 'apple', transactionId: string, fetchImpl: Fetch) {
  return rpc(cfg, 'record_refund', { p_store: store, p_transaction_id: transactionId }, fetchImpl);
}
