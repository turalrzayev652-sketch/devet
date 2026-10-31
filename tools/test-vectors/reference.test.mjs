// node --test tools/test-vectors/reference.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { normalizePhone, mapHeaders, parseRow, fileWarnings, normalizeHeader, normalizeValue, AZ_MOBILE_PREFIXES } from './reference.mjs';

const load = (name) => JSON.parse(readFileSync(new URL(`../../spec/test-vectors/${name}`, import.meta.url), 'utf8'));
const phones = load('phones.json');
const excel = load('excel.json');

test('phones.json prefixes match the reference', () => {
  assert.deepEqual(phones.az_mobile_prefixes, AZ_MOBILE_PREFIXES);
});

for (const c of phones.cases) {
  test(`phone ${JSON.stringify(c.input)}`, () => {
    const r = normalizePhone(c.input);
    if (c.expected === null) assert.deepEqual(r, { ok: false, error: c.error });
    else assert.deepEqual(r, { ok: true, e164: c.expected });
  });
}

test('phone vectors cover every outcome and every mobile prefix', () => {
  const errors = new Set(phones.cases.filter((c) => c.expected === null).map((c) => c.error));
  assert.deepEqual([...errors].sort(), ['empty', 'invalid', 'not_mobile']);
  const prefixes = new Set(phones.cases.filter((c) => c.expected?.startsWith('+994')).map((c) => c.expected.slice(4, 6)));
  for (const p of AZ_MOBILE_PREFIXES) assert.ok(prefixes.has(p), `no valid case for prefix ${p}`);
});

for (const c of excel.header_cases) {
  test(`headers ${JSON.stringify(c.headers)}`, () => {
    const r = mapHeaders(c.headers, excel.columns);
    if (c.expected === null) assert.deepEqual(r, { ok: false, error: c.error });
    else assert.deepEqual(r, { ok: true, mapping: c.expected });
  });
}

for (const c of excel.row_cases) {
  test(`row ${JSON.stringify(c.row)}`, () => {
    const r = parseRow(c.row, excel);
    if (c.skipped) assert.deepEqual(r, { skipped: true });
    else if (c.expected === null) assert.deepEqual(r, { ok: false, errors: c.errors });
    else assert.deepEqual(r, { ok: true, guest: c.expected });
  });
}

for (const c of excel.file_cases) {
  test(`file with ${c.rows.length} rows`, () => {
    const r = fileWarnings(c.rows, excel);
    if (c.error) assert.equal(r.error, c.error);
    assert.deepEqual(r.warnings, c.expected_warnings);
  });
}

test('no alias maps to two different columns', () => {
  const owner = new Map();
  for (const [field, spec] of Object.entries(excel.columns)) {
    for (const a of spec.aliases) {
      const n = normalizeHeader(a);
      assert.ok(!owner.has(n) || owner.get(n) === field, `"${a}" used by ${owner.get(n)} and ${field}`);
      owner.set(n, field);
    }
  }
});

test('no value maps to two different options within one list', () => {
  for (const [list, table] of Object.entries(excel.values)) {
    const owner = new Map();
    for (const [key, aliases] of Object.entries(table)) {
      for (const a of aliases) {
        const n = normalizeValue(a);
        assert.ok(!owner.has(n) || owner.get(n) === key, `${list}: "${a}" means both ${owner.get(n)} and ${key}`);
        owner.set(n, key);
      }
    }
  }
});

test('every error code in the README table has a row vector', () => {
  const used = new Set(excel.row_cases.flatMap((c) => c.errors ?? []));
  for (const code of ['name_missing', 'phone_invalid', 'phone_not_mobile', 'salutation_invalid', 'invited_count_invalid', 'with_family_invalid', 'side_invalid', 'table_no_invalid'])
    assert.ok(used.has(code), code);
});

const maps = load('maps.json');
const { parseMapsLink } = await import('./reference.mjs');
for (const c of maps.cases) {
  test(`maps ${JSON.stringify(c.input).slice(0, 70)}`, () => {
    const r = parseMapsLink(c.input);
    if (c.error) assert.deepEqual(r, { ok: false, error: c.error });
    else assert.deepEqual(r, { ok: true, coords: c.expected });
  });
}
