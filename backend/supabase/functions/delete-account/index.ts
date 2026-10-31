// Edge Function: delete-account (T17). Logic and contract: ../_shared/account.ts
import { json, loadConfig } from '../_shared/config.ts';
import { deleteAccount } from '../_shared/account.ts';

const config = loadConfig((name) => Deno.env.get(name));

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json({ ok: false, error: 'method_not_allowed' }, 405);
  const result = await deleteAccount(config, req.headers.get('authorization'), fetch);
  return json(result.body, result.status);
});
