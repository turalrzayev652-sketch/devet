import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { handleInvite } from '../src/server/invite-handler.js';
import { pickLang, LANGS } from '../src/server/i18n.js';
import { normalizeCode } from '../src/server/supabase.js';

const env = (assets = {}) => ({
  SUPABASE_URL: 'http://supabase.test',
  SUPABASE_ANON_KEY: 'anon-test-key',
  ASSETS: {
    fetch: async (url) => {
      const body = assets[new URL(url).pathname];
      return body ? new Response(body, { status: 200 }) : new Response('nope', { status: 404 });
    },
  },
});
const req = (path, lang = 'az') =>
  new Request(`http://localhost:8788${path}`, { headers: { 'accept-language': lang } });
const rpcReturning = (json, status = 200) => async () => new Response(JSON.stringify(json), { status });

test('pickLang honours Accept-Language and falls back to az', () => {
  assert.equal(pickLang('ru-RU,ru;q=0.9,en;q=0.8'), 'ru');
  assert.equal(pickLang('de-DE,en;q=0.5'), 'en');
  assert.equal(pickLang('fr;q=1, tr;q=0.4'), 'tr');
  assert.equal(pickLang('de'), 'az');
  assert.equal(pickLang(null), 'az');
});

test('normalizeCode accepts only 8-char base32 codes', () => {
  assert.equal(normalizeCode(' k7d2m9qx '), 'K7D2M9QX');
  assert.equal(normalizeCode('test'), null);
  assert.equal(normalizeCode('IIIIIIII'), null);
  assert.equal(normalizeCode('K7D2M9QX1'), null);
});

test('every invite.json key has all four languages', () => {
  const strings = JSON.parse(readFileSync(new URL('../../spec/i18n/invite.json', import.meta.url)));
  for (const [key, entry] of Object.entries(strings)) {
    assert.deepEqual(Object.keys(entry).sort(), [...LANGS].sort(), key);
    for (const l of LANGS) assert.ok(entry[l].trim(), `${key}.${l} empty`);
  }
});

test('/i/test shows the not-found screen (no RPC call for malformed codes)', async () => {
  let called = false;
  const res = await handleInvite({ params: { code: 'test' }, request: req('/i/test'), env: env() }, async () => {
    called = true;
  });
  assert.equal(res.status, 404);
  const html = await res.text();
  assert.match(html, /data-error="not_found"/);
  assert.match(html, /Dəvətnamə tapılmadı/);
  assert.equal(called, false);
});

test('not-found screen follows the browser language', async () => {
  const res = await handleInvite({ params: { code: 'test' }, request: req('/i/test', 'ru'), env: env() });
  assert.match(await res.text(), /Приглашение не найдено/);
});

test('unknown valid code -> not_found from RPC', async () => {
  const res = await handleInvite(
    { params: { code: 'ZZZZZZZZ' }, request: req('/i/ZZZZZZZZ', 'en'), env: env() },
    rpcReturning({ ok: false, error: 'not_found' }),
  );
  assert.equal(res.status, 404);
  assert.match(await res.text(), /Invitation not found/);
});

test('Supabase unreachable -> network screen with retry', async () => {
  const res = await handleInvite(
    { params: { code: 'K7D2M9QX' }, request: req('/i/K7D2M9QX'), env: env() },
    async () => { throw new TypeError('fetch failed'); },
  );
  assert.equal(res.status, 503);
  const html = await res.text();
  assert.match(html, /data-error="network"/);
  assert.match(html, /Yenidən cəhd et/);
});

test('missing config -> network screen, not a crash', async () => {
  const res = await handleInvite({ params: { code: 'K7D2M9QX' }, request: req('/i/K7D2M9QX'), env: { ASSETS: env().ASSETS } });
  assert.equal(res.status, 503);
});

test('valid code -> serves the template page, calls RPC with anon key only', async () => {
  let sent;
  const fetchImpl = async (url, init) => {
    sent = { url, init };
    return new Response(JSON.stringify({ ok: true, lang: 'az', template_id: 'free-01' }), { status: 200 });
  };
  const res = await handleInvite(
    { params: { code: 'k7d2m9qx' }, request: req('/i/k7d2m9qx'), env: env({ '/templates/free-01/index.html': '<p>tpl</p>' }) },
    fetchImpl,
  );
  assert.equal(res.status, 200);
  assert.equal(await res.text(), '<p>tpl</p>');
  assert.equal(sent.url, 'http://supabase.test/rest/v1/rpc/get_preview');
  assert.deepEqual(JSON.parse(sent.init.body), { code: 'K7D2M9QX' });
  assert.equal(sent.init.headers.apikey, 'anon-test-key');
});

test('valid code but template missing -> not_found', async () => {
  const res = await handleInvite(
    { params: { code: 'K7D2M9QX' }, request: req('/i/K7D2M9QX'), env: env() },
    rpcReturning({ ok: true, lang: 'tr', template_id: 'nope' }),
  );
  assert.equal(res.status, 404);
  assert.match(await res.text(), /Davetiye bulunamadı/);
});

test('error text is HTML-escaped', async () => {
  const { errorPageHtml } = await import('../src/server/error-page.js');
  assert.doesNotMatch(errorPageHtml('not_found', 'az'), /<script/);
});
