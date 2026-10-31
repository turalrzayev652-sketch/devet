// node --test tools/i18n/generate.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, readFileSync, writeFileSync, rmSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildEntries, renderAndroid, renderXcstrings } from './generate.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const script = join(here, 'generate.mjs');
const realSource = join(here, '../../spec/i18n/app.json');

function withTmp(fn) {
  const dir = mkdtempSync(join(tmpdir(), 'i18n-gen-'));
  try { return fn(dir); } finally { rmSync(dir, { recursive: true, force: true }); }
}
function run(dir, source) {
  try {
    const out = execFileSync(process.execPath, [script, '--source', source, '--android', join(dir, 'res'), '--ios', join(dir, 'ios/Localizable.xcstrings')], { stdio: 'pipe' });
    return { ok: true, out: out.toString() };
  } catch (e) {
    return { ok: false, out: e.stderr.toString() };
  }
}
const entry = (az, ru = az, en = az, tr = az) => ({ az, ru, en, tr });

test('real app.json generates Android values* and iOS Localizable.xcstrings', () => withTmp((dir) => {
  const r = run(dir, realSource);
  assert.ok(r.ok, r.out);
  for (const d of ['values', 'values-ru', 'values-en', 'values-tr']) assert.ok(existsSync(join(dir, 'res', d, 'strings.xml')), d);
  const az = readFileSync(join(dir, 'res/values/strings.xml'), 'utf8');
  const ru = readFileSync(join(dir, 'res/values-ru/strings.xml'), 'utf8');
  const en = readFileSync(join(dir, 'res/values-en/strings.xml'), 'utf8');
  assert.match(az, /<string name="auth_login_title">Daxil ol<\/string>/);
  assert.match(ru, /<string name="auth_login_title">Вход<\/string>/);
  assert.match(az, /<string name="wa_message_wedding">Hörmətli %1\$s! %2\$s toyuna dəvətlisiniz\. Dəvətnamə: %3\$s<\/string>/);
  assert.match(en, /<item quantity="one">%1\$d guest<\/item>/);
  assert.match(ru, /<item quantity="few">%1\$d гостя<\/item>/);
  assert.match(ru, /<item quantity="many">%1\$d гостей<\/item>/);

  const cat = JSON.parse(readFileSync(join(dir, 'ios/Localizable.xcstrings'), 'utf8'));
  assert.equal(cat.sourceLanguage, 'az');
  assert.equal(cat.version, '1.0');
  assert.equal(cat.strings['auth.login.title'].localizations.tr.stringUnit.value, 'Giriş yap');
  assert.equal(cat.strings['wa_message.wedding'].localizations.en.stringUnit.value,
    'Dear %1$@, you are invited to the wedding of %2$@. Invitation: %3$@');
  assert.equal(cat.strings['guests.count'].localizations.ru.variations.plural.many.stringUnit.value, '%1$lld гостей');
  assert.ok(!('guests.count.one' in cat.strings), 'plural forms are folded into one key');
}));

test('Android escaping: apostrophe, quotes, ampersand, angle brackets, leading @/?', () => {
  const { entries, errors } = buildEntries({
    'a.apos': entry("I'll be there"),
    'a.amp': entry('Tom & "Jerry" <3'),
    'a.at': entry('@home'),
    'a.q': entry('?why'),
    'a.pct': entry('100% {n}'),
    'a.pct_plain': entry('100%'),
  });
  assert.deepEqual(errors, []);
  const xml = renderAndroid(entries, 'az');
  assert.match(xml, /<string name="a_apos">I\\'ll be there<\/string>/);
  assert.match(xml, /<string name="a_amp">Tom &amp; \\"Jerry\\" &lt;3<\/string>/);
  assert.match(xml, /<string name="a_at">\\@home<\/string>/);
  assert.match(xml, /<string name="a_q">\\\?why<\/string>/);
  assert.match(xml, /<string name="a_pct">100%% %1\$s<\/string>/, 'literal % doubled when formatted');
  assert.match(xml, /<string name="a_pct_plain">100%<\/string>/, 'left alone without args');
});

test('placeholder positions follow the source language even if another language reorders them', () => {
  const { entries } = buildEntries({ 'x.y': { az: '{a} və {b}', ru: '{b} и {a}', en: '{a} and {b}', tr: '{b} ve {a}' } });
  assert.match(renderAndroid(entries, 'ru'), />%2\$s и %1\$s</);
  assert.equal(JSON.parse(renderXcstrings(entries)).strings['x.y'].localizations.tr.stringUnit.value, '%2$@ ve %1$@');
});

for (const [name, source, message] of [
  ['missing translation', { 'a.b': { az: 'x', ru: 'x', en: 'x' } }, /a\.b: missing translation "tr"/],
  ['empty translation', { 'a.b': entry('x', ' ') }, /a\.b: missing translation "ru"/],
  ['extra language', { 'a.b': { ...entry('x'), de: 'x' } }, /unexpected language "de"/],
  ['placeholder mismatch', { 'a.b': entry('{n}', '{m}') }, /a\.b\.ru: placeholders differ/],
  ['incomplete plural', { 'g.count.one': entry('{count}'), 'g.count.other': entry('{count}') }, /g\.count: plural form "few" missing/],
  ['android name clash', { 'a.b_c': entry('x'), 'a_b.c': entry('y') }, /clashes/],
  ['bad key', { 'Bad.Key': entry('x') }, /bad key name/],
]) {
  test(`fails and writes nothing on ${name}`, () => withTmp((dir) => {
    const src = join(dir, 'app.json');
    writeFileSync(src, JSON.stringify(source));
    const r = run(dir, src);
    assert.ok(!r.ok, 'should fail');
    assert.match(r.out, message);
    assert.match(r.out, /nothing written/);
    assert.ok(!existsSync(join(dir, 'res')) && !existsSync(join(dir, 'ios')), 'no partial output');
  }));
}

test('wa_message exists for every event type (PRODUCT.md §9)', () => {
  const json = JSON.parse(readFileSync(realSource, 'utf8'));
  for (const type of ['wedding', 'engagement', 'henna', 'birthday', 'jubilee']) {
    const msg = json[`wa_message.${type}`];
    assert.ok(msg, type);
    for (const lang of ['az', 'ru', 'en', 'tr']) assert.match(msg[lang], /\{display_name\}.*\{link\}/s, `${type}.${lang}`);
  }
});

test('template label_key values from templates.md exist in app.json', () => {
  const json = JSON.parse(readFileSync(realSource, 'utf8'));
  const md = readFileSync(join(here, '../../spec/templates.md'), 'utf8');
  const keys = [...md.matchAll(/"label_key": "([^"]+)"/g)].map((m) => m[1]);
  assert.ok(keys.length > 0);
  for (const k of keys) assert.ok(json[k], k);
});
