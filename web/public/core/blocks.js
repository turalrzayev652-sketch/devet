// Block renderers (spec/templates.md §4). Each fills its own container; templates only style dv-* classes.
// All text goes through textContent; URLs through safeUrl.
import { t, plural } from './i18n.js';
import { countdownParts, mapLinks, safeUrl } from './format.js';

function el(tag, attrs = {}, children = []) {
  const node = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (v === null || v === undefined || v === false) continue;
    if (k === 'text') node.textContent = v;
    else if (k === 'class') node.className = v;
    else node.setAttribute(k, v === true ? '' : String(v));
  }
  for (const child of [].concat(children)) if (child) node.append(child);
  return node;
}

// ---------------------------------------------------------------------------

function countdown(container, ctx) {
  const units = ['days', 'hours', 'minutes'];
  const values = {};
  const labels = {};
  const box = el('div', { class: 'dv-countdown', role: 'timer' }, [
    el('p', { class: 'dv-countdown__title', text: t('countdown.title', ctx.lang) }),
    el('div', { class: 'dv-countdown__units' }, units.map((u) => {
      values[u] = el('span', { class: 'dv-countdown__value' });
      labels[u] = el('span', { class: 'dv-countdown__label' });
      return el('div', { class: `dv-countdown__unit dv-countdown__unit--${u}` }, [values[u], labels[u]]);
    })),
  ]);

  const update = () => {
    const parts = countdownParts(ctx.data.event.starts_at, ctx.now());
    if (!parts) {
      container.hidden = true;
      return false;
    }
    for (const u of units) {
      values[u].textContent = String(parts[u]);
      labels[u].textContent = plural(`countdown.${u}`, parts[u], ctx.lang);
    }
    return true;
  };

  if (!update()) return false;
  container.append(box);
  const timer = setInterval(() => { if (!update()) clearInterval(timer); }, 30000);
  ctx.cleanup.push(() => clearInterval(timer));
  return true;
}

function gallery(container, ctx) {
  const max = ctx.template.photos?.max ?? 6;
  const urls = (ctx.media.photos ?? []).map(safeUrl).filter(Boolean).slice(0, max);
  if (!urls.length) return false;
  container.append(el('div', { class: 'dv-gallery' }, urls.map((src) =>
    el('figure', { class: 'dv-gallery__item' }, el('img', { src, alt: '', loading: 'lazy', decoding: 'async' })))));
  return true;
}

function music(container, ctx) {
  const src = ctx.template.music === false ? null : safeUrl(ctx.media.music);
  if (!src) return false;
  // preload="none": nothing is downloaded or played until the guest taps.
  const audio = el('audio', { src, preload: 'none', loop: true });
  const label = el('span', { class: 'dv-music__label', text: t('music.play', ctx.lang) });
  const button = el('button', { type: 'button', class: 'dv-music', 'aria-pressed': 'false' }, [label]);
  const setPlaying = (on) => {
    button.setAttribute('aria-pressed', String(on));
    label.textContent = t(on ? 'music.pause' : 'music.play', ctx.lang);
  };
  button.addEventListener('click', () => {
    if (audio.paused) audio.play().then(() => setPlaying(true), () => setPlaying(false));
    else { audio.pause(); setPlaying(false); }
  });
  audio.addEventListener('pause', () => setPlaying(false));
  ctx.cleanup.push(() => audio.pause());
  container.append(button, audio);
  return true;
}

function map(container, ctx) {
  const ev = ctx.data.event;
  const { google, waze } = mapLinks(ev);
  if (!google && !waze) return false;
  const link = (href, cls, key) => href && el('a', { class: `dv-map__link ${cls}`, href, target: '_blank', rel: 'noopener noreferrer', text: t(key, ctx.lang) });
  container.append(el('div', { class: 'dv-map' }, [
    el('h2', { class: 'dv-map__title', text: t('map.title', ctx.lang) }),
    el('p', { class: 'dv-map__venue', text: ev.venue_name }),
    ev.venue_address && el('p', { class: 'dv-map__address', text: ev.venue_address }),
    el('p', { class: 'dv-map__directions', text: t('map.directions', ctx.lang) }),
    el('div', { class: 'dv-map__links' }, [link(google, 'dv-map__google', 'map.google'), link(waze, 'dv-map__waze', 'map.waze')]),
  ]));
  return true;
}

function table(container, ctx) {
  const tableNo = ctx.data.guest.table_no;
  if (!tableNo) return false;
  const mates = (ctx.data.tablemates ?? []).filter((n) => typeof n === 'string' && n);
  container.append(el('div', { class: 'dv-table' }, [
    el('h2', { class: 'dv-table__title', text: t('table.title', ctx.lang) }),
    el('p', { class: 'dv-table__number', text: t('table.number', ctx.lang, { table_no: tableNo }) }),
    mates.length > 0 && el('p', { class: 'dv-table__mates-title', text: t('table.mates', ctx.lang) }),
    mates.length > 0 && el('ul', { class: 'dv-table__mates' }, mates.map((n) => el('li', { text: n }))),
  ]));
  return true;
}

