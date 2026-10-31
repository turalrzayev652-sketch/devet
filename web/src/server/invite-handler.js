import { pickLang } from './i18n.js';
import { errorResponse } from './error-page.js';
import { normalizeCode, callRpc } from './supabase.js';
import { ogData, ogTags } from './og.js';
import { signedMedia } from './media.js';

const DEFAULT_BRAND = 'Devet';
// Short cache: the guest's name, language or answer can change in the app (TASKS.md T24).
const PAGE_CACHE = 'public, max-age=300';

// JSON inside <script>: escape "<" so the payload cannot close the tag.
const scriptJson = (value) => JSON.stringify(value).replace(/</g, '\\u003c');

const escapeAttr = (s) => String(s).replace(/[&"<>]/g, (c) => ({ '&': '&amp;', '"': '&quot;', '<': '&lt;', '>': '&gt;' })[c]);

// Adds <base> (templates use relative paths), og: tags and the #invite-config script read by invite-core.js.
export function injectHead(html, { templateId, config, meta = '' }) {
  const head = `<base href="/templates/${escapeAttr(templateId)}/">\n` +
    (meta ? `${meta}\n` : '') +
    `<script id="invite-config" type="application/json">${scriptJson(config)}</script>\n`;
  // Templates must not carry their own <title>; the personalised one wins.
  const cleaned = meta ? html.replace(/<title>[\s\S]*?<\/title>\s*/i, '') : html;
  const match = /<head[^>]*>/i.exec(cleaned);
  if (!match) return head + cleaned;
  const at = match.index + match[0].length;
  return `${cleaned.slice(0, at)}\n${head}${cleaned.slice(at)}`;
}

// GET /i/<code>: resolves the code and serves the personalised template page or an error screen.
export async function handleInvite({ params, request, env }, fetchImpl = (...args) => fetch(...args)) {
  const fallbackLang = pickLang(request.headers.get('accept-language'));
  const code = normalizeCode(params.code);
  if (!code) return errorResponse('not_found', fallbackLang);

  const preview = await callRpc(env, 'get_preview', { code }, fetchImpl);
  if (!preview?.ok) return errorResponse(preview?.error, preview?.lang ?? fallbackLang);

  const templateId = preview.template_id;
  const baseUrl = (env.PUBLIC_BASE_URL || new URL(request.url).origin).replace(/\/+$/, '');

  // Same response for crawlers and guests: the page is cacheable, so it must not vary by User-Agent.
  const [page, media] = await Promise.all([
    env.ASSETS.fetch(new URL(`/templates/${templateId}/index.html`, request.url)),
    signedMedia(env, code, fetchImpl),
  ]);
  if (!page.ok) return errorResponse('not_found', preview.lang ?? fallbackLang);

  const html = injectHead(await page.text(), {
    templateId,
    meta: ogTags(ogData(preview, { code, baseUrl })),
    config: {
      code,
      supabase_url: env.SUPABASE_URL,
      anon_key: env.SUPABASE_ANON_KEY,
      brand: env.BRAND_NAME || DEFAULT_BRAND,
      base_url: baseUrl,
      media,
    },
  });

  return new Response(html, {
    status: 200,
    headers: {
      'content-type': 'text/html; charset=utf-8',
      'cache-control': PAGE_CACHE,
      'referrer-policy': 'no-referrer',
      'x-robots-tag': 'noindex, nofollow',
    },
  });
}
