# templates.md — Şablon müqaviləsi

Bu sənəd qonaq səhifəsi şablonları (`/web/public/templates/<id>/`) ilə ortaq kod (`/web/public/core/invite-core.js`, T23) arasındakı müqaviləni təsvir edir. Şablon **yalnız görünüşü** verir (HTML quruluşu, CSS, animasiya); məlumatı doldurmaq, cavab göndərmək, dil seçmək, hitabı formatlamaq — hamısı `invite-core.js`-in işidir.

Əlaqəli: `PRODUCT.md` §5 (`templates`, `events.customization`), §6 (`get_invite`), §11 (bloklar); `i18n/invite.json` (sabit mətnlər); `template.schema.json` (`template.json`-un maşın sxemi).

---

## 1. Qovluq quruluşu

```
web/public/templates/<id>/
  index.html       — səhifə (məcburi)
  style.css        — üslub (məcburi)
  motion.js        — animasiyalar, ES module (məcburi deyil)
  template.json    — metadata (məcburi), sxem: template.schema.json
  thumb.jpg        — kataloq şəkli, 600×800, ≤ 60 KB (məcburi)
  assets/          — şəkillər, şriftlər (woff2), naxışlar
```

- `<id>` = `templates.id` = `template.json` → `id` (məs. `free-01`, `premium-01`). Pattern: `^(free|premium)-[0-9]{2}$`.
- Səhifə `/i/<kod>` ünvanında açılır, ona görə Pages Function `<head>`-ə `<base href="/templates/<id>/">` əlavə edir (T24). Şablon daxilində **nisbi yollar** istifadə olunur (`style.css`, `assets/bg.webp`). Ortaq kod mütləq yolla qoşulur: `/core/invite-core.js`.
- Budcə: ilk yükləmə (HTML + CSS + JS + ilk ekranın şəkilləri + şriftlər) **< 1,5 MB**; qalereya şəkilləri `loading="lazy"`. Xarici CDN və ya Google Fonts **yoxdur** — şriftlər `assets/`-dədir.

## 2. `template.json`

```json
{
  "id": "free-01",
  "version": 1,
  "tier": "free",
  "name": { "az": "Klassik", "ru": "Классика", "en": "Classic", "tr": "Klasik" },
  "event_types": ["wedding", "engagement", "henna", "birthday", "jubilee"],
  "langs": ["az", "ru", "en", "tr"],
  "blocks": ["hero", "countdown", "gallery", "music", "map", "table", "rsvp", "watermark"],
  "css_vars": {
    "--dv-color-bg":      { "type": "color", "default": "#faf7f2", "label_key": "template.var.color_bg" },
    "--dv-color-text":    { "type": "color", "default": "#2b2622", "label_key": "template.var.color_text" },
    "--dv-color-accent":  { "type": "color", "default": "#8a5a44", "label_key": "template.var.color_accent" },
    "--dv-font-heading":  { "type": "font",  "default": "cormorant", "label_key": "template.var.font_heading" },
    "--dv-font-body":     { "type": "font",  "default": "inter", "label_key": "template.var.font_body" }
  },
  "fonts": {
    "cormorant": { "family": "Cormorant Garamond", "fallback": "serif", "file": "assets/fonts/cormorant.woff2" },
    "inter":     { "family": "Inter", "fallback": "sans-serif", "file": "assets/fonts/inter.woff2" }
  },
  "texts": {
    "intro":   { "max_length": 200, "label_key": "template.text.intro" },
    "closing": { "max_length": 120, "label_key": "template.text.closing" }
  },
  "photos": { "max": 6 },
  "music": true
}
```

