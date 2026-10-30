// Guest page runtime (spec/templates.md). Loaded by every template:
//   <script type="module" src="/core/invite-core.js"></script>
// Live mode: reads #invite-config, calls get_invite / submit_rsvp.
// Preview mode (?preview=1): data from window.__INVITE_DATA__ or postMessage({ type: 'invite:data', payload }); no RPC.
import { t, resolveLang, displayName, greeting } from './i18n.js';
import { formatDate, formatTime, formatWeekday, isColor } from './format.js';
import { rpc } from './api.js';
import { BLOCKS } from './blocks.js';

const page = () => document.querySelector('main.dv-page') ?? document.body;
const preview = new URLSearchParams(location.search).get('preview') === '1';
let cleanup = [];
let templateMeta = null;

function readConfig() {
  const node = document.getElementById('invite-config');
  if (!node) return null;
  try { return JSON.parse(node.textContent); } catch { return null; }
}

async function loadTemplateMeta() {
  if (templateMeta) return templateMeta;
  try {
    const res = await fetch(new URL('template.json', document.baseURI));
    templateMeta = res.ok ? await res.json() : {};
  } catch {
    templateMeta = {};
  }
  return templateMeta;
}

function showError(kind, lang) {
  const known = ['not_found', 'event_past', 'network', 'rate_limited'];
  const error = known.includes(kind) ? kind : 'not_found';
  const main = page();
  const section = document.createElement('section');
  section.className = 'dv-error';
  section.dataset.error = error;
  const h1 = document.createElement('h1');
  h1.textContent = t(`error.${error}.title`, lang);
  const p = document.createElement('p');
  p.textContent = t(`error.${error}.body`, lang);
  section.append(h1, p);
  if (error === 'network' || error === 'rate_limited') {
    const retry = document.createElement('button');
    retry.type = 'button';
    retry.className = 'dv-error__retry';
    retry.textContent = t('error.retry', lang);
    retry.addEventListener('click', () => location.reload());
    section.append(retry);
  }
  main.replaceChildren(section);
  main.dataset.state = 'error';
  document.documentElement.lang = lang;
}

function applyTheme(template, customization) {
  const root = document.documentElement.style;
  const vars = template.css_vars ?? {};
  const fonts = template.fonts ?? {};
  const faces = [];
  for (const [name, spec] of Object.entries(vars)) {
    if (spec.type === 'color') {
      const value = customization.colors?.[name];
      root.setProperty(name, isColor(value) ? value : spec.default);
    } else if (spec.type === 'font') {
      const chosen = customization.fonts?.[name];
      const id = fonts[chosen] ? chosen : spec.default;
      const font = fonts[id];
      if (!font) continue;
      const family = `dv-${id}`;
      faces.push(`@font-face{font-family:"${family}";src:url("${font.file}") format("woff2");font-display:swap}`);
      root.setProperty(name, `"${family}", ${font.fallback}`);
    }
  }
  let style = document.getElementById('dv-fonts');
  if (!style) {
    style = document.createElement('style');
    style.id = 'dv-fonts';
    document.head.append(style);
  }
  style.textContent = [...new Set(faces)].join('\n');
}

function bindings(data, lang, template) {
  const { event, guest } = data;
  const texts = event.customization?.texts ?? {};
  const values = {
    'guest.display_name': displayName(guest, lang),
    'guest.greeting': greeting(guest, lang),
    'event.title_names': event.title_names,
    'event.host_names': event.host_names,
    'event.hosts_line': event.host_names ? t('event.hosts', lang, { host_names: event.host_names }) : '',
    'event.type_label': t(`event_type.${event.type}`, lang),
    'event.invite_sentence': t(`invite.${event.type}`, lang),
    'event.date': formatDate(event.starts_at, lang),
    'event.weekday': formatWeekday(event.starts_at, lang),
    'event.time': formatTime(event.starts_at, lang),
    'event.venue_name': event.venue_name,
    'event.venue_address': event.venue_address,
  };
  for (const key of Object.keys(template.texts ?? {})) {
    const max = template.texts[key].max_length ?? 1000;
    values[`text.${key}`] = typeof texts[key] === 'string' ? texts[key].slice(0, max) : '';
  }
  return values;
}

async function render(data, ctxExtra) {
  for (const fn of cleanup) fn();
  cleanup = [];

  const template = await loadTemplateMeta();
  const lang = resolveLang(data.guest?.lang, data.event?.default_lang);
  document.documentElement.lang = lang;
  applyTheme(template, data.event.customization ?? {});

  const values = bindings(data, lang, template);
  for (const node of document.querySelectorAll('[data-bind]')) {
    const value = values[node.dataset.bind];
    node.textContent = value ?? '';
    node.hidden = !value;
  }
  for (const node of document.querySelectorAll('[data-i18n]')) {
    node.textContent = t(node.dataset.i18n, lang, { ...values, brand: ctxExtra.brand });
  }

  const ctx = {
    data,
    lang,
    template,
    tier: ctxExtra.tier ?? template.tier ?? 'free',
    brand: ctxExtra.brand ?? '',
    baseUrl: ctxExtra.baseUrl,
    media: ctxExtra.media ?? {},
    submitRsvp: ctxExtra.submitRsvp,
    now: () => Date.now(),
    cleanup,
  };
  for (const container of document.querySelectorAll('[data-block]')) {
    const renderer = BLOCKS[container.dataset.block];
    if (!renderer) continue; // hero: template markup, filled by data-bind
    container.replaceChildren();
    container.hidden = !renderer(container, ctx);
  }

  const main = page();
  main.dataset.state = 'ready';
  const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;
  document.dispatchEvent(new CustomEvent('invite:ready', { detail: { data, lang, reducedMotion } }));
}

// ---------------------------------------------------------------------------

async function startLive() {
  const config = readConfig();
  const fallbackLang = resolveLang(...(navigator.languages ?? []).map((l) => l.slice(0, 2)));
  if (!config?.code || !config.supabase_url || !config.anon_key) return showError('not_found', fallbackLang);

  const result = await rpc(config, 'get_invite', { code: config.code });
  if (!result?.ok) return showError(result?.error, fallbackLang);

  await render(result, {
    tier: config.tier,
    brand: config.brand,
    baseUrl: config.base_url,
    media: config.media,
    submitRsvp: (status, count) => rpc(config, 'submit_rsvp', { code: config.code, status, count }),
  });
}

function startPreview() {
  const show = (payload) => {
    if (!payload?.event || !payload?.guest) return;
    render(payload, {
      tier: payload.tier,
      brand: payload.brand,
      baseUrl: payload.base_url,
      media: payload.media,
      // Preview never writes to the database.
      submitRsvp: async (status, count) => ({ ok: true, rsvp_status: status, rsvp_count: count }),
    });
  };
  window.addEventListener('message', (e) => {
    if (e.data?.type === 'invite:data') show(e.data.payload);
  });
  if (window.__INVITE_DATA__) show(window.__INVITE_DATA__);
}

if (preview) startPreview();
else startLive();
