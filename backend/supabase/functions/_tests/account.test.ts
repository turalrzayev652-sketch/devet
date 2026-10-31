// node --experimental-strip-types --test backend/supabase/functions/_tests/account.test.ts
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteAccount } from '../_shared/account.ts';
import type { Config } from '../_shared/config.ts';

const USER = '11111111-1111-1111-1111-111111111111';
const E1 = '22222222-2222-2222-2222-222222222222';
const cfg: Config = { db: { url: 'https://proj.supabase.test', serviceKey: 'service-key' }, google: null, apple: null, notificationToken: null };

type Call = { url: string; method: string; body: any; headers: Record<string, string> };
function world(over: Partial<Record<string, (c: Call) => Response>> = {}) {
  const calls: Call[] = [];
  const files: Record<string, Array<{ name: string; id: string | null }>> = {
    [`${E1}/photos`]: [{ name: '1.jpg', id: 'a' }, { name: '2.jpg', id: 'b' }, { name: 'old', id: null }],
    [`${E1}/music`]: [{ name: 'song.mp3', id: 'c' }],
  };
  const routes: Record<string, (c: Call) => Response> = {
    user: (c) => (c.headers.authorization === 'Bearer user-jwt' ? Response.json({ id: USER }) : new Response('', { status: 401 })),
    plan: () => Response.json({ owned_events: [E1], cohost_events: ['efefefef-efef-efef-efef-efefefefefef'], preview_files: ['K7D2M9QX.jpg', 'P3H8W4ZA.jpg'] }),
    list: (c) => Response.json(files[c.body.prefix] ?? []),
    remove: () => Response.json([]),
    data: () => Response.json({ ok: true, deleted_events: 1, left_events: 1 }),
    authDelete: () => new Response(null, { status: 200 }),
    ...over,
  };
  const fetchImpl = (async (input: string, init: RequestInit = {}) => {
    const url = String(input);
    const call: Call = { url, method: init.method ?? 'GET', body: init.body ? JSON.parse(String(init.body)) : null, headers: (init.headers ?? {}) as Record<string, string> };
    calls.push(call);
    if (url.endsWith('/auth/v1/user')) return routes.user(call);
    if (url.endsWith('/rpc/account_deletion_plan')) return routes.plan(call);
    if (url.includes('/storage/v1/object/list/')) return routes.list(call);
    if (/\/storage\/v1\/object\/(event-media|previews)$/.test(url) && call.method === 'DELETE') return routes.remove(call);
    if (url.endsWith('/rpc/delete_account_data')) return routes.data(call);
    if (url.includes('/auth/v1/admin/users/')) return routes.authDelete(call);
    return new Response('no route', { status: 599 });
  }) as typeof fetch;
  return { fetchImpl, calls };
}

const step = (c: Call) =>
  c.url.endsWith('/auth/v1/user') ? 'user'
  : c.url.endsWith('account_deletion_plan') ? 'plan'
  : c.url.includes('/object/list/') ? 'list'
  : c.method === 'DELETE' && c.url.includes('/storage/') ? `remove:${c.url.split('/').pop()}`
  : c.url.endsWith('delete_account_data') ? 'data'
  : c.url.includes('/admin/users/') ? 'auth' : c.url;

test('deletes files first, then data, then the auth user', async () => {
  const { fetchImpl, calls } = world();
  const r = await deleteAccount(cfg, 'Bearer user-jwt', fetchImpl);
  assert.deepEqual(r, { status: 200, body: { ok: true, deleted_events: 1, left_events: 1 } });
  assert.deepEqual(calls.map(step), ['user', 'plan', 'list', 'list', 'remove:event-media', 'remove:previews', 'data', 'auth']);
  const media = calls.find((c) => c.url.endsWith('/object/event-media'))!;
  assert.deepEqual(media.body, { prefixes: [`${E1}/photos/1.jpg`, `${E1}/photos/2.jpg`, `${E1}/music/song.mp3`] }, 'sub-folders skipped');
  assert.deepEqual(calls.find((c) => c.url.endsWith('/object/previews'))!.body, { prefixes: ['K7D2M9QX.jpg', 'P3H8W4ZA.jpg'] });
  assert.match(calls.at(-1)!.url, new RegExp(`/auth/v1/admin/users/${USER}$`));
  assert.equal(calls.at(-1)!.headers.authorization, 'Bearer service-key');
});

test('no or invalid token -> 401, nothing touched', async () => {
  const { fetchImpl, calls } = world();
  assert.equal((await deleteAccount(cfg, null, fetchImpl)).status, 401);
  assert.equal((await deleteAccount(cfg, 'Bearer forged', fetchImpl)).status, 401);
  assert.ok(calls.every((c) => step(c) === 'user'));
});

test('storage failure -> 502 and no data or user is deleted', async () => {
  const { fetchImpl, calls } = world({ remove: () => new Response('', { status: 500 }) });
  const r = await deleteAccount(cfg, 'Bearer user-jwt', fetchImpl);
  assert.deepEqual(r, { status: 502, body: { ok: false, error: 'storage_unavailable' } });
  assert.ok(!calls.some((c) => ['data', 'auth'].includes(step(c))));
});

test('auth deletion failure -> 502 delete_failed (retry finishes it)', async () => {
  const { fetchImpl } = world({ authDelete: () => new Response('', { status: 500 }) });
  assert.deepEqual(await deleteAccount(cfg, 'Bearer user-jwt', fetchImpl), { status: 502, body: { ok: false, error: 'delete_failed' } });
});

test('user without events: no storage deletes needed beyond empty batches, still succeeds', async () => {
  const { fetchImpl, calls } = world({ plan: () => Response.json({ owned_events: [], cohost_events: [], preview_files: [] }), data: () => Response.json({ ok: true, deleted_events: 0, left_events: 0 }) });
  const r = await deleteAccount(cfg, 'Bearer user-jwt', fetchImpl);
  assert.equal(r.status, 200);
  assert.ok(!calls.some((c) => step(c).startsWith('remove') || step(c) === 'list'), 'no storage calls for empty lists');
});

test('large folders are paged and deleted in batches of 100', async () => {
  const many = Array.from({ length: 1000 }, (_, i) => ({ name: `${i}.jpg`, id: String(i) }));
  const rest = Array.from({ length: 50 }, (_, i) => ({ name: `x${i}.jpg`, id: `x${i}` }));
  const { fetchImpl, calls } = world({
    list: (c) => Response.json(c.body.prefix.endsWith('/photos') ? (c.body.offset === 0 ? many : rest) : []),
  });
  await deleteAccount(cfg, 'Bearer user-jwt', fetchImpl);
  const removes = calls.filter((c) => c.url.endsWith('/object/event-media'));
  assert.equal(removes.length, 11);
  assert.equal(removes.reduce((n, c) => n + c.body.prefixes.length, 0), 1050);
});