| Sahə | Məna |
| --- | --- |
| `id` | Qovluq adı və `templates.id`. |
| `version` | Tam ədəd; dizayn dəyişəndə artır. `templates.version` ilə eyni olmalıdır. |
| `tier` | `free` və ya `premium` (`templates.is_premium`). **Qonaq limiti burada yazılmır**: `free` → `app_config.free_guest_limit`, `premium` → `premium_guest_limit` (+ `limit_addon`), bax PRODUCT §7. |
| `name` | 4 dildə ad (`templates.name`). |
| `event_types` | Şablonun yaraşdığı tədbir növləri; kataloqda filtr üçün. |
| `langs` | Dəstəklənən dillər (`templates.langs`); dörd dilin mətni sığmalıdır. |
| `blocks` | Şablonda olan bloklar (bax §4). `hero` və `rsvp` məcburidir; `tier: free` olanda `watermark` məcburidir. |
| `css_vars` | Ailənin tətbiqdə dəyişə bildiyi CSS dəyişənləri. Ad `--dv-` ilə başlayır. `type`: `color` (`#rrggbb`) və ya `font` (`fonts` açarı). `label_key` — tətbiq lüğətində (`app.json`) açar. |
| `fonts` | `font` tipli dəyişənlər üçün seçimlər. `file` — şablon qovluğuna nisbi `woff2`. |
| `texts` | Ailənin yaza bildiyi əlavə mətn yerləri (`customization.texts.<açar>`), maksimum uzunluqla. |
| `photos.max` | Qalereyada maksimum şəkil (0–6). |
| `music` | Musiqi bloku dəstəklənirmi. |

Sxem: [`template.schema.json`](template.schema.json).

### `events.customization` (tətbiqin yazdığı)

```json
{
  "colors": { "--dv-color-accent": "#a0522d" },
  "fonts":  { "--dv-font-heading": "cormorant" },
  "texts":  { "intro": "Ömrümüzün ən xoşbəxt gününü sizinlə bölüşmək istəyirik." },
  "photos": ["<event_id>/photos/1.jpg", "<event_id>/photos/2.jpg"],
  "music":  "<event_id>/music/song.mp3"
}
```

- `colors`/`fonts` açarları `template.json → css_vars`-da olmalıdır; olmayanlar nəzərə alınmır. Verilməyən dəyişən `default` alır.
- `photos`, `music` — `event-media` bucket-indəki yollar. Qonaq səhifəsi üçün Pages Function onları imzalı linklərlə əvəz edir (TASKS T24 qərarı); şablon həmişə hazır URL alır.
- `texts` dəyərləri ailənin mətnidir, tərcümə olunmur; `textContent` kimi yazılır (HTML qəbul edilmir).

## 3. Mətn bağlantıları

### 3.1 Dinamik məlumat — `data-bind`

`invite-core.js` `data-bind="<açar>"` olan elementin `textContent`-ini doldurur. Boş dəyərdə element `hidden` olur.

| Açar | Mənbə / format |
| --- | --- |
| `guest.display_name` | Hitab + "ailəliklə" formatı, qonağın dilində (`salutation.*`, `salutation.family`). |
| `guest.greeting` | `greeting.<hitab>` və ya `greeting.family` (`{display_name}` doldurulur). |
| `event.title_names` | `events.title_names` (məs. "Aysel və Ramin"). |
| `event.host_names` | `events.host_names`; boşdursa gizlənir. |
| `event.hosts_line` | `event.hosts` mətni (`{host_names}` ilə); boşdursa gizlənir. |
| `event.type_label` | `event_type.<növ>`. |
| `event.invite_sentence` | `invite.<növ>`. |
| `event.date` | `starts_at`, `Intl.DateTimeFormat(lang, { dateStyle: 'long' })`. |
| `event.weekday` | `Intl.DateTimeFormat(lang, { weekday: 'long' })`. |
| `event.time` | `Intl.DateTimeFormat(lang, { timeStyle: 'short' })`. |
| `event.venue_name` | `events.venue_name`. |
| `event.venue_address` | `events.venue_address`; boşdursa gizlənir. |
| `text.<açar>` | `customization.texts.<açar>`; boşdursa gizlənir. |

