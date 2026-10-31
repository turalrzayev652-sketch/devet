/* Devet prototype runtime (no dependencies). Each screen page calls Proto.screen({...}).
   Page controls: theme (light/dark), language (AZ/RU), font scale (100%/130%), state tabs.
   Links: data-go="06-qonaqlar.html?state=list" (other screen), data-state="key" (same screen), data-toast="text". */
(function () {
  'use strict';

  // ------------------------------------------------------------------ icons (24×24, stroke 1.5, round)
  const ICONS = {
    back: '<path d="M15 18l-6-6 6-6"/>',
    chevronRight: '<path d="M9 6l6 6-6 6"/>',
    chevronDown: '<path d="M6 9l6 6 6-6"/>',
    close: '<path d="M6 6l12 12M18 6L6 18"/>',
    eye: '<path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
    eyeOff: '<path d="M3 3l18 18"/><path d="M10.6 6.1A9.6 9.6 0 0 1 12 6c6.4 0 10 6 10 6a17 17 0 0 1-3.2 3.9"/><path d="M6.6 6.6C3.8 8.3 2 12 2 12s3.6 7 10 7c1.7 0 3.2-.4 4.5-1.1"/><path d="M9.9 9.9a3 3 0 0 0 4.2 4.2"/>',
    search: '<circle cx="11" cy="11" r="7"/><path d="M20 20l-3.5-3.5"/>',
    plus: '<path d="M12 5v14M5 12h14"/>',
    more: '<circle cx="5" cy="12" r="1"/><circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/>',
    users: '<circle cx="9" cy="8" r="3.5"/><path d="M2.5 19.5v-.5A4.5 4.5 0 0 1 7 14.5h4a4.5 4.5 0 0 1 4.5 4.5v.5"/><path d="M16 4.6a3.5 3.5 0 0 1 0 6.8M18.5 14.7A4.5 4.5 0 0 1 21.5 19v.5"/>',
    send: '<path d="M21 3L10.5 13.5"/><path d="M21 3l-6.5 18-4-7.5L3 9.5z"/>',
    chart: '<path d="M5 20V11M12 20V5M19 20v-6M3 20h18"/>',
    menu: '<path d="M4 7h16M4 12h16M4 17h16"/>',
    phone: '<path d="M5 4h3.5l2 5-2.4 1.5a11 11 0 0 0 5.4 5.4L15 13.5l5 2V19a2 2 0 0 1-2 2A16 16 0 0 1 3 6a2 2 0 0 1 2-2z"/>',
    pencil: '<path d="M4 20h4L19 9l-4-4L4 16z"/><path d="M13.5 6.5l4 4"/>',
    trash: '<path d="M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3"/>',
    table: '<rect x="3" y="6" width="18" height="5" rx="1.5"/><path d="M6 11v8M18 11v8"/>',
    side: '<path d="M7 4v16M17 4v16M3 8h8M13 16h8"/>',
    alert: '<path d="M12 3.5l9.5 16.5h-19z"/><path d="M12 10v4.5M12 17.5v.01"/>',
    wifiOff: '<path d="M3 3l18 18"/><path d="M8.5 16.5a5 5 0 0 1 7 0M5 13a10 10 0 0 1 4-2.6M19 13a10 10 0 0 0-2.3-1.7M2 9.5a15 15 0 0 1 4.3-2.7M22 9.5A15 15 0 0 0 12 6c-.8 0-1.6.1-2.4.2"/><path d="M12 20h.01"/>',
    refresh: '<path d="M20 11a8 8 0 0 0-14.9-3M4 4v4h4"/><path d="M4 13a8 8 0 0 0 14.9 3M20 20v-4h-4"/>',
    check: '<path d="M5 12.5l4.5 4.5L19 7"/>',
    sparkle: '<path d="M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8z"/><path d="M19 16l.7 1.8 1.8.7-1.8.7L19 21l-.7-1.8-1.8-.7 1.8-.7z"/>',
    globe: '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a14 14 0 0 1 0 18M12 3a14 14 0 0 0 0 18"/>',
    mail: '<rect x="3" y="5" width="18" height="14" rx="2.5"/><path d="M4 7l8 6 8-6"/>',
    lock: '<rect x="5" y="10.5" width="14" height="10" rx="2.5"/><path d="M8 10.5V8a4 4 0 0 1 8 0v2.5"/>',
    user: '<circle cx="12" cy="8" r="4"/><path d="M4 20.5v-.5A5.5 5.5 0 0 1 9.5 14.5h5A5.5 5.5 0 0 1 20 20v.5"/>',
    userPlus: '<circle cx="10" cy="8" r="4"/><path d="M2.5 20.5v-.5A5.5 5.5 0 0 1 8 14.5h4M18 13v6M15 16h6"/>',
    contacts: '<rect x="4" y="3" width="15" height="18" rx="2.5"/><circle cx="11.5" cy="10" r="2.5"/><path d="M8 16.5a3.5 3.5 0 0 1 7 0M2 8h2M2 12h2M2 16h2"/>',
    sheet: '<path d="M6 3h8l5 5v13H6z"/><path d="M14 3v5h5M9 13h7M9 17h7M12.5 11v8"/>',
    skip: '<path d="M5 6l8 6-8 6zM17 6v12"/>',
    filter: '<path d="M4 6h16M7 12h10M10 18h4"/>',
  };
  const icon = (name, cls = '') => `<svg class="icon ${cls}" viewBox="0 0 24 24" aria-hidden="true">${ICONS[name] || ''}</svg>`;
  // WhatsApp mark as a functional indicator only (simplified glyph, its own colour).
  const WA = '<svg class="wa" viewBox="0 0 24 24" aria-hidden="true"><path fill="#25D366" d="M12 2.5a9.5 9.5 0 0 0-8.2 14.3L2.5 21.5l4.8-1.3A9.5 9.5 0 1 0 12 2.5z"/><path fill="#fff" d="M9.2 7.4c.2 0 .4 0 .6.4l.8 1.9c.1.2 0 .4-.1.6l-.6.7c-.1.1-.1.3 0 .5a6.9 6.9 0 0 0 3.2 2.8c.2.1.4.1.5-.1l.7-.8c.2-.2.4-.2.6-.1l1.9.9c.2.1.3.3.3.5 0 1.1-.9 2-2.4 2-2.8-.2-6.7-3.6-7-7 0-1.5.9-2.3 1.5-2.3z"/></svg>';

  // Abstract art (no people): botanical line drawing, empty-state and celebration marks.
  const ART = {
    botanical: '<svg viewBox="0 0 393 210" fill="none" stroke="currentColor" stroke-width="1.2" stroke-linecap="round" aria-hidden="true"><path d="M-10 190 C 80 150, 120 80, 210 60 S 360 70, 410 20" opacity=".55"/><path d="M60 162 c 10 -22 34 -30 52 -24 c -8 20 -30 32 -52 24z M128 110 c 18 -16 42 -14 56 -2 c -16 14 -40 16 -56 2z M196 66 c 6 -24 28 -38 48 -36 c -4 22 -26 38 -48 36z M262 58 c 20 -10 42 -2 52 12 c -20 8 -42 2 -52 -12z M330 44 c 8 -20 30 -28 48 -22 c -8 18 -30 28 -48 22z" opacity=".7"/><path d="M40 205 C 110 175, 150 140, 170 100" opacity=".35"/><circle cx="214" cy="58" r="3" opacity=".6"/><circle cx="300" cy="52" r="2.5" opacity=".6"/></svg>',
    emptyGuests: '<svg viewBox="0 0 180 140" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="40" y="22" width="100" height="80" rx="10" opacity=".9"/><path d="M40 34 L90 70 L140 34" opacity=".9"/><path d="M20 118 C 50 100, 70 128, 100 112 S 150 104, 166 118" opacity=".5"/><path d="M150 18 l3 8 8 3 -8 3 -3 8 -3 -8 -8 -3 8 -3z" opacity=".8"/><path d="M28 44 l2 5 5 2 -5 2 -2 5 -2 -5 -5 -2 5 -2z" opacity=".6"/></svg>',
    celebrate: '<svg viewBox="0 0 180 140" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" aria-hidden="true"><circle cx="90" cy="74" r="34" opacity=".9"/><path d="M74 75l11 11 22-24" stroke-width="2"/><path d="M30 30l4 10 10 4 -10 4 -4 10 -4 -10 -10 -4 10 -4z M150 24l3 7 7 3 -7 3 -3 7 -3 -7 -7 -3 7 -3z M146 112l2 5 5 2 -5 2 -2 5 -2 -5 -5 -2 5 -2z" opacity=".75"/><path d="M24 104c8-6 14 2 22-4M134 60c6-6 14-2 20-8" opacity=".5"/></svg>',
  };

  // ------------------------------------------------------------------ preferences
  const store = {
    get(k) { try { return localStorage.getItem(k); } catch { return null; } },
    set(k, v) { try { localStorage.setItem(k, v); } catch { /* private mode: keep in memory */ } },
  };
  const params = new URLSearchParams(location.search);
  const prefs = {
    theme: params.get('theme') || store.get('devet.theme') || 'light',
    lang: params.get('lang') || store.get('devet.lang') || 'az',
    scale: params.get('scale') || store.get('devet.scale') || '1',
  };

  // Screens that exist in this phase; links to others show a toast instead of a 404.
  const BUILT = new Set(['01-giris.html', '06-qonaqlar.html', '08-gonderme.html']);

  // ------------------------------------------------------------------ shared copy
  const COMMON = {
    az: {
      screens: 'Bütün ekranlar', states: 'Hallar', tabGuests: 'Qonaqlar', tabSend: 'Göndər', tabStats: 'Statistika', tabMore: 'Daha çox',
      coming: 'Gəlir {n}', declined: 'Gəlmir', viewed: 'Baxdı', pending: 'Cavab yoxdur', unsent: 'Göndərilməyib',
      people: '{n} nəfər', table: 'Masa {n}', noTable: 'Masasız', groom: 'Bəy tərəfi', bride: 'Gəlin tərəfi',
      notBuilt: 'Bu ekran növbəti mərhələdə hazırlanacaq', retry: 'Yenidən cəhd et', offline: 'İnternet bağlantısı yoxdur. Dəyişikliklər bağlantı bərpa olunanda göndəriləcək.',
      networkError: 'Məlumat yüklənmədi. İnternet bağlantısını yoxlayın.', save: 'Yadda saxla', cancel: 'Ləğv et',
      eventTitle: 'Aysel və Ramin', eventType: 'Toy', eventDate: '12 iyul 2027, 18:00', venue: 'Ağ Saray şadlıq evi', city: 'Bakı',
    },
    ru: {
      screens: 'Все экраны', states: 'Состояния', tabGuests: 'Гости', tabSend: 'Отправка', tabStats: 'Статистика', tabMore: 'Ещё',
      coming: 'Придёт {n}', declined: 'Не придёт', viewed: 'Просмотрено', pending: 'Нет ответа', unsent: 'Не отправлено',
      people: '{n} чел.', table: 'Стол {n}', noTable: 'Без стола', groom: 'Сторона жениха', bride: 'Сторона невесты',
      notBuilt: 'Этот экран будет готов на следующем этапе', retry: 'Повторить', offline: 'Нет подключения к интернету. Изменения отправятся, когда связь восстановится.',
      networkError: 'Не удалось загрузить данные. Проверьте подключение к интернету.', save: 'Сохранить', cancel: 'Отмена',
      eventTitle: 'Aysel və Ramin', eventType: 'Свадьба', eventDate: '12 июля 2027, 18:00', venue: 'Ağ Saray şadlıq evi', city: 'Баку',
    },
  };

  // ------------------------------------------------------------------ sample data (DESIGN_PROMPT.md §4)
  const SAL = {
    az: { muellim: '{n} müəllim', xanim: '{n} xanım', bey: '{n} bəy', none: '{n}', family: '{d} və ailəsi' },
    ru: { muellim: '{n} муаллим', xanim: '{n} ханум', bey: '{n} бей', none: '{n}', family: '{d} с семьёй' },
  };
  const GREET = {
    az: { muellim: 'Hörmətli {d}!', xanim: 'Hörmətli {d}!', bey: 'Hörmətli {d}!', none: 'Hörmətli {d}!', family: 'Hörmətli {d}!' },
    ru: { muellim: 'Уважаемый {d}!', xanim: 'Уважаемая {d}!', bey: 'Уважаемый {d}!', none: 'Здравствуйте, {d}!', family: 'Уважаемые {d}!' },
  };
  const DATA = {
    code: 'K7D2M9QX',
    link: 'devet.pages.dev/i/K7D2M9QX',
    guests: [
      { id: 1, name: 'Elçin', sal: 'muellim', family: true, count: 4, table: '12', side: 'groom', status: 'coming', rsvp: 4, phone: '+994 50 123 45 67', glang: 'az' },
      { id: 2, name: 'Leyla', sal: 'xanim', family: false, count: 1, table: '7', side: 'bride', status: 'viewed', phone: '+994 55 111 22 33', glang: 'az' },
      { id: 3, name: 'Rəşad', sal: 'bey', family: false, count: 2, table: '12', side: 'groom', status: 'declined', phone: '+994 70 222 33 44', glang: 'ru' },
      { id: 4, name: 'Günel Məmmədova', sal: 'none', family: false, count: 3, table: null, side: 'bride', status: 'pending', phone: '+994 51 765 43 21', glang: 'az' },
      { id: 5, name: 'Tural Əliyev', sal: 'none', family: false, count: 2, table: '3', side: 'groom', status: 'unsent', phone: '+994 77 444 55 66', glang: 'az' },
      { id: 6, name: 'Səbinə', sal: 'xanim', family: true, count: 5, table: '7', side: 'bride', status: 'coming', rsvp: 5, phone: '+994 99 555 66 77', glang: 'az' },
    ],
    stats: { sent: 198, viewed: 164, coming: 121, comingPeople: 387, declined: 18, pending: 59 },
  };
  const fill = (s, vars = {}) => String(s).replace(/\{(\w+)\}/g, (_, k) => (vars[k] ?? ''));
  const displayName = (g, lang) => {
    const d = fill(SAL[lang][g.sal] || '{n}', { n: g.name });
    return g.family ? fill(SAL[lang].family, { d }) : d;
  };
  const greeting = (g, lang) => fill(GREET[lang][g.family ? 'family' : g.sal], { d: displayName(g, lang) });
  const initials = (g) => g.name.split(/\s+/).map((w) => w[0]).join('').slice(0, 2).toUpperCase();

  // ------------------------------------------------------------------ screen mount
  function screen(def) {
    const root = document.documentElement;
    root.dataset.theme = prefs.theme;
    root.lang = prefs.lang;
    root.style.setProperty('--font-scale', prefs.scale);
    let current = params.get('state') && def.states.some((s) => s.key === params.get('state')) ? params.get('state') : def.states[0].key;

    const strings = Object.assign({}, COMMON[prefs.lang], (def.strings || {})[prefs.lang]);
    const t = (key, vars) => fill(strings[key] ?? key, vars);
    const L = (obj) => (typeof obj === 'string' ? obj : obj[prefs.lang] ?? obj.az);

    const ctx = {
      t, lang: prefs.lang, icon, WA, ART, DATA, displayName: (g) => displayName(g, prefs.lang), greeting: (g) => greeting(g, prefs.lang), initials,
      statusPill: (g) => `<span class="pill ${g.status}">${t(g.status, { n: g.rsvp ?? '' }).trim()}</span>`,
      meta: (g) => [t('people', { n: g.count }), g.table ? t('table', { n: g.table }) : t('noTable'), t(g.side)].join(' · '),
      tabbar: (active) => `<nav class="tabbar" aria-label="Tədbir">${[
        ['guests', 'users', '06-qonaqlar.html'], ['send', 'send', '08-gonderme.html'], ['stats', 'chart', '09-statistika.html'], ['more', 'menu', '13-daha-cox.html'],
      ].map(([k, ic, href]) => `<a href="#" data-go="${href}" ${k === active ? 'aria-current="page"' : ''}>${icon(ic)}<span>${t('tab' + k[0].toUpperCase() + k.slice(1))}</span></a>`).join('')}</nav>`,
    };

    document.title = `${L(def.title)} — Devet prototip`;
    const pressed = (v, cur) => `aria-pressed="${v === cur}"`;
    document.body.innerHTML = `
      <header class="chrome">
        <a href="index.html">← ${t('screens')}</a>
        <h1>${def.number}. ${L(def.title)}</h1>
        <span class="grow"></span>
        <span class="group" role="group" aria-label="Theme"><button data-pref="theme" data-v="light" ${pressed('light', prefs.theme)}>Light</button><button data-pref="theme" data-v="dark" ${pressed('dark', prefs.theme)}>Dark</button></span>
        <span class="group" role="group" aria-label="Language"><button data-pref="lang" data-v="az" ${pressed('az', prefs.lang)}>AZ</button><button data-pref="lang" data-v="ru" ${pressed('ru', prefs.lang)}>RU</button></span>
        <span class="group" role="group" aria-label="Font scale"><button data-pref="scale" data-v="1" ${pressed('1', prefs.scale)}>Aa 100%</button><button data-pref="scale" data-v="1.3" ${pressed('1.3', prefs.scale)}>Aa 130%</button></span>
      </header>
      <nav class="states" aria-label="${t('states')}">${def.states.map((s) => `<a href="?state=${s.key}" data-state="${s.key}">${L(s.label)}</a>`).join('')}</nav>
      <main class="stage">
        <div class="device" id="device">
          <div class="statusbar"><span>9:41</span><span class="island"></span><span class="sys">
            <svg width="18" height="12" viewBox="0 0 18 12" fill="currentColor"><rect x="0" y="8" width="3" height="4" rx="1"/><rect x="5" y="5.5" width="3" height="6.5" rx="1"/><rect x="10" y="3" width="3" height="9" rx="1"/><rect x="15" y="0" width="3" height="12" rx="1"/></svg>
            <svg width="26" height="12" viewBox="0 0 26 12" fill="none" stroke="currentColor"><rect x=".5" y=".5" width="22" height="11" rx="3.5" opacity=".4"/><rect x="2" y="2" width="17" height="8" rx="2" fill="currentColor" stroke="none"/><path d="M24.5 4v4" opacity=".5"/></svg>
          </span></div>
          <div id="screen-root"></div>
          <div class="homebar"></div>
        </div>
      </main>
      <p class="note" id="note"></p>`;

    const device = document.getElementById('device');
    const rootEl = document.getElementById('screen-root');

    function render() {
      const state = def.states.find((s) => s.key === current);
      const out = state.render(ctx);
      const view = typeof out === 'string' ? { html: out } : out;
      rootEl.innerHTML = `<div class="screen ${view.tabbar ? 'has-tabbar' : ''}">${view.html}</div>${view.tabbar ? ctx.tabbar(view.tabbar) : ''}${view.overlay || ''}`;
      document.querySelectorAll('.states a').forEach((a) => a.setAttribute('aria-current', String(a.dataset.state === current)));
      document.getElementById('note').textContent = state.note ? L(state.note) : '';
      const url = new URL(location.href);
      url.searchParams.set('state', current);
      history.replaceState(null, '', url);
      if (state.after) state.after(device, ctx);
    }

    function toast(text) {
      const el = document.createElement('div');
      el.className = 'toast';
      el.setAttribute('role', 'status');
      el.textContent = text;
      device.append(el);
      setTimeout(() => el.remove(), 2400);
    }

    document.addEventListener('click', (e) => {
      const pref = e.target.closest('[data-pref]');
      if (pref) {
        store.set(`devet.${pref.dataset.pref}`, pref.dataset.v);
        const url = new URL(location.href);
        url.searchParams.delete(pref.dataset.pref);
        location.replace(url.toString());
        return;
      }
      const go = e.target.closest('[data-go]');
      if (go) {
        e.preventDefault();
        const file = go.dataset.go.split('?')[0];
        if (BUILT.has(file)) location.href = go.dataset.go;
        else toast(t('notBuilt'));
        return;
      }
      const st = e.target.closest('[data-state]');
      if (st) { e.preventDefault(); current = st.dataset.state; render(); return; }
      const tst = e.target.closest('[data-toast]');
      if (tst) { e.preventDefault(); toast(tst.dataset.toast); return; }
      const pw = e.target.closest('[data-toggle-password]');
      if (pw) {
        const input = pw.closest('.input').querySelector('input');
        const show = input.type === 'password';
        input.type = show ? 'text' : 'password';
        pw.innerHTML = icon(show ? 'eyeOff' : 'eye');
        pw.setAttribute('aria-label', show ? 'Gizlət' : 'Göstər');
      }
    });

    render();
    window.__proto = { render, toast, setState(key) { current = key; render(); }, get state() { return current; } };
  }

  window.Proto = { screen, icon, WA, ART, DATA, COMMON, displayName, greeting, BUILT, prefs };
})();
