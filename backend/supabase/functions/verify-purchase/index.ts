// Edge Function: verify-purchase (T4C). Logic and request/response contract: ../_shared/verify.ts
import { json, loadConfig } from '../_shared/config.ts';
import { verifyPurchase } from '../_shared/verify.ts';

const config = loadConfig((name) => Deno.env.get(name));

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json({ ok: false, error: 'method_not_allowed' }, 405);
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return json({ ok: false, error: 'invalid_request' }, 400);
  }
  const result = await verifyPurchase(config, { authorization: req.headers.get('authorization'), body }, fetch);
  return json(result.body, result.status);
});
