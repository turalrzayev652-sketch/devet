import { pickLang } from './i18n.js';
import { errorResponse } from './error-page.js';
import { normalizeCode, callRpc } from './supabase.js';

const DEFAULT_BRAND = 'Devet';

// JSON inside <script>: escape "<" so the payload cannot close the tag.
const scriptJson = (value) => JSON.stringify(value).replace(/</g, '\\u003c');

const escapeAttr = (s) => String(s).replace(/[&"<>]/g, (c) => ({ '&': '&amp;', '"': '&quot;', '<': '&lt;', '>': '&gt;' })[c]);

// Adds <base> (templates use relative paths) and the #invite-config script read by invite-core.js.
// T24 adds the personalised og: tags and signed media URLs here.
export function injectHead(html, { templateId, config }) {
  const head = `<base href="/templates/${escapeAttr(templateId)}/">\n` +
    `<script id="invite-config" type="application/json">${scriptJson(config)}</script>\n`;
  const match = /<head[^>]*>/i.exec(html);
  if (!match) return head + html;
  const at = match.index + match[0].length;
  return `${html.slice(0, at)}\n${head}${html.slice(at)}`;
}

// GET /i/<code>: resolves the code and serves the template page or an error screen.
export async function handleInvite({ params, request, env }, fetchImpl = fetch) {
  const fallbackLang = pickLang(request.headers.get('accept-language'));
  const code = normalizeCode(params.code);
  if (!code) return errorResponse('not_found', fallbackLang);

  const preview = await callRpc(env, 'get_preview', { code }, fetchImpl);
  if (!preview?.ok) return errorResponse(preview?.error, preview?.lang ?? fallbackLang);

  const templateId = preview.template_id;
  const page = await env.ASSETS.fetch(new URL(`/templates/${templateId}/index.html`, request.url));
  if (!page.ok) return errorResponse('not_found', preview.lang ?? fallbackLang);

  const html = injectHead(await page.text(), {
    templateId,
    config: {
      code,
      supabase_url: env.SUPABASE_URL,
      anon_key: env.SUPABASE_ANON_KEY,
      brand: env.BRAND_NAME || DEFAULT_BRAND,
      base_url: env.PUBLIC_BASE_URL || new URL(request.url).origin,
      media: { photos: [], music: null },
    },
  });

  return new Response(html, {
    status: 200,
    headers: {
      'content-type': 'text/html; charset=utf-8',
      'cache-control': 'private, max-age=300',
      'referrer-policy': 'no-referrer',
    },
  });
}
