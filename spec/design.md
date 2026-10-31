# design.md — Devet dizayn sistemi

Mənbə: `spec/DESIGN_PROMPT.md` (brif). Bu fayl **mənbə həqiqətidir**: tokenlər buradan Android (Compose), iOS (SwiftUI) və veb (`design/tokens.css`) koduna köçürülür. Dəyər dəyişəndə əvvəl burada, sonra `tokens.css`-də dəyişin.

Vizual sübut: `design/prototype/` (ekranlar), `design/components.html` (komponentlər), `design/font-check.html` (şrift yoxlaması).

**Ad qaydası:** token `color.brand.primary` →
- CSS: `--color-brand-primary`
- Compose: `DevetTheme.colors.brandPrimary`
- SwiftUI: `Color.DS.brandPrimary` (Asset Catalog rəngi `brandPrimary`, Any/Dark görünüşü ilə)

---

## 1. Şriftlər

| Rol | Şrift | Çəkilər | İstifadə |
| --- | --- | --- | --- |
| Serif (brend) | **Noto Serif Display** | 500, 600 | yalnız ekran başlıqları, tədbir adları, boş halın başlığı |
| Sans (UI) | **Inter** | 400, 500, 600 | qalan hər şey |
| Mono | sistem (`SF Mono` / `Roboto Mono`) | 500 | yalnız 8 simvollu dəvət kodu |

**Hərf dəstəyi yoxlanılıb (2026-10-30)**, `design/font-check.html` ilə brauzerdə avtomatik: hər hərf iki fərqli ehtiyat şriftlə ölçülür; fərq varsa şriftdə hərf yoxdur.

| Şrift | `Ə ə Ğ ğ Ş ş Ç ç Ö ö Ü ü I ı İ i` | Kiril (33+33) | Nəticə |
| --- | --- | --- | --- |
| Noto Serif Display 600 | var | var | ✓ seçildi |
| Inter 400 / 600 | var | var | ✓ seçildi |
| Cormorant Garamond 600 | var | var | ✓ (kiçik ölçüdə çox nazik — seçilmədi) |
| Playfair Display 600 | var | var | ✓ (ağır, çox istifadə olunur — seçilmədi) |
| Lora 600 | var | var | ✓ (ehtiyat variant) |
| Manrope 400 | **`Ə` yoxdur** | var | ✗ — test metodunun işlədiyini də göstərir |

Tətbiqə şriftlər **paketlə daxil edilir** (Google Fonts-dan OFL lisenziyalı `.ttf`, `latin`, `latin-ext`, `cyrillic` alt dəstləri): Android `res/font/`, iOS `UIAppFonts`. Prototip onları Google Fonts-dan yükləyir.

## 2. Rənglər

### 2.1 Light / Dark

| Token | Light | Dark | İstifadə |
| --- | --- | --- | --- |
| `color.bg.canvas` | `#FAF7F2` | `#151217` | ekran fonu |
| `color.bg.surface` | `#FFFFFF` | `#211C24` | kartlar, sətirlər, sheet |
| `color.bg.sunken` | `#F3EEE7` | `#1A161D` | input fonu, axtarış, seçilməmiş seqment |
| `color.bg.raised` | `#FFFFFF` | `#2B2530` | dialoq, toast, açılan menyu |
| `color.bg.overlay` | `rgba(31,27,36,.40)` | `rgba(0,0,0,.60)` | modal arxası |
| `color.text.primary` | `#1F1B24` | `#F3EEF4` | əsas mətn |
| `color.text.secondary` | `#6B6470` | `#B8AFBB` | köməkçi mətn, placeholder |
| `color.text.onBrand` | `#FFFFFF` | `#1F1B24` | əsas düymə mətni |
| `color.text.link` | `#4A2C4F` | `#C9A3CF` | mətn düymələri, linklər |
| `color.border.hairline` | `#EAE4DC` | `#352E39` | kart/sətir ayırıcıları (dekorativ) |
| `color.border.control` | `#8F8790` | `#7E7581` | input, checkbox sərhədi (3:1) |
| `color.border.focus` | `#4A2C4F` | `#C9A3CF` | fokus halqası (2 px) |
| `color.brand.primary` | `#4A2C4F` | `#C9A3CF` | əsas düymə, aktiv hal |
| `color.brand.pressed` | `#3A2140` | `#B48BBA` | basılı hal |
| `color.brand.subtle` | `#EFE8F0` | `#3A2D3E` | seçilmiş chip, seçilmiş kart fonu |
| `color.accent.gold` | `#C9A66B` | `#C9A66B` | **yalnız dekor**: nazik xətlər, step progress, Premium çərçivə |
| `color.accent.goldStrong` | `#A3813A` | `#C9A66B` | qeyri-mətn göstəricilər: limitə yaxın halqa, ikon |
| `color.accent.goldText` | `#7A5C27` | `#D9BC86` | qızılı **mətn** (Premium nişanı, qiymət vurğusu) |
| `color.accent.goldSubtle` | `#F6EEDF` | `#3A3122` | Premium nişanının fonu, xəbərdarlıq zolağı |
| `color.feedback.danger` | `#A8423B` | `#EC9A93` | xəta mətni, sil düyməsi |
| `color.feedback.dangerBg` | `#F7E6E4` | `#3F2422` | xəta zolağı |
| `color.feedback.success` | `#3F6B4B` | `#8CC59A` | uğur mətni |
| `color.feedback.successBg` | `#E7F0E9` | `#22342A` | uğur zolağı |
| `color.feedback.warning` | `#7A5C27` | `#D9BC86` | xəbərdarlıq mətni |
| `color.feedback.warningBg` | `#F6EEDF` | `#3A3122` | xəbərdarlıq zolağı (120 göndərmə) |
| `color.whatsapp` | `#25D366` | `#25D366` | **yalnız** WhatsApp ikonunun özü |

