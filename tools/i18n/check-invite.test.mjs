// node --test tools/i18n/check-invite.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const script = join(here, 'check-invite.mjs');
const repo = join(here, '../..');
const real = JSON.parse(readFileSync(join(repo, 'spec/i18n/invite.json'), 'utf8'));
const schema = join(repo, 'spec/i18n/invite.schema.json');
const migration = join(repo, 'backend/supabase/migrations/003_guest_rpc.sql');

function run(mutate) {
  const dir = mkdtempSync(join(tmpdir(), 'invite-check-'));
  try {
    const data = structuredClone(real);
    mutate(data);
    const file = join(dir, 'invite.json');
    writeFileSync(file, JSON.stringify(data));
    execFileSync(process.execPath, [script, file, schema, migration], { stdio: 'pipe' });
    return { ok: true, out: '' };
  } catch (e) {
    return { ok: false, out: e.stderr.toString() };
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

test('real invite.json passes', () => assert.ok(run(() => {}).ok));

test('missing language is reported', () => {
  const r = run((d) => { delete d['rsvp.yes'].tr; });
  assert.ok(!r.ok);
  assert.match(r.out, /rsvp\.yes: missing "tr"/);
});

test('empty text is reported', () => {
  const r = run((d) => { d['rsvp.no'].ru = '  '; });
  assert.match(r.out, /rsvp\.no\.ru: empty/);
});

test('extra language is reported', () => {
  const r = run((d) => { d['rsvp.no'].de = 'Nein'; });
  assert.match(r.out, /unexpected "de"/);
});

test('placeholder mismatch is reported', () => {
  const r = run((d) => { d['table.number'].en = 'Table {table}'; });
  assert.match(r.out, /table\.number\.en: placeholders/);
});

test('missing required key is reported', () => {
  const r = run((d) => { delete d['countdown.days.many']; });
  assert.match(r.out, /missing required key "countdown\.days\.many"/);
});

test('salutation drift from the database is reported', () => {
  const r = run((d) => { d['salutation.xanim'].az = 'Xanım {name}'; });
  assert.match(r.out, /salutation\.xanim\.az: .* differs from display_name_forms/);
});

test('bad key name is reported', () => {
  const r = run((d) => { d['Bad Key'] = { az: 'a', ru: 'b', en: 'c', tr: 'd' }; });
  assert.match(r.out, /bad key "Bad Key"/);
});

test('plural keys cover every category Intl.PluralRules returns', () => {
  for (const lang of ['az', 'ru', 'en', 'tr']) {
    const rules = new Intl.PluralRules(lang);
    for (const n of [0, 1, 2, 3, 5, 11, 21, 22, 25, 101, 1.5]) {
      const key = `countdown.days.${rules.select(n)}`;
      assert.ok(real[key]?.[lang], `${lang} n=${n} -> ${key}`);
    }
  }
});
