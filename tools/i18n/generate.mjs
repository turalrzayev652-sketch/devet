#!/usr/bin/env node
// Generates platform string files from /spec/i18n/app.json (T32).
//
//   node tools/i18n/generate.mjs [--source spec/i18n/app.json]
//                                [--android android/app/src/main/res]
//                                [--ios ios/Devet/Resources/Localizable.xcstrings]
//
// Android: values/strings.xml (az, the default), values-ru, values-en, values-tr.
// iOS:     one Localizable.xcstrings (source language az).
// Keys:    "a.b.c" -> Android name "a_b_c", iOS key "a.b.c".
// Plurals: keys ending in .one/.few/.many/.other form one plural string (Android <plurals>, iOS plural variations).
// Placeholders: {name} -> positional %1$s (Android) / %1$@ (iOS); {count} inside plurals -> %1$d / %1$lld.
// Generated files must not be edited by hand. Any problem (missing translation, placeholder mismatch, name clash)
// stops the script with exit code 1 and nothing is written.
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, resolve, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

export const LANGS = ['az', 'ru', 'en', 'tr'];
export const SOURCE_LANG = 'az';
const PLURAL_CATEGORIES = ['one', 'few', 'many', 'other'];
const KEY_RE = /^[a-z][a-z0-9_]*(\.[a-z0-9_]+)*$/;
const PLACEHOLDER_RE = /\{([a-z_]+)\}/g;

const repo = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const DEFAULTS = {
  source: join(repo, 'spec/i18n/app.json'),
  android: join(repo, 'android/app/src/main/res'),
  ios: join(repo, 'ios/Devet/Resources/Localizable.xcstrings'),
};

const placeholderNames = (s) => [...new Set([...String(s).matchAll(PLACEHOLDER_RE)].map((m) => m[1]))];

// ---------------------------------------------------------------------------
// Parse + validate into entries: { key, plural: false, values } | { key, plural: true, forms: { cat: values } }
// ---------------------------------------------------------------------------

export function buildEntries(json) {
  const errors = [];
  if (typeof json !== 'object' || json === null || Array.isArray(json)) return { errors: ['source must be an object'], entries: [] };

  for (const [key, entry] of Object.entries(json)) {
    if (!KEY_RE.test(key)) errors.push(`${key}: bad key name`);
    if (typeof entry !== 'object' || entry === null) { errors.push(`${key}: must be an object`); continue; }
    for (const lang of LANGS) {
      if (typeof entry[lang] !== 'string' || !entry[lang].trim()) errors.push(`${key}: missing translation "${lang}"`);
    }
    for (const extra of Object.keys(entry)) if (!LANGS.includes(extra)) errors.push(`${key}: unexpected language "${extra}"`);
    const base = placeholderNames(entry[SOURCE_LANG]).sort().join(',');
    for (const lang of LANGS) {
      if (typeof entry[lang] === 'string' && placeholderNames(entry[lang]).sort().join(',') !== base)
        errors.push(`${key}.${lang}: placeholders differ from ${SOURCE_LANG}`);
    }
  }

  const plurals = new Map();
  const singles = [];
  for (const key of Object.keys(json)) {
    const m = /^(.*)\.(one|few|many|other)$/.exec(key);
    if (m) {
      if (!plurals.has(m[1])) plurals.set(m[1], {});
      plurals.get(m[1])[m[2]] = json[key];
    } else {
      singles.push(key);
    }
  }
  for (const [base, forms] of plurals) {
    for (const cat of PLURAL_CATEGORIES) if (!forms[cat]) errors.push(`${base}: plural form "${cat}" missing`);
    if (singles.includes(base)) errors.push(`${base}: used both as a plain key and a plural`);
  }

  const entries = [
    ...singles.map((key) => ({ key, plural: false, values: json[key] })),
    ...[...plurals].map(([key, forms]) => ({ key, plural: true, forms })),
  ].sort((a, b) => a.key.localeCompare(b.key));

  const androidNames = new Map();
  for (const e of entries) {
    const name = androidName(e.key);
    if (androidNames.has(name)) errors.push(`${e.key}: Android name "${name}" clashes with ${androidNames.get(name)}`);
    androidNames.set(name, e.key);
  }
  return { errors, entries };
}

export const androidName = (key) => key.replace(/\./g, '_');

// Positional index per placeholder name, in order of first appearance in the source language.
function placeholderOrder(text) {
  return new Map(placeholderNames(text).map((name, i) => [name, i + 1]));
}

