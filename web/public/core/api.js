// Guest RPCs through Supabase PostgREST with the anon key (PRODUCT.md §6).

export async function rpc(config, fn, args) {
  try {
    const res = await fetch(`${config.supabase_url}/rest/v1/rpc/${fn}`, {
      method: 'POST',
      headers: {
        apikey: config.anon_key,
        authorization: `Bearer ${config.anon_key}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify(args),
    });
    if (res.status === 429) return { ok: false, error: 'rate_limited' };
    if (!res.ok) return { ok: false, error: 'network' };
    return await res.json();
  } catch {
    return { ok: false, error: 'network' };
  }
}
