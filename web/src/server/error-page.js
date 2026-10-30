import { t } from './i18n.js';

const STATUS = { not_found: 404, event_past: 410, network: 503 };

const escapeHtml = (s) =>
  String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);

export function errorPageHtml(error, lang) {
  const kind = STATUS[error] ? error : 'not_found';
  const title = escapeHtml(t(`error.${kind}.title`, lang));
  const body = escapeHtml(t(`error.${kind}.body`, lang));
  const retry = kind === 'network'
    ? `<button type="button" onclick="location.reload()">${escapeHtml(t('error.retry', lang))}</button>`
    : '';
  return `<!doctype html>
<html lang="${lang}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>${title}</title>
<style>
  :root { color-scheme: light dark; --bg: #faf7f2; --fg: #2b2622; --muted: #6b625a; --accent: #8a5a44; }
  @media (prefers-color-scheme: dark) { :root { --bg: #1c1917; --fg: #f5f0ea; --muted: #b5aca3; --accent: #d9a58a; } }
  * { box-sizing: border-box; }
  body { margin: 0; min-height: 100vh; display: grid; place-items: center; padding: 24px 16px;
         background: var(--bg); color: var(--fg); font: 16px/1.5 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; }
  main { max-width: 420px; text-align: center; }
  h1 { font-size: 1.4rem; margin: 0 0 8px; }
  p { margin: 0; color: var(--muted); }
  button { margin-top: 20px; padding: 12px 20px; border: 0; border-radius: 999px;
           background: var(--accent); color: var(--bg); font: inherit; cursor: pointer; }
</style>
</head>
<body>
<main data-error="${kind}">
  <h1>${title}</h1>
  <p>${body}</p>
  ${retry}
</main>
</body>
</html>`;
}

export function errorResponse(error, lang) {
  const kind = STATUS[error] ? error : 'not_found';
  return new Response(errorPageHtml(kind, lang), {
    status: STATUS[kind],
    headers: {
      'content-type': 'text/html; charset=utf-8',
      'cache-control': 'no-store',
      'x-robots-tag': 'noindex',
    },
  });
}