### 2.2 Status (qonaq cavabı)

Hər status **həmişə mətnlə** göstərilir (pill), rəng yalnız köməkçidir. `fg` — nöqtə/ikon, `text` + `bg` — pill.

| Status | Pill mətni (az / ru) | `fg` L / D | `text` L / D | `bg` L / D |
| --- | --- | --- | --- | --- |
| `coming` | Gəlir {n} / Придёт {n} | `#4E7D5B` / `#8CC59A` | `#3F6B4B` / `#8CC59A` | `#E7F0E9` / `#22342A` |
| `declined` | Gəlmir / Не придёт | `#B5564F` / `#EC9A93` | `#9E443D` / `#EC9A93` | `#F7E6E4` / `#3F2422` |
| `viewed` | Baxdı / Просмотрено | `#5B7896` / `#A3BCD8` | `#4A6683` / `#A3BCD8` | `#E5ECF3` / `#22303D` |
| `pending` | Cavab yoxdur / Нет ответа | `#9A9299` / `#9F97A2` | `#625B66` / `#C2BAC2` | `#EFECEF` / `#2F2A31` |
| `unsent` | Göndərilməyib / Не отправлено | `#6B6470` / `#8C8390` | `#6B6470` / `#B8AFBB` | `#F3EEE7` / `#2B2530` |

Status hesablanması: `rsvp_status = yes` → coming, `no` → declined; `pending` olanda `opened_at` doludursa viewed, `sent_at` doludursa pending, yoxsa unsent.

### 2.3 Kontrast (WCAG 2.x, hesablanıb)

Bütün mətn cütləri ≥ 4.5:1, qeyri-mətn göstəricilər ≥ 3:1.

| Cüt | Light | Dark |
| --- | --- | --- |
| text.primary / canvas | 15.84 | 16.23 |
| text.secondary / canvas | 5.34 | 8.74 |
| text.secondary / surface | 5.70 | 7.87 |
| text.onBrand / brand.primary | 11.90 | 7.76 |
| brand.primary (link) / canvas | 11.14 | 8.51 |
| goldText / canvas | 5.80 | — |
| goldText / goldSubtle (Premium nişanı) | 5.38 | 6.99 |
| gold / canvas (yalnız dekor) | **2.15** — mətn üçün qadağandır | 8.09 |
| goldStrong / surface (halqa) | 3.65 | — |
| border.control / surface | 3.48 | 3.78 |
| pill coming / declined / pending / viewed / unsent | 5.28 / 5.20 / 5.59 / 5.01 / 4.94 | 6.64 / 6.46 / 7.42 / 6.89 / 7.01 |
| feedback.danger / surface | 5.99 | 7.65 |

## 3. Tipoqrafiya

| Token | Şrift | Ölçü / sətir (pt) | Çəki | İstifadə |
| --- | --- | --- | --- | --- |
| `type.serif.display` | serif | 34 / 40 | 500 | "Tədbirlərim", giriş brendi |
| `type.serif.title` | serif | 28 / 34 | 500 | ekran başlığı, tədbir adı (kartda) |
| `type.serif.headline` | serif | 22 / 28 | 600 | sihirbaz sualı, boş halın başlığı |
| `type.sans.title1` | sans | 28 / 34 | 600 | böyük rəqəmlər (statistika) |
| `type.sans.title2` | sans | 22 / 28 | 600 | bölmə başlığı, sayğac |
| `type.sans.headline` | sans | 17 / 24 | 600 | düymə, sətir başlığı (qonaq adı) |
| `type.sans.body` | sans | 17 / 24 | 400 | əsas mətn, input |
| `type.sans.callout` | sans | 15 / 20 | 400 | köməkçi mətn, chip |
| `type.sans.footnote` | sans | 13 / 18 | 400 | ikinci sətir ("4 nəfər · Masa 12") |
| `type.sans.caption` | sans | 11 / 14 | 500, +2% hərf aralığı | nişan, tab etiketi |