function watermark(container, ctx) {
  if (ctx.tier !== 'free') return false;
  const href = safeUrl(ctx.baseUrl);
  container.append(el(href ? 'a' : 'span', { class: 'dv-watermark', href, target: href && '_blank', rel: href && 'noopener', text: t('watermark', ctx.lang, { brand: ctx.brand }) }));
  return true;
}

// ---------------------------------------------------------------------------
// RSVP: idle → sending → done | error  (data-state on the form)

function rsvp(container, ctx) {
  const lang = ctx.lang;
  const guest = ctx.data.guest;
  const max = Math.max(1, Number(guest.invited_count) || 1);
  let choice = guest.rsvp_status === 'no' ? 'no' : guest.rsvp_status === 'yes' ? 'yes' : null;

  const yesBtn = el('button', { type: 'button', class: 'dv-rsvp__choice dv-rsvp__yes', 'aria-pressed': 'false', text: t('rsvp.yes', lang) });
  const noBtn = el('button', { type: 'button', class: 'dv-rsvp__choice dv-rsvp__no', 'aria-pressed': 'false', text: t('rsvp.no', lang) });
  const countId = `dv-rsvp-count-${Math.random().toString(36).slice(2, 8)}`;
  const select = el('select', { id: countId, class: 'dv-rsvp__count' },
    Array.from({ length: max }, (_, i) => el('option', { value: i + 1, text: String(i + 1) })));
  select.value = String(Math.min(Math.max(Number(guest.rsvp_count) || max, 1), max));
  const countRow = el('div', { class: 'dv-rsvp__count-row' }, [
    el('label', { for: countId, class: 'dv-rsvp__count-label', text: t('rsvp.count_label', lang) }),
    select,
    el('p', { class: 'dv-rsvp__hint', text: t('rsvp.count_hint', lang, { max }) }),
  ]);
  const submit = el('button', { type: 'submit', class: 'dv-rsvp__submit', text: t('rsvp.submit', lang) });
  const message = el('p', { class: 'dv-rsvp__message', role: 'status', 'aria-live': 'polite' });
  const answer = el('p', { class: 'dv-rsvp__answer' });
  const change = el('button', { type: 'button', class: 'dv-rsvp__change', text: t('rsvp.change', lang) });
  const fields = el('div', { class: 'dv-rsvp__fields' }, [
    el('div', { class: 'dv-rsvp__choices', role: 'group' }, [yesBtn, noBtn]), countRow, submit,
  ]);
  const done = el('div', { class: 'dv-rsvp__done' }, [answer, change]);
  const form = el('form', { class: 'dv-rsvp', novalidate: true }, [
    el('h2', { class: 'dv-rsvp__title', text: t('rsvp.title', lang) }), fields, message, done,
  ]);

  const setState = (state) => { form.dataset.state = state; };
  const refreshChoice = () => {
    yesBtn.setAttribute('aria-pressed', String(choice === 'yes'));
    noBtn.setAttribute('aria-pressed', String(choice === 'no'));
    countRow.hidden = choice !== 'yes' || max === 1;
    submit.disabled = !choice;
  };
  const showDone = (status, count, thanks) => {
    fields.hidden = true;
    done.hidden = false;
    message.textContent = thanks ? t(status === 'yes' ? 'rsvp.thanks_yes' : 'rsvp.thanks_no', lang) : '';
    answer.textContent = status === 'yes' ? t('rsvp.current_yes', lang, { count }) : t('rsvp.current_no', lang);
    setState('done');
  };
  const showForm = () => {
    fields.hidden = false;
    done.hidden = true;
    message.textContent = '';
    refreshChoice();
    setState('idle');
  };

  yesBtn.addEventListener('click', () => { choice = 'yes'; refreshChoice(); });
  noBtn.addEventListener('click', () => { choice = 'no'; refreshChoice(); });
  change.addEventListener('click', showForm);
  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    if (!choice || form.dataset.state === 'sending') return;
    const count = choice === 'yes' ? Number(select.value) : 0;
    if (choice === 'yes' && !(count >= 1 && count <= max)) {
      message.textContent = t('rsvp.invalid_count', lang, { max });
      setState('error');
      return;
    }
    setState('sending');
    submit.disabled = true;
    message.textContent = t('rsvp.sending', lang);
    const result = await ctx.submitRsvp(choice, count);
    if (result?.ok) {
      guest.rsvp_status = result.rsvp_status;
      guest.rsvp_count = result.rsvp_count;
      showDone(result.rsvp_status, result.rsvp_count, true);
      document.dispatchEvent(new CustomEvent('invite:rsvp', { detail: { status: result.rsvp_status, count: result.rsvp_count } }));
    } else {
      submit.disabled = false;
      message.textContent = result?.error === 'invalid_count' ? t('rsvp.invalid_count', lang, { max })
        : result?.error === 'rate_limited' ? t('error.rate_limited.body', lang)
        : t('rsvp.error', lang);
      setState('error');
    }
  });

  container.append(form);
  if (guest.rsvp_status === 'yes' || guest.rsvp_status === 'no') showDone(guest.rsvp_status, guest.rsvp_count, false);
  else showForm();
  return true;
}

export const BLOCKS = { countdown, gallery, music, map, table, rsvp, watermark };
