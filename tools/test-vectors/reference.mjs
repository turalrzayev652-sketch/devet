// Reference implementation of the rules in spec/test-vectors/README.md.
// Not used by the apps — it exists so the shared vectors are proven consistent before Android/iOS implement them.

export const AZ_MOBILE_PREFIXES = ['10', '50', '51', '55', '60', '70', '77', '99'];

// ---------------------------------------------------------------------------
// phones
// ---------------------------------------------------------------------------

export function normalizePhone(input) {
  let s = String(input ?? '').normalize('NFKC').trim().replace(/[\s \-.()]/g, '');
  if (!s) return { ok: false, error: 'empty' };
  if (!/^\+?\d+$/.test(s)) return { ok: false, error: 'invalid' };
  if (s.startsWith('00')) s = `+${s.slice(2)}`;

  let e164;
  if (s.startsWith('+')) {
    if (!/^\+[1-9]\d{7,14}$/.test(s)) return { ok: false, error: 'invalid' };
    e164 = s;
  } else if (/^994\d{9}$/.test(s)) {
    e164 = `+${s}`;
  } else if (/^0\d{9}$/.test(s)) {
    e164 = `+994${s.slice(1)}`;
  } else if (/^[1-9]\d{8}$/.test(s)) {
    e164 = `+994${s}`;
  } else {
    return { ok: false, error: 'invalid' };
  }

  if (e164.startsWith('+994')) {
    const national = e164.slice(4);
    if (!/^\d{9}$/.test(national)) return { ok: false, error: 'invalid' };
    if (!AZ_MOBILE_PREFIXES.includes(national.slice(0, 2))) return { ok: false, error: 'not_mobile' };
  }
  return { ok: true, e164 };
}

// ---------------------------------------------------------------------------
// excel
// ---------------------------------------------------------------------------

export function fold(text) {
  return String(text ?? '')
    .normalize('NFKC')
    .toLowerCase()
    .replace(/ı/g, 'i')
    .replace(/ə/g, 'e')
    .normalize('NFD')
    .replace(/\p{M}/gu, '')
    .replace(/\s+/g, ' ')
    .trim();
}
export const normalizeHeader = (t) => fold(t).replace(/[^\p{L}\p{N}]+/gu, ' ').trim();
export const normalizeValue = (t) => fold(t);

export function mapHeaders(headers, columns) {
  const lookup = new Map();
  for (const [field, spec] of Object.entries(columns)) {
    for (const alias of spec.aliases) lookup.set(normalizeHeader(alias), field);
  }
  const result = {};
  headers.forEach((h, i) => {
    const field = lookup.get(normalizeHeader(h));
    if (field && !(field in result)) result[field] = i;
  });
  if (!('name' in result)) return { ok: false, error: 'name_column_missing' };
  return { ok: true, mapping: result };
}

const isEmpty = (v) => v === null || v === undefined || (typeof v === 'string' && v.trim() === '');
const asText = (v) => (typeof v === 'number' ? String(v) : String(v ?? '')).trim();

function lookupValue(table, raw) {
  const v = normalizeValue(raw);
  for (const [key, list] of Object.entries(table)) {
    if (list.some((alias) => normalizeValue(alias) === v)) return key;
  }
  return undefined;
}

function parseCount(raw) {
  if (isEmpty(raw)) return 1;
  const n = typeof raw === 'number' ? raw : Number(String(raw).trim());
  return Number.isInteger(n) && n >= 1 && n <= 50 ? n : null;
}