Tarix/saat **tədbirin yerli vaxtı** ilə göstərilir: hələlik `Asia/Baku` (məlumat modelində saat qurşağı sahəsi yoxdur — açıq sual, bax §8).

### 3.2 Sabit mətn — `data-i18n`

`data-i18n="<invite.json açarı>"` olan elementin `textContent`-i qonağın dilində yazılır. Placeholder-lər məlumatdan doldurulur. Məs.:

```html
<h2 data-i18n="map.title"></h2>
<p data-i18n="countdown.title"></p>
```

Şablon HTML-ində **heç bir görünən mətn birbaşa yazılmır** (CLAUDE.md kod qaydası) — ya `data-bind`, ya `data-i18n`.

## 4. Bloklar

Hər blok konteynerdir: `<section data-block="<ad>"></section>`. `invite-core.js` konteynerin içini özü qurur (eyni davranış, eyni xəta mesajları — bütün şablonlarda). Şablon yalnız konteynerin yerini və CSS-i verir. Konteyner `template.json → blocks`-da olmalıdır və səhifədə ən çox bir dəfə olur.

Blok göstərilmirsə konteynerə `hidden` atributu qoyulur — şablon bunu nəzərə alaraq layout qurmalıdır.

| Blok | Nə qurulur | Gizlənir, əgər |
| --- | --- | --- |
| `hero` | Şablonun öz HTML-i (`data-bind` ilə); core yalnız doldurur. | — (məcburi) |
| `countdown` | `.dv-countdown` → 3 `.dv-countdown__unit` (`__value`, `__label`): gün/saat/dəqiqə; `countdown.<vahid>.<plural>` ilə; dəqiqədə bir yenilənir. | tədbir başlayıb |
| `gallery` | `.dv-gallery` → `figure.dv-gallery__item > img` (lazy, `alt=""`). | şəkil yoxdur |
| `music` | `button.dv-music` (`aria-pressed`), mətn `music.play`/`music.pause`; `<audio preload="none">`. **Yalnız toxunuşla başlayır.** | musiqi yoxdur |
| `map` | `.dv-map` → başlıq (`map.title`), məkan adı/ünvanı, `a.dv-map__google`, `a.dv-map__waze` (`target="_blank" rel="noopener"`). Link: `maps_url` varsa o, yoxdursa `lat,lng`; Waze: `https://waze.com/ul?ll=<lat>,<lng>&navigate=yes`. | nə `maps_url`, nə koordinat var |
| `table` | `.dv-table` → `table.title`, `table.number`; `tablemates` doludursa `table.mates` + `ul.dv-table__mates`. | `table_no` boşdur |
| `rsvp` | `form.dv-rsvp`: `rsvp.yes`/`rsvp.no` düymələri, `yes` seçiləndə nəfər seçimi (1…`invited_count`, `invited_count = 1` olanda gizli), göndər; sonra təşəkkür ekranı və "cavabı dəyiş". Xəta mətnləri `rsvp.error`, `rsvp.invalid_count`. Vəziyyət: `data-state="idle|sending|done|error"`. | — (məcburi) |
| `watermark` | `a.dv-watermark` → `watermark` mətni (`{brand}` = `{{BRAND_NAME}}`), link `PUBLIC_BASE_URL`. | `tier: premium` |

Core sinifləri `dv-` prefiksi ilə BEM formatındadır; şablon onları `style.css`-də istədiyi kimi üslublandırır, amma DOM-u dəyişmir.

## 5. Skriptlər və hadisələr

`index.html` minimal skeleti:

```html
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <link rel="stylesheet" href="style.css">
  <!-- T24 buraya <base>, og:* teqləri və #invite-config əlavə edir -->
</head>
<body>
  <main class="dv-page" data-state="loading">
    <section data-block="hero">
      <p data-bind="guest.greeting"></p>
      <h1 data-bind="event.title_names"></h1>
      <p data-bind="event.invite_sentence"></p>
      <p><span data-bind="event.date"></span> · <span data-bind="event.time"></span></p>
    </section>
    <section data-block="countdown"></section>
    <section data-block="rsvp"></section>
    <section data-block="watermark"></section>
  </main>
  <script type="module" src="/core/invite-core.js"></script>
  <script type="module" src="motion.js"></script>
</body>
</html>
```

