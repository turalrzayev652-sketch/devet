import { test } from 'node:test';
import assert from 'node:assert/strict';
import { handleInvite } from '../src/server/invite-handler.js';
import { ogData } from '../src/server/og.js';
import { allowedPath, signedMedia, SIGNED_URL_TTL_SECONDS } from '../src/server/media.js';

const EVENT = '22222222-2222-2222-2222-222222222222';
const OTHER = '99999999-9999-9999-9999-999999999999';
const PREVIEW = {
  ok: true, lang: 'az', display_name: 'Elçin müəllim və ailəsi', event_type: 'wedding',
  title_names: 'Aysel və Ramin', starts_at: '2027-07-10T18:00:00+04:00', venue_name: 'Gülüstan sarayı',
  preview_url: null, template_id: 'free-01',
};
const TEMPLATE = '<!doctype html><html><head><meta charset="utf-8"><title>Template</title></head><body><main></main></body></html>';

function makeEnv(extra = {}) {
  return {
    SUPABASE_URL: 'https://proj.supabase.test',
    SUPABASE_ANON_KEY: 'anon-key',
    PUBLIC_BASE_URL: 'https://devet.pages.test',
    ASSETS: { fetch: async (url) => (new URL(url).pathname === '/templates/free-01/index.html'
      ? new Response(TEMPLATE) : new Response('nope', { status: 404 })) },
    ...extra,
  };
}

// Fake Supabase: get_preview RPC, guests lookup (service role), storage batch sign.
function fakeSupabase({ preview = PREVIEW, customization = {}, calls = [] } = {}) {
  return async (url, init = {}) => {
    calls.push({ url, init });
    if (url.endsWith('/rest/v1/rpc/get_preview')) return Response.json(preview);
    if (url.includes('/rest/v1/guests?')) return Response.json([{ event_id: EVENT, events: { customization } }]);
    if (url.endsWith('/storage/v1/object/sign/event-media')) {
      const { paths } = JSON.parse(init.body);
      return Response.json(paths.map((p) => ({ path: p, signedURL: `/object/sign/event-media/${p}?token=t-${p.length}`, error: null })));
    }
    return new Response('unexpected', { status: 500 });
  };
}

const whatsapp = (code = 'K7D2M9QX') =>
  new Request(`https://devet.pages.test/i/${code}`, { headers: { 'user-agent': 'WhatsApp/2.0', 'accept-language': 'en' } });
const meta = (html, prop) => new RegExp(`<meta property="${prop}" content="([^"]*)">`).exec(html)?.[1];

test('WhatsApp request gets personalised og: tags in the guest language', async () => {
  const res = await handleInvite({ params: { code: 'K7D2M9QX' }, request: whatsapp(), env: makeEnv() }, fakeSupabase());
  assert.equal(res.status, 200);
  const html = await res.text();
  assert.equal(meta(html, 'og:title'), 'Elçin müəllim və ailəsi, sizi Aysel və Ramin toyuna dəvət edirik');
  assert.equal(meta(html, 'og:description'), '10 iyul 2027 · Gülüstan sarayı');
  assert.equal(meta(html, 'og:url'), 'https://devet.pages.test/i/K7D2M9QX');
  assert.equal(meta(html, 'og:image'), 'https://devet.pages.test/templates/free-01/thumb.jpg');
  assert.equal(meta(html, 'og:locale'), 'az_AZ');
  assert.match(html, /<title>Elçin müəllim və ailəsi, sizi Aysel və Ramin toyuna dəvət edirik<\/title>/);
  assert.doesNotMatch(html, /<title>Template<\/title>/);
  assert.match(html, /<meta name="robots" content="noindex, nofollow">/);
  assert.equal(res.headers.get('cache-control'), 'public, max-age=300');
});

test('named preview image is used when present', async () => {
  const preview = { ...PREVIEW, preview_url: 'https://proj.supabase.test/storage/v1/object/public/previews/K7D2M9QX.jpg' };
  const html = await (await handleInvite({ params: { code: 'K7D2M9QX' }, request: whatsapp(), env: makeEnv() }, fakeSupabase({ preview }))).text();
  assert.equal(meta(html, 'og:image'), preview.preview_url);
  assert.equal(meta(html, 'og:image:width'), '1200');
  assert.equal(meta(html, 'og:image:height'), '630');
});

test('og text follows guest language and event type', () => {
  const ru = ogData({ ...PREVIEW, lang: 'ru', display_name: 'Rəşad бей с семьёй', event_type: 'engagement' }, { code: 'R5T6Y7B2', baseUrl: 'https://x' });
  assert.equal(ru.title, 'Rəşad бей с семьёй, приглашаем вас на помолвку: Aysel və Ramin');
  assert.equal(ru.description, '10 июля 2027 г. · Gülüstan sarayı');
  const tr = ogData({ ...PREVIEW, lang: 'tr', display_name: 'Səbinə Hanım', event_type: 'birthday', venue_name: null }, { code: 'Q2W3E4R5', baseUrl: 'https://x' });
  assert.equal(tr.title, 'Səbinə Hanım, doğum gününe davetlisiniz: Aysel və Ramin');
  assert.equal(tr.description, '10 Temmuz 2027');
});