// row: object keyed by field (already mapped from headers). Returns { skipped } | { ok, guest } | { ok: false, errors }.
export function parseRow(row, spec) {
  if (Object.values(row).every(isEmpty)) return { skipped: true };
  const errors = [];
  const guest = {};
  const order = Object.keys(spec.columns);

  for (const field of order) {
    const raw = row[field];
    switch (field) {
      case 'name': {
        const name = asText(raw);
        if (!name) errors.push('name_missing');
        guest.name = name;
        break;
      }
      case 'phone': {
        if (isEmpty(raw)) { guest.phone_e164 = null; break; }
        const input = typeof raw === 'number' ? String(Math.trunc(raw)) : raw;
        const r = normalizePhone(input);
        if (r.ok) guest.phone_e164 = r.e164;
        else errors.push(r.error === 'not_mobile' ? 'phone_not_mobile' : 'phone_invalid');
        break;
      }
      case 'salutation': {
        const v = isEmpty(raw) ? 'none' : lookupValue(spec.values.salutation, raw);
        if (v === undefined) errors.push('salutation_invalid');
        guest.salutation = v;
        break;
      }
      case 'invited_count': {
        const n = parseCount(raw);
        if (n === null) errors.push('invited_count_invalid');
        guest.invited_count = n;
        break;
      }
      case 'with_family': {
        const v = isEmpty(raw) ? 'false' : lookupValue(spec.values.boolean, raw);
        if (v === undefined) errors.push('with_family_invalid');
        guest.with_family = v === 'true';
        break;
      }
      case 'side': {
        const v = isEmpty(raw) ? 'none' : lookupValue(spec.values.side, raw);
        if (v === undefined) errors.push('side_invalid');
        guest.side = v;
        break;
      }
      case 'table_no': {
        const t = isEmpty(raw) ? null : asText(raw);
        if (t !== null && t.length > 12) errors.push('table_no_invalid');
        guest.table_no = t;
        break;
      }
      default:
        break;
    }
  }
  return errors.length ? { ok: false, errors } : { ok: true, guest };
}

export function fileWarnings(rows, spec) {
  if (!rows.length) return { ok: false, error: 'no_rows', warnings: [] };
  const seen = new Map();
  const warnings = [];
  rows.forEach((row, i) => {
    const r = parseRow(row, spec);
    const phone = r.ok ? r.guest.phone_e164 : null;
    if (!phone) return;
    if (seen.has(phone)) warnings.push({ row: i + 1, warning: 'duplicate_phone', first_row: seen.get(phone) });
    else seen.set(phone, i + 1);
  });
  return { ok: true, warnings };
}

// ---------------------------------------------------------------------------
// maps
// ---------------------------------------------------------------------------

const NUM = String.raw`(-?\d{1,3}(?:\.\d+)?)`;
const inRange = (lat, lng) => Math.abs(lat) <= 90 && Math.abs(lng) <= 180;

function isMapHost(url) {
  const host = url.hostname.toLowerCase();
  if (host === 'waze.com' || host === 'www.waze.com' || host === 'maps.apple.com') return true;
  const google = /^(?:www\.|maps\.)?google\.(?:[a-z]{2,3}|com?\.[a-z]{2})$/.test(host);
  return google && (host.startsWith('maps.') || url.pathname.startsWith('/maps'));
}

export function parseMapsLink(input) {
  const text = String(input ?? '').trim();
  if (!text) return { ok: false, error: 'empty' };
  let url;
  try { url = new URL(text); } catch { return { ok: false, error: 'invalid_url' }; }
  if (url.protocol !== 'http:' && url.protocol !== 'https:') return { ok: false, error: 'invalid_url' };
  if (!isMapHost(url)) return { ok: true, coords: null };

  const full = decodeURIComponent(url.href);
  const candidates = [];
  const pin = new RegExp(`!3d${NUM}!4d${NUM}`).exec(full);
  if (pin) candidates.push(pin);
  const at = new RegExp(`@${NUM},${NUM}(?:,|$)`).exec(decodeURIComponent(url.pathname));
  if (at) candidates.push(at);
  for (const name of ['q', 'query', 'll']) {
    const v = url.searchParams.get(name);
    const m = v && new RegExp(String.raw`^${NUM},\s*${NUM}$`).exec(v.trim());
    if (m) candidates.push(m);
  }
  for (const m of candidates) {
    const lat = Number(m[1]);
    const lng = Number(m[2]);
    if (inRange(lat, lng)) return { ok: true, coords: { lat, lng } };
  }
  return { ok: true, coords: null };
}
