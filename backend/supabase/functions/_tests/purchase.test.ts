// Unit tests for the purchase Edge Functions' shared logic. Runs on Node 22 (no Deno needed):
//   node --experimental-strip-types --test backend/supabase/functions/_tests/purchase.test.ts
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { base64url, base64urlDecode, signJwt, importRsaPrivateKey, importEcPrivateKey, decodeJwsPayload, sha256Hex } from '../_shared/jwt.ts';
import { resetGoogleTokenCache, type GoogleConfig } from '../_shared/google-play.ts';
import { appleAuthToken, type AppleConfig } from '../_shared/app-store.ts';
import { verifyPurchase } from '../_shared/verify.ts';
import { handleAppleNotification, handleGoogleNotification } from '../_shared/notifications.ts';
import { loadConfig, type Config } from '../_shared/config.ts';

const USER = '11111111-1111-1111-1111-111111111111';
const EVENT = 'abababab-abab-abab-abab-abababababab';

// ---------------------------------------------------------------------------
// Keys and helpers
// ---------------------------------------------------------------------------

const toPem = (der: ArrayBuffer) => `-----BEGIN PRIVATE KEY-----\n${btoa(String.fromCharCode(...new Uint8Array(der))).replace(/(.{64})/g, '$1\n')}\n-----END PRIVATE KEY-----\n`;
const rsa = await crypto.subtle.generateKey({ name: 'RSASSA-PKCS1-v1_5', modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256' }, true, ['sign', 'verify']);
const ec = await crypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign', 'verify']);
const RSA_PEM = toPem(await crypto.subtle.exportKey('pkcs8', rsa.privateKey));
const EC_PEM = toPem(await crypto.subtle.exportKey('pkcs8', ec.privateKey));

const jws = (payload: unknown) => `eyJhbGciOiJFUzI1NiJ9.${base64url(JSON.stringify(payload))}.c2ln`;

async function verifySignature(jwt: string, key: CryptoKey, alg: 'RS256' | 'ES256') {
  const [h, p, s] = jwt.split('.');
  const algorithm = alg === 'ES256' ? { name: 'ECDSA', hash: 'SHA-256' } : { name: 'RSASSA-PKCS1-v1_5' };
  return crypto.subtle.verify(algorithm, key, base64urlDecode(s), new TextEncoder().encode(`${h}.${p}`));
}

const GOOGLE: GoogleConfig = { packageName: 'az.devet.app', clientEmail: 'sa@devet.iam.gserviceaccount.com', privateKey: RSA_PEM, allowTestPurchases: false };
const APPLE: AppleConfig = { bundleId: 'az.devet.app', issuerId: 'issuer-1', keyId: 'KEY123', privateKey: EC_PEM, allowSandbox: false };
const config = (over: Partial<Config> = {}): Config => ({
  db: { url: 'https://proj.supabase.test', serviceKey: 'service-key' },
  google: GOOGLE, apple: APPLE, notificationToken: 'notify-secret', ...over,
});

type Call = { url: string; method: string; body: any; headers: Record<string, string> };
type Route = [RegExp, (call: Call) => Response | Promise<Response>];

// Fake HTTP world: routes by URL regex, records every call in order.
function fakeFetch(routes: Route[]) {
  const calls: Call[] = [];
  const impl = async (input: string | URL | Request, init: RequestInit = {}) => {
    const url = String(input);
    let body: any = init.body;
    try { body = typeof body === 'string' ? JSON.parse(body) : body; } catch { /* form body */ }
    const call = { url, method: init.method ?? 'GET', body, headers: (init.headers ?? {}) as Record<string, string> };
    calls.push(call);
    for (const [re, handler] of routes) if (re.test(url)) return handler(call);
    return new Response(`no route for ${url}`, { status: 599 });
  };
  return { fetch: impl as typeof fetch, calls };
}

const authOk: Route = [/\/auth\/v1\/user$/, (c) => (c.headers.authorization === 'Bearer user-jwt' ? Response.json({ id: USER }) : new Response('', { status: 401 }))];
const googleToken: Route = [/oauth2\.googleapis\.com\/token$/, () => Response.json({ access_token: 'g-access', expires_in: 3600 })];
const recordOk: Route = [/\/rpc\/record_purchase$/, () => Response.json({ ok: true, status: 'created', kind: 'template', is_paid: true, guest_limit: 300 })];
const consumeOk: Route = [/:consume$/, () => new Response(null, { status: 204 })];
const googlePurchase = (p: Record<string, unknown>): Route => [/\/purchases\/products\/[^/]+\/tokens\/[^/:]+$/, () => Response.json(p)];

const googleBody = (over: Record<string, unknown> = {}) => ({ store: 'google', event_id: EVENT, product_id: 'template_premium_01', purchase_token: 'tok-123', ...over });
const appleBody = (over: Record<string, unknown> = {}) => ({ store: 'apple', event_id: EVENT, product_id: 'limit_addon_200', transaction_id: '2000000001', ...over });
const appleTx = (over: Record<string, unknown> = {}) => ({ transactionId: '2000000001', bundleId: 'az.devet.app', productId: 'limit_addon_200', appAccountToken: USER, price: 4990, currency: 'AZN', environment: 'Production', ...over });

// ---------------------------------------------------------------------------
// JWT
// ---------------------------------------------------------------------------

test('RS256 and ES256 JWTs verify with the matching public keys', async () => {
  const rs = await signJwt({ alg: 'RS256', typ: 'JWT' }, { a: 1 }, await importRsaPrivateKey(RSA_PEM));
  assert.ok(await verifySignature(rs, rsa.publicKey, 'RS256'));
  const es = await signJwt({ alg: 'ES256', typ: 'JWT' }, { b: 2 }, await importEcPrivateKey(EC_PEM));
  assert.equal(base64urlDecode(es.split('.')[2]).length, 64, 'ES256 signature is raw r||s');
  assert.ok(await verifySignature(es, ec.publicKey, 'ES256'));
  assert.deepEqual(decodeJwsPayload(es), { b: 2 });
});

test('private keys with escaped \\n (as stored in env JSON) still import', async () => {
  await importRsaPrivateKey(RSA_PEM.replace(/\n/g, '\\n'));
});

test('Apple auth token has the App Store Server API claims', async () => {
  const token = await appleAuthToken(APPLE, Date.parse('2027-01-01T00:00:00Z'));
  const [h] = token.split('.');
  assert.deepEqual(JSON.parse(new TextDecoder().decode(base64urlDecode(h))), { alg: 'ES256', kid: 'KEY123', typ: 'JWT' });
  const p = decodeJwsPayload<any>(token);
  assert.equal(p.iss, 'issuer-1');
  assert.equal(p.aud, 'appstoreconnect-v1');
  assert.equal(p.bid, 'az.devet.app');
  assert.ok(p.exp - p.iat <= 3600);
  assert.ok(await verifySignature(token, ec.publicKey, 'ES256'));
});

// ---------------------------------------------------------------------------
// verify-purchase: Google
// ---------------------------------------------------------------------------

test('google: valid purchase is recorded, then consumed; service account JWT is signed correctly', async () => {
  resetGoogleTokenCache();
  const { fetch, calls } = fakeFetch([authOk, googleToken, googlePurchase({ purchaseState: 0, consumptionState: 0, orderId: 'GPA.1234', obfuscatedExternalAccountId: USER, obfuscatedExternalProfileId: EVENT }), recordOk, consumeOk]);
  const r = await verifyPurchase(config(), { authorization: 'Bearer user-jwt', body: googleBody() }, fetch);
  assert.equal(r.status, 200);
  assert.deepEqual(r.body, { ok: true, status: 'created', kind: 'template', is_paid: true, guest_limit: 300 });

  const record = calls.find((c) => c.url.endsWith('/rpc/record_purchase'))!;
  assert.deepEqual(record.body, { p_user_id: USER, p_event_id: EVENT, p_product_id: 'template_premium_01', p_store: 'google', p_transaction_id: 'GPA.1234', p_amount_minor: null, p_currency: null });
  assert.equal(record.headers.authorization, 'Bearer service-key');
  const order = calls.map((c) => (c.url.endsWith(':consume') ? 'consume' : c.url.endsWith('record_purchase') ? 'record' : null)).filter(Boolean);
  assert.deepEqual(order, ['record', 'consume'], 'consume only after recording');
  assert.match(calls.find((c) => /tokens\/tok-123$/.test(c.url))!.url, /applications\/az\.devet\.app\/purchases\/products\/template_premium_01\/tokens\/tok-123$/);

  const assertion = new URLSearchParams(calls.find((c) => c.url.includes('oauth2'))!.body).get('assertion')!;
  const claims = decodeJwsPayload<any>(assertion);
  assert.equal(claims.iss, GOOGLE.clientEmail);
  assert.equal(claims.scope, 'https://www.googleapis.com/auth/androidpublisher');
  assert.ok(await verifySignature(assertion, rsa.publicKey, 'RS256'));
});

test('google: already consumed purchase (retry) is recorded idempotently without consuming again', async () => {
  const { fetch, calls } = fakeFetch([authOk, googleToken, googlePurchase({ purchaseState: 0, consumptionState: 1, orderId: 'GPA.1234' }),
    [/record_purchase$/, () => Response.json({ ok: true, status: 'already_recorded' })], consumeOk]);
  const r = await verifyPurchase(config(), { authorization: 'Bearer user-jwt', body: googleBody() }, fetch);
  assert.equal(r.body.status, 'already_recorded');
  assert.ok(!calls.some((c) => c.url.endsWith(':consume')));
});

test('google: purchase without orderId uses a hash of the token as transaction id', async () => {
  const { fetch, calls } = fakeFetch([authOk, googleToken, googlePurchase({ purchaseState: 0, purchaseType: 0 }), recordOk, consumeOk]);
  await verifyPurchase(config({ google: { ...GOOGLE, allowTestPurchases: true } }), { authorization: 'Bearer user-jwt', body: googleBody() }, fetch);
  assert.equal(calls.find((c) => c.url.endsWith('record_purchase'))!.body.p_transaction_id, `token:${await sha256Hex('tok-123')}`);
});

for (const [name, purchase, error, status] of [
  ['pending', { purchaseState: 2, orderId: 'GPA.1' }, 'purchase_pending', 422],
  ['cancelled', { purchaseState: 1, orderId: 'GPA.1' }, 'purchase_cancelled', 422],
  ['test purchase when not allowed', { purchaseState: 0, purchaseType: 0, orderId: 'GPA.1' }, 'test_purchase_not_allowed', 422],
  ['promo code', { purchaseState: 0, purchaseType: 1, orderId: 'GPA.1' }, 'purchase_mismatch', 422],
  ['bought by another user', { purchaseState: 0, orderId: 'GPA.1', obfuscatedExternalAccountId: 'someone-else' }, 'purchase_mismatch', 422],
  ['bought for another event', { purchaseState: 0, orderId: 'GPA.1', obfuscatedExternalProfileId: '99999999-9999-9999-9999-999999999999' }, 'purchase_mismatch', 422],
] as const) {
  test(`google: ${name} -> ${error}, nothing recorded or consumed`, async () => {
    const { fetch, calls } = fakeFetch([authOk, googleToken, googlePurchase(purchase), recordOk, consumeOk]);
    const r = await verifyPurchase(config(), { authorization: 'Bearer user-jwt', body: googleBody() }, fetch);
    assert.deepEqual([r.status, r.body], [status, { ok: false, error }]);
    assert.ok(!calls.some((c) => c.url.endsWith('record_purchase') || c.url.endsWith(':consume')));
  });
}

test('google: unknown token -> purchase_not_found; store outage -> store_unavailable', async () => {
  let f = fakeFetch([authOk, googleToken, [/tokens\//, () => new Response('', { status: 404 })]]);
  assert.equal((await verifyPurchase(config(), { authorization: 'Bearer user-jwt', body: googleBody() }, f.fetch)).body.error, 'purchase_not_found');
  f = fakeFetch([authOk, googleToken, [/tokens\//, () => new Response('', { status: 503 })]]);
  const r = await verifyPurchase(config(), { authorization: 'Bearer user-jwt', body: googleBody() }, f.fetch);
  assert.deepEqual([r.status, r.body.error], [502, 'store_unavailable']);
});

test('database refusal (e.g. not_member) is passed through and nothing is consumed', async () => {
  const { fetch, calls } = fakeFetch([authOk, googleToken, googlePurchase({ purchaseState: 0, orderId: 'GPA.9' }),
    [/record_purchase$/, () => Response.json({ ok: false, error: 'not_member' })], consumeOk]);
  const r = await verifyPurchase(config(), { authorization: 'Bearer user-jwt', body: googleBody() }, fetch);
  assert.deepEqual([r.status, r.body], [403, { ok: false, error: 'not_member' }]);
  assert.ok(!calls.some((c) => c.url.endsWith(':consume')));
});

// ---------------------------------------------------------------------------
// verify-purchase: request checks
// ---------------------------------------------------------------------------

test('no or invalid user token -> 401 before any store call', async () => {
  const { fetch, calls } = fakeFetch([authOk]);
  assert.equal((await verifyPurchase(config(), { authorization: null, body: googleBody() }, fetch)).status, 401);
  assert.equal((await verifyPurchase(config(), { authorization: 'Bearer forged', body: googleBody() }, fetch)).status, 401);
  assert.ok(calls.every((c) => c.url.endsWith('/auth/v1/user')));
});

for (const [name, body] of [
  ['unknown store', googleBody({ store: 'paypal' })],
  ['bad event id', googleBody({ event_id: 'x' })],
  ['bad product id', googleBody({ product_id: '../../etc' })],
  ['missing purchase token', googleBody({ purchase_token: '' })],
  ['apple non-numeric transaction', appleBody({ transaction_id: 'abc' })],
  ['empty body', null],
] as const) {
  test(`invalid request: ${name} -> 400`, async () => {
    const { fetch } = fakeFetch([authOk]);
    const r = await verifyPurchase(config(), { authorization: 'Bearer user-jwt', body }, fetch);
    assert.deepEqual([r.status, r.body.error], [400, 'invalid_request']);
  });
}

test('store not configured -> 503', async () => {
  const { fetch } = fakeFetch([authOk]);
  assert.deepEqual((await verifyPurchase(config({ google: null }), { authorization: 'Bearer user-jwt', body: googleBody() }, fetch)).body.error, 'store_not_configured');
  assert.deepEqual((await verifyPurchase(config({ apple: null }), { authorization: 'Bearer user-jwt', body: appleBody() }, fetch)).status, 503);
});

// ---------------------------------------------------------------------------
// verify-purchase: Apple
// ---------------------------------------------------------------------------

const appleProd = (tx: unknown, status = 200): Route => [/api\.storekit\.itunes\.apple\.com\/inApps\/v1\/transactions\//, () => (status === 200 ? Response.json({ signedTransactionInfo: jws(tx) }) : new Response('', { status }))];
const appleSandbox = (tx: unknown): Route => [/api\.storekit-sandbox\.itunes\.apple\.com/, () => Response.json({ signedTransactionInfo: jws(tx) })];

test('apple: valid transaction recorded with amount in minor units', async () => {
  const { fetch, calls } = fakeFetch([authOk, appleProd(appleTx()), recordOk]);
  const r = await verifyPurchase(config(), { authorization: 'Bearer user-jwt', body: appleBody() }, fetch);
  assert.equal(r.status, 200);
  const rec = calls.find((c) => c.url.endsWith('record_purchase'))!.body;
  assert.deepEqual([rec.p_store, rec.p_transaction_id, rec.p_amount_minor, rec.p_currency], ['apple', '2000000001', 499, 'AZN']);
  const apiCall = calls.find((c) => c.url.includes('storekit'))!;
  assert.ok(await verifySignature(apiCall.headers.authorization.slice(7), ec.publicKey, 'ES256'), 'App Store API call is authenticated');
});

test('apple: sandbox transaction is found only when sandbox is allowed', async () => {
  let f = fakeFetch([authOk, appleProd(null, 404), appleSandbox(appleTx({ environment: 'Sandbox' })), recordOk]);
  assert.equal((await verifyPurchase(config(), { authorization: 'Bearer user-jwt', body: appleBody() }, f.fetch)).body.error, 'purchase_not_found');
  assert.ok(!f.calls.some((c) => c.url.includes('sandbox')));
  f = fakeFetch([authOk, appleProd(null, 404), appleSandbox(appleTx({ environment: 'Sandbox' })), recordOk]);
  const r = await verifyPurchase(config({ apple: { ...APPLE, allowSandbox: true } }), { authorization: 'Bearer user-jwt', body: appleBody() }, f.fetch);
  assert.equal(r.status, 200);
});

for (const [name, tx, error] of [
  ['other app', appleTx({ bundleId: 'com.other' }), 'purchase_mismatch'],
  ['other product', appleTx({ productId: 'template_premium_01' }), 'purchase_mismatch'],
  ['other user', appleTx({ appAccountToken: '22222222-2222-2222-2222-222222222222' }), 'purchase_mismatch'],
  ['revoked', appleTx({ revocationDate: 1800000000000 }), 'revoked'],
  ['different transaction id', appleTx({ transactionId: '2000000099' }), 'purchase_mismatch'],
] as const) {
  test(`apple: ${name} -> ${error}`, async () => {
    const { fetch, calls } = fakeFetch([authOk, appleProd(tx), recordOk]);
    const r = await verifyPurchase(config(), { authorization: 'Bearer user-jwt', body: appleBody() }, fetch);
    assert.deepEqual(r.body, { ok: false, error });
    assert.ok(!calls.some((c) => c.url.endsWith('record_purchase')));
  });
}

// ---------------------------------------------------------------------------
// store-notifications
// ---------------------------------------------------------------------------

const pubsub = (data: unknown) => ({ message: { data: btoa(JSON.stringify(data)), messageId: '1' }, subscription: 's' });
const voided = (orderId: string) => pubsub({ packageName: 'az.devet.app', voidedPurchaseNotification: { purchaseToken: 'tok-123', orderId, productType: 2 } });
const refundOk: Route = [/record_refund$/, (c) => Response.json({ ok: true, status: 'refunded', event_id: EVENT, txn: c.body.p_transaction_id })];

test('google refund: wrong or missing token -> 401, nothing checked', async () => {
  const { fetch, calls } = fakeFetch([]);
  assert.equal((await handleGoogleNotification(config(), 'wrong', voided('GPA.1'), fetch)).status, 401);
  assert.equal((await handleGoogleNotification(config(), null, voided('GPA.1'), fetch)).status, 401);
  assert.equal((await handleGoogleNotification(config({ notificationToken: null }), 'notify-secret', voided('GPA.1'), fetch)).status, 401);
  assert.equal(calls.length, 0);
});

test('google refund: confirmed by the Voided Purchases API -> recorded', async () => {
  resetGoogleTokenCache();
  const { fetch, calls } = fakeFetch([googleToken, [/voidedpurchases/, () => Response.json({ voidedPurchases: [{ orderId: 'GPA.1234', purchaseToken: 'tok-123' }] })], refundOk]);
  const r = await handleGoogleNotification(config(), 'notify-secret', voided('GPA.1234'), fetch);
  assert.deepEqual(r, { status: 200, body: { ok: true, outcome: 'refunded', event_id: EVENT } });
  assert.deepEqual(calls.find((c) => c.url.endsWith('record_refund'))!.body, { p_store: 'google', p_transaction_id: 'GPA.1234' });
});

test('google refund: forged notification (not voided at Google) -> nothing refunded', async () => {
  const { fetch, calls } = fakeFetch([googleToken, [/voidedpurchases/, () => Response.json({ voidedPurchases: [] })], refundOk]);
  const r = await handleGoogleNotification(config(), 'notify-secret', voided('GPA.1234'), fetch);
  assert.equal(r.body.outcome, 'not_confirmed');
  assert.ok(!calls.some((c) => c.url.endsWith('record_refund')));
});

test('google: other notification types and packages are acknowledged and ignored', async () => {
  const { fetch, calls } = fakeFetch([]);
  assert.equal((await handleGoogleNotification(config(), 'notify-secret', pubsub({ packageName: 'az.devet.app', testNotification: { version: '1.0' } }), fetch)).body.outcome, 'ignored_type');
  assert.equal((await handleGoogleNotification(config(), 'notify-secret', pubsub({ packageName: 'com.other', voidedPurchaseNotification: {} }), fetch)).body.outcome, 'ignored_package');
  assert.equal((await handleGoogleNotification(config(), 'notify-secret', { message: { data: '%%%' } }, fetch)).status, 400);
  assert.equal(calls.length, 0);
});

const appleNotification = (type: string, tx: unknown) => ({ signedPayload: jws({ notificationType: type, data: { bundleId: 'az.devet.app', signedTransactionInfo: jws(tx) } }) });

test('apple refund: confirmed by the App Store API (revocationDate) -> recorded', async () => {
  const { fetch, calls } = fakeFetch([appleProd(appleTx({ revocationDate: 1800000000000 })), refundOk]);
  const r = await handleAppleNotification(config(), appleNotification('REFUND', appleTx()), fetch);
  assert.equal(r.body.outcome, 'refunded');
  assert.deepEqual(calls.find((c) => c.url.endsWith('record_refund'))!.body, { p_store: 'apple', p_transaction_id: '2000000001' });
});

test('apple refund: forged notification (Apple shows no revocation) -> nothing refunded', async () => {
  const { fetch, calls } = fakeFetch([appleProd(appleTx()), refundOk]);
  const r = await handleAppleNotification(config(), appleNotification('REFUND', appleTx({ revocationDate: 1 })), fetch);
  assert.equal(r.body.outcome, 'not_confirmed');
  assert.ok(!calls.some((c) => c.url.endsWith('record_refund')));
});

test('apple: other types ignored, malformed payload -> 400', async () => {
  const { fetch, calls } = fakeFetch([]);
  assert.equal((await handleAppleNotification(config(), appleNotification('CONSUMPTION_REQUEST', appleTx()), fetch)).body.outcome, 'ignored_type');
  assert.equal((await handleAppleNotification(config(), { signedPayload: 'garbage' }, fetch)).status, 400);
  assert.equal(calls.length, 0);
});

// ---------------------------------------------------------------------------
// config
// ---------------------------------------------------------------------------

test('loadConfig: stores are optional, flags default to false', () => {
  const env: Record<string, string> = { SUPABASE_URL: 'u', SUPABASE_SERVICE_ROLE_KEY: 'k' };
  const c = loadConfig((n) => env[n]);
  assert.equal(c.google, null);
  assert.equal(c.apple, null);
  Object.assign(env, {
    GOOGLE_PLAY_PACKAGE_NAME: 'az.devet.app', GOOGLE_SERVICE_ACCOUNT_JSON: JSON.stringify({ client_email: 'e', private_key: 'p' }),
    APPLE_BUNDLE_ID: 'b', APPLE_ISSUER_ID: 'i', APPLE_KEY_ID: 'k', APPLE_PRIVATE_KEY: 'p', APPLE_ALLOW_SANDBOX: 'true',
  });
  const c2 = loadConfig((n) => env[n]);
  assert.equal(c2.google!.allowTestPurchases, false);
  assert.equal(c2.apple!.allowSandbox, true);
  assert.throws(() => loadConfig(() => undefined));
});

test('google: a failing consume does not fail an already recorded purchase', async () => {
  const { fetch } = fakeFetch([authOk, googleToken, googlePurchase({ purchaseState: 0, consumptionState: 0, orderId: 'GPA.77' }), recordOk,
    [/:consume$/, () => { throw new TypeError('network down'); }]]);
  const r = await verifyPurchase(config(), { authorization: 'Bearer user-jwt', body: googleBody() }, fetch);
  assert.equal(r.status, 200);
});