test('og values are HTML-escaped', async () => {
  const preview = { ...PREVIEW, display_name: '"><script>x</script>', title_names: 'A & B' };
  const html = await (await handleInvite({ params: { code: 'K7D2M9QX' }, request: whatsapp(), env: makeEnv() }, fakeSupabase({ preview }))).text();
  assert.doesNotMatch(html, /"><script>x<\/script>/);
  assert.match(meta(html, 'og:title'), /&quot;&gt;&lt;script&gt;x&lt;\/script&gt;/);
  assert.match(meta(html, 'og:title'), /A &amp; B/);
});

test('javascript: preview_url falls back to the thumbnail', async () => {
  const preview = { ...PREVIEW, preview_url: 'javascript:alert(1)' };
  const html = await (await handleInvite({ params: { code: 'K7D2M9QX' }, request: whatsapp(), env: makeEnv() }, fakeSupabase({ preview }))).text();
  assert.equal(meta(html, 'og:image'), 'https://devet.pages.test/templates/free-01/thumb.jpg');
});

test('allowedPath accepts only this event\'s photos/music files', () => {
  assert.ok(allowedPath(EVENT, `${EVENT}/photos/1.jpg`, 'photos'));
  assert.ok(allowedPath(EVENT, `${EVENT}/music/song.mp3`, 'music'));
  assert.ok(!allowedPath(EVENT, `${OTHER}/photos/1.jpg`, 'photos'), 'other event');
  assert.ok(!allowedPath(EVENT, `${EVENT}/music/song.mp3`, 'photos'), 'wrong folder');
  assert.ok(!allowedPath(EVENT, `${EVENT}/photos/../../${OTHER}/photos/1.jpg`, 'photos'), 'traversal');
  assert.ok(!allowedPath(EVENT, `${EVENT}/photos/`, 'photos'), 'empty name');
  assert.ok(!allowedPath(EVENT, null, 'photos'));
});

test('media is signed with the service role key, filtered, and the key never reaches the page', async () => {
  const calls = [];
  const customization = {
    photos: [`${EVENT}/photos/1.jpg`, `${OTHER}/photos/secret.jpg`, `${EVENT}/photos/2.jpg`],
    music: `${EVENT}/music/song.mp3`,
  };
  const env = makeEnv({ SUPABASE_SERVICE_ROLE_KEY: 'service-role-SECRET' });
  const res = await handleInvite({ params: { code: 'K7D2M9QX' }, request: whatsapp(), env }, fakeSupabase({ customization, calls }));
  const html = await res.text();
  assert.doesNotMatch(html, /service-role-SECRET/);
  const config = JSON.parse(/<script id="invite-config" type="application\/json">(.*?)<\/script>/.exec(html)[1]);
  assert.deepEqual(config.media, {
    photos: [
      `https://proj.supabase.test/storage/v1/object/sign/event-media/${EVENT}/photos/1.jpg?token=t-49`,
      `https://proj.supabase.test/storage/v1/object/sign/event-media/${EVENT}/photos/2.jpg?token=t-49`,
    ],
    music: `https://proj.supabase.test/storage/v1/object/sign/event-media/${EVENT}/music/song.mp3?token=t-51`,
  });
  assert.equal(config.anon_key, 'anon-key');

  const sign = calls.find((c) => c.url.endsWith('/sign/event-media'));
  assert.deepEqual(JSON.parse(sign.init.body), { expiresIn: SIGNED_URL_TTL_SECONDS, paths: [`${EVENT}/photos/1.jpg`, `${EVENT}/photos/2.jpg`, `${EVENT}/music/song.mp3`] });
  assert.equal(sign.init.headers.authorization, 'Bearer service-role-SECRET');
  const rpc = calls.find((c) => c.url.endsWith('/rpc/get_preview'));
  assert.equal(rpc.init.headers.apikey, 'anon-key', 'guest RPC still uses the anon key');
});

test('no service key or failing storage -> page still served with empty media', async () => {
  assert.deepEqual(await signedMedia(makeEnv(), 'K7D2M9QX', fakeSupabase()), { photos: [], music: null });
  const failing = async () => { throw new TypeError('down'); };
  assert.deepEqual(await signedMedia(makeEnv({ SUPABASE_SERVICE_ROLE_KEY: 'k' }), 'K7D2M9QX', failing), { photos: [], music: null });
});
