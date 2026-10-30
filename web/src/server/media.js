// Signed URLs for the guest's event photos/music (private bucket event-media).
// Decision 2026-10-29 (TASKS.md T24): signed here with SUPABASE_SERVICE_ROLE_KEY, which exists only in the
// Cloudflare environment. The key is never written into the page.

export const SIGNED_URL_TTL_SECONDS = 6 * 60 * 60;
const EMPTY = { photos: [], music: null };

// Only files inside this event's own folders may be signed: customization is written by family members,
// and a path into another event's folder would otherwise leak that event's private media.
export function allowedPath(eventId, path, folder) {
  if (typeof path !== 'string' || !eventId) return false;
  const prefix = `${eventId}/${folder}/`;
  const rest = path.slice(prefix.length);
  return path.startsWith(prefix) && rest.length > 0 && !rest.includes('/') && !rest.includes('..');
}

export async function signedMedia(env, code, fetchImpl = (...args) => fetch(...args)) {
  const url = env.SUPABASE_URL;
  const key = env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) return EMPTY;
  const headers = { apikey: key, authorization: `Bearer ${key}`, 'content-type': 'application/json' };

  try {
    const res = await fetchImpl(
      `${url}/rest/v1/guests?code=eq.${encodeURIComponent(code)}&select=event_id,events(customization)&limit=1`,
      { headers },
    );
    if (!res.ok) return EMPTY;
    const [row] = await res.json();
    if (!row) return EMPTY;
    const custom = row.events?.customization ?? {};
    const photos = (Array.isArray(custom.photos) ? custom.photos : [])
      .filter((p) => allowedPath(row.event_id, p, 'photos'))
      .slice(0, 6);
    const music = allowedPath(row.event_id, custom.music, 'music') ? custom.music : null;
    const paths = [...photos, ...(music ? [music] : [])];
    if (!paths.length) return EMPTY;

    const signRes = await fetchImpl(`${url}/storage/v1/object/sign/event-media`, {
      method: 'POST',
      headers,
      body: JSON.stringify({ expiresIn: SIGNED_URL_TTL_SECONDS, paths }),
    });
    if (!signRes.ok) return EMPTY;
    const signed = new Map();
    for (const item of await signRes.json()) {
      if (item?.signedURL && !item.error) signed.set(item.path, `${url}/storage/v1${item.signedURL}`);
    }
    return {
      photos: photos.map((p) => signed.get(p)).filter(Boolean),
      music: music ? signed.get(music) ?? null : null,
    };
  } catch {
    return EMPTY;
  }
}
