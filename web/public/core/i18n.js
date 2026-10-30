import STRINGS from './strings.js';

export const LANGS = ['az', 'ru', 'en', 'tr'];
export const DEFAULT_LANG = 'az';

export function resolveLang(...candidates) {
  return candidates.find((l) => LANGS.includes(l)) ?? DEFAULT_LANG;
}

// Text for a key in a language, with {placeholders} filled from vars (missing ones become '').
export function t(key, lang, vars = {}) {
  const entry = STRINGS[key];
  if (!entry) return '';
  const text = entry[lang] ?? entry[DEFAULT_LANG] ?? '';
  return text.replace(/\{([a-z_]+)\}/g, (_, name) => (vars[name] ?? '').toString());
}

export function has(key) {
  return Object.prototype.hasOwnProperty.call(STRINGS, key);
}

export function plural(base, n, lang) {
  const key = `${base}.${new Intl.PluralRules(lang).select(n)}`;
  return has(key) ? t(key, lang) : t(`${base}.other`, lang);
}

// Same rules as display_name_forms on the server (PRODUCT.md §8).
export function displayName(guest, lang) {
  const salutation = has(`salutation.${guest.salutation}`) ? guest.salutation : 'none';
  const display = t(`salutation.${salutation}`, lang, { name: String(guest.name ?? '').trim() });
  return guest.with_family ? t('salutation.family', lang, { display }) : display;
}

export function greeting(guest, lang) {
  const kind = guest.with_family ? 'family' : (has(`greeting.${guest.salutation}`) ? guest.salutation : 'none');
  return t(`greeting.${kind}`, lang, { display_name: displayName(guest, lang) });
}