- **Dinamik şrift:** ölçülər iOS Dynamic Type / Android `sp` ilə miqyaslanır; 130%-də sətirlər qırılır, kəsilmir. Düymə və chip mətni 2 sətrə qədər keçə bilər; daha uzunda `…` ilə kəsilir.
- Rəqəmlər üçün `font-variant-numeric: tabular-nums` (sayğaclar, statistika).

## 4. Boşluq, ölçü, forma

| Token | Dəyər | | Token | Dəyər |
| --- | --- | --- | --- | --- |
| `space.0_5` | 4 | | `radius.sm` | 8 (kiçik nişan, thumbnail) |
| `space.1` | 8 | | `radius.control` | 14 (input, düymə) |
| `space.1_5` | 12 | | `radius.card` | 20 |
| `space.2` | 16 | | `radius.sheet` | 28 (bottom sheet üst küncləri) |
| `space.3` | 24 | | `radius.pill` | tam (chip, status pill) |
| `space.4` | 32 | | `size.touchMin` | 44 |
| `space.5` | 40 | | `size.controlHeight` | 52 (düymə, input) |
| `space.6` | 48 | | `size.chipHeight` | 36 (toxunma sahəsi 44) |
| `space.8` | 64 | | `size.icon` | 24, xətt 1.5 |
| `layout.gutter` | 24 (ekran kənarı) | | | |

**Kölgə:** `shadow.card` = y 4, blur 24, `#1F1B24` 6% (dark: qara 35%); `shadow.raised` = y 8, blur 32, 10% (sheet, FAB, toast). Kölgə yerinə `border.hairline` da istifadə oluna bilər — eyni ekranda ikisi birlikdə yox.

## 5. Hərəkət

| Token | Dəyər | İstifadə |
| --- | --- | --- |
| `motion.duration.fast` | 200 ms | düymə basılması, chip seçimi |
| `motion.duration.base` | 250 ms | ekran keçidi, sheet açılması |
| `motion.duration.slow` | 300 ms | kart yerləşməsi, irəliləmə |
| `motion.easing.standard` | `cubic-bezier(0.2, 0.8, 0.2, 1)` (ease-out) | hamısı |
| kart yayı | iOS `spring(response: 0.35, dampingFraction: 0.8)`; Compose `spring(dampingRatio = 0.8f, stiffness = 400f)` | göndərmə kartının dəyişməsi |
| konfetti/parıltı | ≤ 1.2 s, bir dəfə | yalnız: tədbir yaradıldı, alış uğurlu, hamısı göndərildi |

**Azaldılmış hərəkət** (iOS Reduce Motion / Android "Remove animations"): bütün müddətlər 0, konfetti əvəzinə statik ikon, kart sürüşməsi əvəzinə yalnız şəffaflıq.

## 6. İkonlar

Bir dəst, xətti (outline), 24×24, xətt 1.5, yuvarlaq birləşmə və uclar. Prototipdə əl ilə çəkilmiş SVG-lər (`design/prototype/proto.js → ICONS`); tətbiqdə eyni formaların vektor resursu (Android `VectorDrawable`, iOS SF Symbols-a yaxın xüsusi simvollar və ya PDF). **WhatsApp loqosu yalnız göndərmə düyməsində, funksional göstərici kimi**, öz rəngində (`color.whatsapp`), düymənin özü brend rəngindədir.

## 7. Platforma qeydləri (Android ↔ iOS)

| Mövzu | iOS (master, 393×852) | Android (Material 3) |
| --- | --- | --- |
| Üst panel | böyük serif başlıq, sürüşəndə kiçilir | `LargeTopAppBar` → `TopAppBar`, eyni serif başlıq |
| Geri | sol üstdə `‹`, kənardan sürüşdürmə | sistem geri jesti/düyməsi; üst paneldə `←` |
| Alt naviqasiya (tədbir daxilində) | Tab bar: Qonaqlar · Göndər · Statistika · Daha çox | `NavigationBar`, eyni 4 bölmə |
| Bottom sheet | `.sheet` + `presentationDetents` | `ModalBottomSheet`, sürükləmə tutacağı ilə |
| Dialoq | `alert` | `AlertDialog` (M3), düymələr sağda |
| Toast | yuxarıdan banner | `Snackbar` aşağıda, alt naviqasiyanın üstündə |
| FAB | sağ altda yuvarlaq düymə (tab barın üstündə) | `ExtendedFloatingActionButton` |
| Sistem panelləri | status bar + home indicator (34 pt) | edge-to-edge, `WindowInsets` ilə; naviqasiya paneli şəffaf |
| Tarix/saat seçici | `DatePicker` (wheel/compact) | M3 `DatePickerDialog`, `TimePicker` |
| Toxunma rəyi | yüngül haptik (seçim, uğur) | `HapticFeedbackType` eyni anlarda |

