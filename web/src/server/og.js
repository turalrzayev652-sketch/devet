// Personalised Open Graph tags for the WhatsApp link preview (T24, PRODUCT.md §10).
// Texts come from invite.json via the same helpers the guest page uses.
import { t, resolveLang } from '../../public/core/i18n.js';
import { formatDate, safeUrl } from '../../public/core/format.js';

const LOCALES = { az: 'az_AZ', ru: 'ru_RU', en: 'en_US', tr: 'tr_TR' };
const EVENT_TYPES = ['wedding', 'engagement', 'henna', 'birthday', 'jubilee'];

const escapeAttr = (s) =>
  String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);

export function ogData(preview, { code, baseUrl }) {
  const lang = resolveLang(preview.lang);
  const type = EVENT_TYPES.includes(preview.event_type) ? preview.event_type : 'wedding';
  const title = t(`og.title.${type}`, lang, { display_name: preview.display_name, title_names: preview.title_names });
  const date = preview.starts_at ? formatDate(preview.starts_at, lang) : '';
  const description = preview.venue_name
    ? t('og.description', lang, { date, venue_name: preview.venue_name })
    : date;
  // Named preview image if the app uploaded one, otherwise the template thumbnail (public, no secret).
  const named = safeUrl(preview.preview_url);
  const image = named ?? `${baseUrl}/templates/${encodeURIComponent(preview.template_id)}/thumb.jpg`;
  return {
    lang,
    title,
    description,
    url: `${baseUrl}/i/${code}`,
    image,
    imageSize: named ? { width: 1200, height: 630 } : { width: 600, height: 800 },
    locale: LOCALES[lang],
  };
}

export function ogTags(og) {
  const meta = (property, content) => `<meta property="${property}" content="${escapeAttr(content)}">`;
  return [
    `<title>${escapeAttr(og.title)}</title>`,
    `<meta name="robots" content="noindex, nofollow">`,
    `<meta name="description" content="${escapeAttr(og.description)}">`,
    meta('og:type', 'website'),
    meta('og:title', og.title),
    meta('og:description', og.description),
    meta('og:url', og.url),
    meta('og:image', og.image),
    meta('og:image:width', og.imageSize.width),
    meta('og:image:height', og.imageSize.height),
    meta('og:locale', og.locale),
    `<meta name="twitter:card" content="summary_large_image">`,
  ].join('\n');
}
