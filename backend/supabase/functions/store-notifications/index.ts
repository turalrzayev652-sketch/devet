// Edge Function: store-notifications (T4C refunds). Called by Google Pub/Sub and Apple, not by the app,
// so JWT verification is off for this function (config.toml) and each store is authenticated in the handler.
import { json, loadConfig } from '../_shared/config.ts';
import { handleAppleNotification, handleGoogleNotification } from '../_shared/notifications.ts';

const config = loadConfig((name) => Deno.env.get(name));

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json({ ok: false, error: 'method_not_allowed' }, 405);
  const url = new URL(req.url);
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return json({ ok: false, error: 'invalid_request' }, 400);
  }
  const result = url.pathname.endsWith('/google')
    ? await handleGoogleNotification(config, url.searchParams.get('token'), body, fetch)
    : url.pathname.endsWith('/apple')
      ? await handleAppleNotification(config, body, fetch)
      : { status: 404, body: { ok: false, error: 'not_found' } };
  return json(result.body, result.status);
});
