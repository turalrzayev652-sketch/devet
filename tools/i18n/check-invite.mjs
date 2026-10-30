#!/usr/bin/env node
// Validates /spec/i18n/invite.json (T21).
// Usage: node tools/i18n/check-invite.mjs [invite.json] [schema.json] [003_guest_rpc.sql]
// Exit code 1 with a list of problems if anything is wrong.
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { resolve, dirname } from 'node:path';

const repo = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const [invitePath = `${repo}/spec/i18n/invite.json`,
       schemaPath = `${repo}/spec/i18n/invite.schema.json`,
       migrationPath = `${repo}/backend/supabase/migrations/003_guest_rpc.sql`] = process.argv.slice(2);

const LANGS = ['az', 'ru', 'en', 'tr'];
const EVENT_TYPES = ['wedding', 'engagement', 'henna', 'birthday', 'jubilee'];
const SALUTATIONS = ['muellim', 'xanim', 'bey', 'none'];
const PLURAL_CATEGORIES = ['one', 'few', 'many', 'other'];

// Keys the guest page cannot work without (TASKS.md T21, PRODUCT.md §8, §10, §11).
const REQUIRED = [
  ...SALUTATIONS.map((s) => `salutation.${s}`), 'salutation.family',
  ...SALUTATIONS.map((s) => `greeting.${s}`), 'greeting.family',
  ...EVENT_TYPES.flatMap((e) => [`event_type.${e}`, `invite.${e}`, `og.title.${e}`]), 'og.description',
  ...['days', 'hours', 'minutes'].flatMap((u) => PLURAL_CATEGORIES.map((c) => `countdown.${u}.${c}`)), 'countdown.title',
  'rsvp.yes', 'rsvp.no', 'rsvp.count_label', 'rsvp.submit', 'rsvp.thanks_yes', 'rsvp.thanks_no',
  'table.title', 'table.number', 'table.mates', 'map.title', 'map.directions', 'map.google', 'map.waze',
  'music.play', 'music.pause', 'gallery.title', 'watermark',
  'date.long', ...Array.from({ length: 12 }, (_, i) => `date.month.${i + 1}`), ...Array.from({ length: 7 }, (_, i) => `date.weekday.${i}`),
  ...['not_found', 'event_past', 'network', 'rate_limited'].flatMap((e) => [`error.${e}.title`, `error.${e}.body`]),
];

const errors = [];
const fail = (msg) => errors.push(msg);

let strings, schema;
try { strings = JSON.parse(readFileSync(invitePath, 'utf8')); } catch (e) { fail(`invite.json: ${e.message}`); }
try { schema = JSON.parse(readFileSync(schemaPath, 'utf8')); } catch (e) { fail(`schema: ${e.message}`); }

// Minimal JSON Schema check for the keywords invite.schema.json uses.
function validate(value, s, path) {
  if (s.type === 'object') {
    if (typeof value !== 'object' || value === null || Array.isArray(value)) return fail(`${path}: must be an object`);
    for (const r of s.required ?? []) if (!(r in value)) fail(`${path}: missing "${r}"`);
    for (const [k, v] of Object.entries(value)) {
      if (s.propertyNames?.pattern && !new RegExp(s.propertyNames.pattern).test(k)) fail(`${path}: bad key "${k}"`);
      const sub = s.properties?.[k] ?? s.additionalProperties;
      if (sub === false) fail(`${path}: unexpected "${k}"`);
      else if (sub && typeof sub === 'object') validate(v, sub, `${path}.${k}`);
    }
  } else if (s.type === 'string') {
    if (typeof value !== 'string') return fail(`${path}: must be a string`);
    if (s.minLength && value.trim().length < s.minLength) fail(`${path}: empty`);
  }
}

if (strings && schema) {
  validate(strings, schema, 'invite');

  for (const key of REQUIRED) if (!(key in strings)) fail(`missing required key "${key}"`);

  // Same placeholders in every language.
  const placeholders = (s) => [...String(s).matchAll(/\{([a-z_]+)\}/g)].map((m) => m[1]).sort().join(',');
  for (const [key, entry] of Object.entries(strings)) {
    if (typeof entry !== 'object' || entry === null) continue;
    const base = placeholders(entry.az);
    for (const l of LANGS) {
      if (typeof entry[l] === 'string' && placeholders(entry[l]) !== base)
        fail(`${key}.${l}: placeholders {${placeholders(entry[l])}} differ from az {${base}}`);
    }
  }

  // Salutation forms must match the server copy used by get_preview (display_name_forms in 003_guest_rpc.sql).
  let sql = null;
  try { sql = readFileSync(migrationPath, 'utf8'); } catch (e) { fail(`migration: ${e.message}`); }
  if (sql) {
    const rows = [...sql.matchAll(/\('(az|ru|en|tr)',\s*(?:'(\w+)'|null),\s*'([^']*)'\)/g)];
    if (rows.length !== LANGS.length * (SALUTATIONS.length + 1)) fail(`migration: expected 20 display_name_forms rows, found ${rows.length}`);
    for (const [, lang, salutation, pattern] of rows) {
      const key = salutation ? `salutation.${salutation}` : 'salutation.family';
      const mine = strings[key]?.[lang];
      if (mine !== pattern) fail(`${key}.${lang}: "${mine}" differs from display_name_forms "${pattern}"`);
    }
  }
}

if (errors.length) {
  console.error(`invite.json: ${errors.length} problem(s)`);
  for (const e of errors) console.error(`  - ${e}`);
  process.exit(1);
}
console.log(`invite.json OK (${Object.keys(strings).length} keys × ${LANGS.length} languages)`);