- `main.dv-page` `data-state`: `loading` → `ready` və ya `error`. Xəta halında core `main`-in içini xəta ekranı ilə əvəz edir (`error.not_found`, `error.event_past`, `error.network`, `error.rate_limited`).
- `<html lang>` qonağın dilinə qoyulur.
- CSS dəyişənləri (`customization` + `default`) `document.documentElement.style`-a yazılır; `font` dəyişənləri üçün `@font-face` core tərəfindən `fonts`-dan yaradılır.
- Hadisələr (`document`-də, `CustomEvent`):
  - `invite:ready` — `detail = { data, lang, reducedMotion }`; `motion.js` animasiyanı bundan sonra başladır.
  - `invite:rsvp` — `detail = { status, count }`; uğurlu cavabdan sonra (məs. təbrik animasiyası üçün).
- `motion.js` **məcburi qayda**: `matchMedia('(prefers-reduced-motion: reduce)')` doğrudursa hərəkətli animasiya yoxdur (yalnız ani və ya opacity keçidləri). Musiqi heç vaxt avtomatik başlamır. Animasiya məzmunu gizlətməməlidir — `motion.js` yüklənməsə də səhifə tam oxunaqlıdır.

## 6. Məlumat mənbələri

### 6.1 Canlı rejim (`/i/<kod>`)

Pages Function `<head>`-ə konfiqurasiya yerləşdirir (T24):

```html
<script id="invite-config" type="application/json">
  { "code": "K7D2M9QX", "supabase_url": "https://….supabase.co", "anon_key": "…",
    "brand": "Devet", "base_url": "https://….pages.dev", "tier": "free",
    "media": { "photos": ["https://…signed…"], "music": "https://…signed…" } }
</script>
```

Core `get_invite(code)` çağırır (anon açar), cavabı `submit_rsvp` ilə göndərir. Cavab forması PRODUCT §6-dadır.

### 6.2 Önizləmə rejimi (`?preview=1`)

Tətbiqin WebView-u üçün (T44). RPC çağırılmır, bazaya heç nə yazılmır, RSVP forması işləyir amma göndərmir.

- Məlumat `get_invite` cavabı formasındadır (`{ ok, event, guest, tablemates }`) + `media`, `tier`, `brand`.
- Ötürmə yolları: (a) səhifə yüklənmədən əvvəl `window.__INVITE_DATA__`; (b) `window.postMessage({ type: 'invite:data', payload })` — hər mesaj səhifəni yenidən doldurur (rəng/mətn dəyişəndə canlı yeniləmə).
- Önizləmədə watermark `tier`-ə görə göstərilir.

## 7. Yoxlama siyahısı (T26–T29 üçün)

- [ ] `template.json` `template.schema.json`-a uyğundur; `id` qovluq adı ilə eynidir.
- [ ] `blocks`-dakı hər blok üçün səhifədə bir `data-block` konteyneri var, artıq konteyner yoxdur.
- [ ] Birbaşa yazılmış görünən mətn yoxdur.
- [ ] İlk yükləmə < 1,5 MB; xarici resurs yoxdur.
- [ ] `prefers-reduced-motion` işləyir; musiqi avtomatik başlamır.
- [ ] 4 dildə (xüsusən ru və tr uzun mətnlər) 360 px enində mətn sığır, üfüqi scroll yoxdur.
- [ ] Bütün `css_vars` dəyişənləri `style.css`-də istifadə olunur.

## 8. Açıq suallar

1. **Saat qurşağı.** `events`-də saat qurşağı yoxdur; tarix `Asia/Baku` ilə göstərilir. Xaricdə (məs. Türkiyədə) keçirilən tədbir üçün `events.time_zone` sahəsi lazım ola bilər.
