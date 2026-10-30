import { pickLang } from './i18n.js';
import { errorResponse } from './error-page.js';
import { normalizeCode, callRpc } from './supabase.js';

// GET /i/<code>. T20: resolves the code and serves the template page or an error screen.
// T24 adds the personalised og: tags and the inline config script.
export async function handleInvite({ params, request, env }, fetchImpl = fetch) {
  const fallbackLang = pickLang(request.headers.get('accept-language'));
  const code = normalizeCode(params.code);
  if (!code) return errorResponse('not_found', fallbackLang);

  const preview = await callRpc(env, 'get_preview', { code }, fetchImpl);
  if (!preview?.ok) return errorResponse(preview?.error, preview?.lang ?? fallbackLang);

  const page = await env.ASSETS.fetch(new URL(`/templates/${preview.template_id}/index.html`, request.url));
  if (!page.ok) return errorResponse('not_found', preview.lang ?? fallbackLang);

  return new Response(page.body, {
    status: 200,
    headers: { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'private, max-age=300' },
  });
}