function toFormat(text, order, { plural, platform }) {
  const hasArgs = order.size > 0;
  let out = hasArgs ? text.replace(/%/g, '%%') : text;
  out = out.replace(PLACEHOLDER_RE, (_, name) => {
    const i = order.get(name);
    const numeric = plural && name === 'count';
    if (platform === 'android') return numeric ? `%${i}$d` : `%${i}$s`;
    return numeric ? `%${i}$lld` : `%${i}$@`;
  });
  return out;
}

// ---------------------------------------------------------------------------
// Android
// ---------------------------------------------------------------------------

function androidEscape(s) {
  let out = s
    .replace(/\\/g, '\\\\')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/'/g, "\\'")
    .replace(/"/g, '\\"')
    .replace(/\n/g, '\\n');
  if (/^[@?]/.test(out)) out = `\\${out}`;
  return out;
}

export function renderAndroid(entries, lang) {
  const lines = [
    '<?xml version="1.0" encoding="utf-8"?>',
    '<!-- Generated from spec/i18n/app.json by tools/i18n/generate.mjs. Do not edit. -->',
    '<resources>',
  ];
  for (const e of entries) {
    const name = androidName(e.key);
    if (e.plural) {
      const order = placeholderOrder(e.forms.other[SOURCE_LANG]);
      lines.push(`    <plurals name="${name}">`);
      for (const cat of PLURAL_CATEGORIES) {
        lines.push(`        <item quantity="${cat}">${androidEscape(toFormat(e.forms[cat][lang], order, { plural: true, platform: 'android' }))}</item>`);
      }
      lines.push('    </plurals>');
    } else {
      const order = placeholderOrder(e.values[SOURCE_LANG]);
      lines.push(`    <string name="${name}">${androidEscape(toFormat(e.values[lang], order, { plural: false, platform: 'android' }))}</string>`);
    }
  }
  lines.push('</resources>', '');
  return lines.join('\n');
}

export const androidDir = (lang) => (lang === SOURCE_LANG ? 'values' : `values-${lang}`);

// ---------------------------------------------------------------------------
// iOS String Catalog
// ---------------------------------------------------------------------------

const unit = (value) => ({ stringUnit: { state: 'translated', value } });

export function renderXcstrings(entries) {
  const strings = {};
  for (const e of entries) {
    const localizations = {};
    if (e.plural) {
      const order = placeholderOrder(e.forms.other[SOURCE_LANG]);
      for (const lang of LANGS) {
        const plural = {};
        for (const cat of PLURAL_CATEGORIES) plural[cat] = unit(toFormat(e.forms[cat][lang], order, { plural: true, platform: 'ios' }));
        localizations[lang] = { variations: { plural } };
      }
    } else {
      const order = placeholderOrder(e.values[SOURCE_LANG]);
      for (const lang of LANGS) localizations[lang] = unit(toFormat(e.values[lang], order, { plural: false, platform: 'ios' }));
    }
    strings[e.key] = { extractionState: 'manual', localizations };
  }
  return `${JSON.stringify({ sourceLanguage: SOURCE_LANG, strings, version: '1.0' }, null, 2)}\n`;
}

// ---------------------------------------------------------------------------

export function generate({ source = DEFAULTS.source, android = DEFAULTS.android, ios = DEFAULTS.ios } = {}) {
  let json;
  try { json = JSON.parse(readFileSync(source, 'utf8')); } catch (e) { return { errors: [`${source}: ${e.message}`] }; }
  const { errors, entries } = buildEntries(json);
  if (errors.length) return { errors };

  const written = [];
  if (android) {
    for (const lang of LANGS) {
      const file = join(android, androidDir(lang), 'strings.xml');
      mkdirSync(dirname(file), { recursive: true });
      writeFileSync(file, renderAndroid(entries, lang));
      written.push(file);
    }
  }
  if (ios) {
    mkdirSync(dirname(ios), { recursive: true });
    writeFileSync(ios, renderXcstrings(entries));
    written.push(ios);
  }
  return { errors: [], written, count: entries.length };
}

function parseArgs(argv) {
  const opts = {};
  for (let i = 0; i < argv.length; i += 2) {
    const flag = argv[i];
    const value = argv[i + 1];
    if (!['--source', '--android', '--ios'].includes(flag) || value === undefined) {
      throw new Error(`usage: generate.mjs [--source file] [--android resDir] [--ios file.xcstrings]`);
    }
    opts[flag.slice(2)] = resolve(value);
  }
  return opts;
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  let result;
  try { result = generate(parseArgs(process.argv.slice(2))); } catch (e) { result = { errors: [e.message] }; }
  if (result.errors.length) {
    console.error(`app.json: ${result.errors.length} problem(s), nothing written`);
    for (const e of result.errors) console.error(`  - ${e}`);
    process.exit(1);
  }
  console.log(`${result.count} strings -> ${result.written.length} files`);
  for (const f of result.written) console.log(`  ${f}`);
}
