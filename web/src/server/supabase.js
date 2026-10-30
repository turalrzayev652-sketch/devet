// Guest RPC calls with the anon key only (CLAUDE.md security rules).

export const CODE_RE = /^[0-9A-HJKMNP-TV-Z]{8}$/;

export function normalizeCode(raw) {
  const code = String(raw ?? '').trim().toUpperCase();
  return CODE_RE.test(code) ? code : null;
}

// Returns the RPC JSON ({ ok, ... } or { ok: false, error }) or { ok: false, error: 'network' }.
export async function callRpc(env, fn, args, fetchImpl = (...args) => fetch(...args)) {
  if (!env.SUPABASE_URL || !env.SUPABASE_ANON_KEY) return { ok: false, error: 'network' };
  try {
    const res = await fetchImpl(`${env.SUPABASE_URL}/rest/v1/rpc/${fn}`, {
      method: 'POST',
      headers: {
        apikey: env.SUPABASE_ANON_KEY,
        authorization: `Bearer ${env.SUPABASE_ANON_KEY}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify(args),
    });
    if (!res.ok) return { ok: false, error: 'network' };
    return await res.json();
  } catch {
    return { ok: false, error: 'network' };
  }
}