## 8. Dizayn əsaslandırması

1. **Fil sümüyü fon + dərin bənövşəyi:** toy dəftərxanasının sakit, bahalı hissi; bənövşəyi qızılla birlikdə təntənəli, amma qadınlar və kişilər üçün neytraldır. 300 qonaqla stress altında olan ailə üçün sakit fon yorğunluğu azaldır.
2. **Qızılı yalnız dekorda:** fil sümüyü üzərində 2.15:1 kontrastı var — mətn üçün yararsızdır. Premium və irəliləyiş hissini verir, amma oxunaqlılığa toxunmur; mətn üçün ayrıca tünd `goldText`.
3. **Serif yalnız başlıqlarda:** brend hissi başlıqlardan gəlir, işçi ekranlar (qonaq siyahısı, formlar) oxunaqlı Inter ilə — 300 sətri sürətlə taramaq üçün.
4. **Statuslar həm rəng, həm mətn:** "Gəlir 4", "Gəlmir" — rəng korluğu və günəş altında ekran üçün; rənglər bir-birindən parlaqlıqla da fərqlənir.
5. **Bir ekranda bir əsas hərəkət,** baş barmağın çatdığı aşağı zonada (52 pt düymə, FAB): "Qonaq əlavə et", "WhatsApp-da göndər", "İrəli".
6. **Göndərmə axını bir qonaq = bir kart:** səhv qonağa göndərmə riskini azaldır; adlar əvvəlcə məcburi siyahıda yoxlanılır.
7. **Ad + hitab hər yerdə tam yazılır** ("Elçin müəllim və ailəsi") — mədəni hörmət və səhvi erkən görmək üçün; uzun rus mətni (`Elçin муаллим с семьёй`) iki sətrə keçir.
8. **Yumşaq kölgə və 20 pt künclər:** "kağız kart" hissi, ağır kölgə olmadan — orta səviyyəli Android telefonlarda da təmiz görünür.

## 9. Keyfiyyət yoxlaması (DESIGN_PROMPT.md §8) — 2026-10-31

| Bənd | Nəticə | Necə yoxlanılıb |
| --- | --- | --- |
| Azərbaycan hərfləri (ə, ğ, ş, ç, ö, ü, ı, İ) və kiril hər iki şriftdə | ✓ | `design/font-check.html`: hər hərf iki ehtiyat şriftlə ölçülür; test Manrope-da `Ə` yoxluğunu tutur (metod işləyir) |
| AA kontrast, o cümlədən qızılı və status pill-ləri | ✓ | §2.3 cədvəli (hesablanıb); bütün 106 halda light rejimdə dekorativ qızılı (`#C9A66B`) rəngli mətn elementi tapılmadı |
| Heç bir ekran yalnız rəngə güvənmir | ✓ | status pill-lərdə mətn; statistika kartları, huni və tərəf bölgüsündə etiket/legend |
| Əsas hərəkət aydındır və baş barmaqla çatılır | ✓ | əsas düymə aşağıda (`bottom-actions`, FAB, göndərmə düyməsi tab barın üstündə) |
| Hər data ekranında boş, yüklənmə, xəta halları | ✓ | 2, 4, 5, 6, 7, 8, 9, 10 — hər birində ayrıca hal; 3 və 12-də "yaradılır/yoxlanılır" + xəta; 11-də 3 xəta halı |
| Real insan şəkli yoxdur; brend loqosu yalnız WhatsApp funksional ikonu | ✓ | abstrakt tekstura və botanik xətt rəsmləri; WhatsApp işarəsi yalnız göndərmə düyməsinin içində |
| 130% şrift və rus mətni | ✓ | 13 ekranın 106 halı `dark + RU + 130%` rejimində avtomatik render; üfüqi daşma yoxdur (3 hal düzəldildi: ekran 7 forması, ekran 11 düymələri) |

**Prototip:** 13 ekran (12 + "Daha çox" menyusu), 106 hal, light/dark, AZ/RU, 100%/130%. Rus variantı (3, 6, 8 daxil) hər ekranda dil keçidi ilə. Komponentlər: `design/components.html` (8 bölmə, light və dark yan-yana).

**Qeydlər:** limit artırmanın qiyməti (9,99 ₼) prototipdə nümunədir — PRODUCT.md-də hələ seçilməyib. 4-cü addımda xəritə seçicisi yoxdur (qərar §15.3 screens.md).
