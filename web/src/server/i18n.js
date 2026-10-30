import strings from '../../../spec/i18n/invite.json' with { type: 'json' };

export const LANGS = ['az', 'ru', 'en', 'tr'];
export const DEFAULT_LANG = 'az';

// Picks the first supported language from an Accept-Language header.
export function pickLang(acceptLanguage) {
  const ranked = String(acceptLanguage || '')
    .split(',')
    .map((part) => {
      const [tag, ...params] = part.trim().toLowerCase().split(';');
      const q = params.find((p) => p.trim().startsWith('q='));
      return { lang: tag.split('-')[0], q: q ? Number(q.split('=')[1]) || 0 : 1 };
    })
    .filter((x) => x.lang && x.q > 0)
    .sort((a, b) => b.q - a.q);
  return ranked.find((x) => LANGS.includes(x.lang))?.lang ?? DEFAULT_LANG;
}

export function t(key, lang) {
  const entry = strings[key];
  if (!entry) throw new Error(`Missing i18n key: ${key}`);
  return entry[lang] ?? entry[DEFAULT_LANG];
}
