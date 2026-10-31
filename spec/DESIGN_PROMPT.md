# Design brief — "Devet" digital invitation app (12 screens)

You are a senior product designer. Design a complete, production-ready mobile app UI for **Devet** (working name), a 2026 digital invitation platform for Azerbaijani weddings and family celebrations. Deliver polished, high-fidelity screens that an engineer can implement natively on **iOS (SwiftUI)** and **Android (Jetpack Compose)** without guessing.

---

## 1. Product context (read first)

- **Who uses the app:** a family organizing a wedding (toy), engagement (nişan), henna night (xınayaxdı), birthday (ad günü) or jubilee (yubiley) in Baku, Azerbaijan. Typical users are the bride, groom or their mothers/sisters, age 22–55, mostly on mid-range Android phones, some on iPhone.
- **What the app does:** the family creates an event, picks an animated HTML invitation template, customizes it, adds 100–300 guests (manually, from phone contacts or from Excel), and sends each guest a **personal invitation with the guest's name** via WhatsApp — one tap per guest. Guests open the link in a browser and reply "coming / not coming + how many people". The family sees who is coming in the app.
- **Two families can manage one event** (groom's side and bride's side).
- **Monetization:** free templates (up to 100 guests) and premium templates (one-time purchase per event, 300 guests, from 19.99 AZN) via in-app purchase.
- **Emotional goal:** the app must feel like a premium wedding stationery brand — elegant, warm, calm and trustworthy — while being extremely simple to operate under stress (a family managing 300 guests a few weeks before the wedding).
- **Cultural context:** respect and honorifics matter. Guests are addressed as "Elçin müəllim", "Leyla xanım", "Rəşad bəy", or "… və ailəsi" (and family). Show these forms in sample data.

## 2. Visual direction — "2026 modern wedding stationery"

Aim for the quality bar of top 2026 consumer apps (Airbnb, Revolut, Apple Invites, Paperless Post), with a distinct identity:

- **Mood:** quiet luxury, soft and airy, editorial. Not flashy, not childish, no clip-art hearts or rings.
- **Color (light mode):**
  - Background: warm ivory `#FAF7F2`; surface cards: white `#FFFFFF`.
  - Primary text: deep ink `#1F1B24`; secondary text: `#6B6470`.
  - Brand primary: deep plum / aubergine `#4A2C4F` (buttons, active states).
  - Accent: champagne gold `#C9A66B` (thin details, premium badges, progress) — use sparingly, never for body text.
  - Status: coming = sage green `#4E7D5B`; not coming = muted rose `#B5564F`; no answer = warm grey `#9A9299`; viewed = dusty blue `#5B7896`.
- **Dark mode:** design every screen in dark mode too. Background `#151217`, surfaces `#211C24`, primary `#C9A3CF`, gold stays gold. Check contrast.
- **Typography:**
  - Display / headings: an elegant serif for the brand feeling (e.g. a modern high-contrast serif).
  - UI / body: a clean geometric or grotesque sans (e.g. Inter).
  - **Hard requirement:** both fonts must contain all Azerbaijani letters **Ə ə Ğ ğ Ş ş Ç ç Ö ö Ü ü I ı İ i** and full **Cyrillic** (the app is also in Russian). Many serif fonts lack "ə" — verify glyph support and name the exact fonts you choose.
  - Type scale (sans): 34 / 28 / 22 / 17 (body) / 15 / 13 / 11. Serif only for screen titles, event names and empty-state headlines.
- **Shape and depth:** 8-pt grid, generous whitespace, corner radius 20 for cards, 14 for inputs and buttons, full pill for chips. Very soft shadows (y 4, blur 24, 6% opacity) or hairline borders `#EAE4DC` — no heavy drop shadows.
- **Iconography:** one consistent outline icon set, 1.5 px stroke, rounded joins.
- **Motion (describe in notes):** subtle 200–300 ms ease-out transitions, gentle spring on cards, a small celebratory confetti/sparkle only on success moments (event created, purchase done, all guests sent). Respect "reduce motion".
- **Imagery:** use elegant abstract textures, botanical line art or blurred venue photography as placeholders. **Do not** use photos of real, identifiable people.

## 3. Platform rules

- Design at **iPhone 15 (393×852)** as the master. Add notes where Android differs (Material 3 top app bar, back gesture, bottom sheets, system navigation bar). One visual language, platform-native behavior.
- Touch targets ≥ 44×44 pt. WCAG AA contrast minimum (4.5:1 body text).
- Support Dynamic Type / font scaling up to 130% without breaking layouts.
- **Text expansion:** Russian and Turkish labels can be 30–40% longer than Azerbaijani. Buttons and chips must allow two lines or truncate gracefully. Show at least one screen variant in Russian to prove it.
- Bottom navigation inside an event (after opening an event): **Qonaqlar · Göndər · Statistika · Daha çox**. The events list and login are outside this navigation.

## 4. Sample data (use consistently everywhere)

- Event: **"Aysel və Ramin"**, Toy, **12 iyul 2027, 18:00**, venue **"Ağ Saray şadlıq evi"**, Bakı.
- Second event in list: **"Nərminin ad günü"**, 3 avqust 2027.
- Guests: Elçin müəllim və ailəsi (4 nəfər, Masa 12, Gəlir 4), Leyla xanım (1, Masa 7, Baxdı), Rəşad bəy (2, Masa 12, Gəlmir), Günel Məmmədova (3, —, Cavab yoxdur), Tural Əliyev (2, Masa 3, Göndərilməyib), Səbinə xanım və ailəsi (5, Masa 7, Gəlir 5).
- Counter: **84 / 100** guests (free plan) and **212 / 300** (premium).
- Stats: Göndərildi 198, Baxdı 164, Gəlir 121 (387 nəfər), Gəlmir 18, Cavab yoxdur 59.

## 5. Global components to deliver (component library)

Primary button, secondary button, text button, destructive button; text input (default, focused, error, disabled); password input with show/hide; search field; filter chips (single + multi select); segmented control / tabs; event card; template card (with Pulsuz / Premium badge); guest row; status pill (Gəlir, Gəlmir, Baxdı, Cavab yoxdur, Göndərilməyib); counter badge ("84/100" with progress ring); step indicator ("2/6"); bottom sheet; dialog; toast/snackbar; empty state; skeleton loading; error banner with retry; toggle switch; color swatch picker; font picker row; image picker tile; audio picker row with play button.

Every component in light and dark mode, with all states.

## 6. Screens — specification

For **every screen** also deliver: **loading**, **empty** (where relevant), **error** (network / validation) and **success** states. Use the exact Azerbaijani copy below.

### Screen 1 — Giriş (Sign in)
- **Purpose:** returning user signs in with email and password.
- **Layout (top → bottom):** brand logo-mark and wordmark "Devet" in serif; one-line welcome "Xoş gəlmisiniz"; email field ("E-poçt"); password field ("Şifrə", show/hide eye); primary button **"Daxil ol"**; text link **"Şifrəni unutmusunuz?"**; divider; line "Hesabınız yoxdur?" + link **"Qeydiyyatdan keçin"**.
- **Also design:** Qeydiyyat (name, email, password, confirm password, terms checkbox "İstifadə şərtləri və məxfilik siyasəti ilə razıyam", button "Hesab yarat") and Şifrə bərpası (email field, "Link göndər", success state "E-poçtunuzu yoxlayın").
- **States:** wrong password error under the field ("E-poçt və ya şifrə yanlışdır"), loading spinner inside the button, offline banner.
- **Feel:** calm and premium; a soft botanical line illustration or subtle texture at the top, not a big photo.

### Screen 2 — Tədbirlər siyahısı (My events)
- **Purpose:** home screen; list of the user's events.
- **Layout:** large serif title **"Tədbirlərim"**; profile/settings icon top-right; event cards (cover image or template thumbnail, event name in serif, type chip "Toy", date and venue, mini stats row "121 gəlir · 59 cavab yoxdur", role tag "Ortaq" for co-hosted events); floating or prominent **"+" button** ("Yeni tədbir"); secondary button **"Kodla qoşul"** (join an event with an invite code from the other family).
- **Empty state:** elegant illustration, headline "İlk tədbirinizi yaradın", supporting text "Dəvətnamə hazırlamaq 10 dəqiqə çəkir", primary button "Tədbir yarat", secondary "Kodla qoşul".
- **Interaction:** tap card → opens event (Qonaqlar tab). Long-press or "…" menu → Redaktə et, Arxivlə, Sil (owner only, with confirm dialog).

### Screen 3 — Tədbir yaratma (Create event, 6-step wizard)
- **Purpose:** create an event in small, calm steps.
- **Global layout:** top bar with back arrow and close "×"; **step indicator "1/6"** with a thin gold progress bar; one question per step with a serif headline; bottom-anchored **"İrəli"** (primary) and **"Geri"** (secondary/text). "İrəli" disabled until the step is valid.
- **Steps:**
  1. "Hansı tədbirdir?" — 5 large selectable cards with icons: Toy, Nişan, Xınayaxdı, Ad günü, Yubiley.
  2. "Kimin tədbiridir?" — field "Adlar" (placeholder "Aysel və Ramin"), optional "Valideynlərin adları" (helper: "Dəvət mətnində göstərilir").
  3. "Nə vaxt?" — date picker and time picker (native style).
  4. "Harada?" — venue name, address (optional), "Xəritədə seç" button opening a map sheet, or "Xəritə linkini yapışdır".
  5. "Dəvətnamənin dili" — 4 options with native names: Azərbaycan, Русский, English, Türkçe; helper "Hər qonaq üçün sonradan ayrıca dil seçə bilərsiniz".
  6. "Masadakılar göstərilsin?" — toggle with explanation and a mini preview of the guest page table block ("Masanız: 12 · Masada: Rəşad bəy, Leyla xanım"); default off.
- **Final:** success screen "Tədbir yaradıldı" with subtle sparkle and button "Şablon seç".

### Screen 4 — Şablon kataloqu (Template catalog)
- **Purpose:** choose an invitation design.
- **Layout:** title "Şablon seçin"; filter chips "Hamısı · Pulsuz · Premium"; 2-column grid of tall template cards (phone-shaped preview thumbnails, slight parallax hint), template name, badge **"Pulsuz"** (neutral) or **"Premium"** (gold), line "100 qonağa qədər" / "300 qonaq"; premium cards show price "19,99 ₼". Current selection shows a checkmark.
- **Interaction:** tap card → full-screen preview sheet with the animated template, buttons "Bu şablonu seç" and (for premium, not yet bought) "Önizlə — almadan əvvəl fərdiləşdirə bilərsiniz".

### Screen 5 — Fərdiləşdirmə (Customize)
- **Purpose:** personalize the chosen template with a live preview.
- **Layout:** **top ~55%: live preview** of the invitation (phone frame or edge-to-edge web view) with a toggle "Qonaq kimi bax" and a language switcher (AZ/RU/EN/TR); **bottom: a draggable bottom sheet** with sections as tabs or accordion: **Rəng** (5–6 curated palettes + custom swatch), **Şrift** (3–4 font pairings shown as "Aa" samples), **Mətn** (title, invitation sentence, footer note; character counters), **Şəkil** (up to 6 photos, reorder by drag, crop), **Musiqi** (choose from library with play buttons, or upload; note "Musiqi qonaq toxunanda başlayır").
- **Top bar:** back, title "Fərdiləşdir", button **"Yadda saxla"**.
- **Premium not purchased:** small gold banner "Premium şablon — göndərmək üçün alın" with button "Al".

### Screen 6 — Qonaqlar siyahısı (Guest list) — main working screen
- **Purpose:** manage up to 300 guests quickly.
- **Layout:** top bar with event name; **counter badge "84/100"** with a progress ring (turns gold near the limit; at 100% shows "Limit doldu — artırın"); search field "Qonaq axtar"; horizontally scrollable filter chips: **Hamısı, Bəy tərəfi, Gəlin tərəfi, Gəlir, Gəlmir, Cavab yoxdur, Göndərilməyib, Masasız**; guest rows; primary floating button **"Qonaq əlavə et"**.
- **Guest row:** honorific name ("Elçin müəllim və ailəsi"), secondary line "4 nəfər · Masa 12 · Bəy tərəfi", trailing **status pill** (Gəlir 4 / Gəlmir / Baxdı / Cavab yoxdur / Göndərilməyib). Swipe actions: Redaktə, Sil.
- **Multi-select mode:** long-press → checkboxes, bottom action bar "Masa təyin et · Tərəf · Sil".
- **Guest edit sheet:** honorific segmented control (Müəllim / Xanım / Bəy / Yox), name, "Ailəliklə" toggle, invited count stepper, phone, side, table, language.
- **Empty state:** "Hələ qonaq yoxdur" + three quick buttons: "Əl ilə", "Kontaktlardan", "Excel-dən".

### Screen 7 — Qonaq əlavə etmə (Add guests)
- **Layout:** title "Qonaq əlavə et"; **3 tabs: Əl ilə · Kontaktlar · Excel**.
- **Əl ilə:** compact form (honorific, name, phone with +994 prefix, count, side, table) and buttons "Yadda saxla" and "Yadda saxla və növbəti".
- **Kontaktlar:** explain + button "Kontaktları seç" (opens native picker); after selection show list with honorific quick-set and count per row; button "23 qonaq əlavə et".
- **Excel:** upload card ("Excel faylı seçin (.xlsx)"), link "Nümunə faylı yüklə"; then **column mapping screen**: detected columns on the left ("A: Ad Soyad", "B: Tel"…) mapped via dropdowns to fields on the right (Ad, Telefon, Hitab, Nəfər, Tərəf, Masa, Dil); preview of first 5 rows; **validation summary**: "248 sətir hazırdır · 6 sətirdə xəta" with expandable error list ("Sətir 14: telefon nömrəsi yanlışdır"); duplicates warning; button "248 qonağı idxal et".
- **Limit reached state:** sheet "Limit doldu: 100/100" with options "Premium şablona keç" and "Limiti artır".

### Screen 8 — Göndərmə (Send)
- **Purpose:** send personal WhatsApp invitations one by one, fast and without mistakes.
- **Step A — Name check (mandatory):** title "Adları yoxlayın"; list of all guests as they will appear ("Hörmətli Elçin müəllim və ailəsi"); each row shows the personal preview image thumbnail; warning chips for suspicious items (missing phone, empty name); button "Hamısı düzgündür — başla".
- **Step B — Sending flow:** progress "45 / 212 göndərildi"; a **large guest card** in the center: avatar initials, honorific name, phone, language tag, the personal WhatsApp preview (image + title) exactly as the guest will see it, the message text; big primary button **"WhatsApp-da göndər"** (WhatsApp-green icon inside the brand button, not a full green brand clone); after returning from WhatsApp a sheet/inline prompt **"Göndərildi?"** with "Bəli, növbəti" and "Xeyr, yenidən"; small text button "Keç".
- **Warning:** soft banner after 120 sends today: "Bu gün çox mesaj göndərdiniz. Nömrənizin məhdudlaşdırılmaması üçün qalanını sabah davam etdirin."
- **Completion:** celebratory state "Bütün dəvətlər göndərildi".

### Screen 9 — Statistika (Statistics)
- **Layout:** title "Statistika"; **5 key numbers** as cards in a grid: Göndərildi, Baxdı, Gəlir (with total people "387 nəfər" emphasized), Gəlmir, Cavab yoxdur — each with its status color and a tap action that opens the filtered guest list; a horizontal **funnel** or stacked bar (sent → viewed → answered); **side breakdown** (Bəy tərəfi vs Gəlin tərəfi: coming people); **table breakdown** list ("Masa 12 — 8/10 nəfər təsdiqləyib"); "Son yenilənmə: 2 dəq əvvəl" and pull-to-refresh; button "Excel / PDF ixrac et".
- **Empty state:** "Hələ heç kimə göndərilməyib" + button "Göndərməyə başla".

### Screen 10 — Masalar (Tables)
- **Layout:** title "Masalar"; **toggle "Masadakıları göstər"** with helper text and a mini preview of how it looks for the guest; list of tables as cards ("Masa 12 · 4 qonaq · 10 nəfər"; expandable list of names); "Masasız qonaqlar: 37" row; primary button **"Toplu təyin et"** → flow: select guests (checkbox list with filters) → enter table number → confirm.
- No visual floor plan in this version.

### Screen 11 — Ortaq ailə (Co-host)
- **Purpose:** the second family joins and manages the same event.
- **Owner view:** explanation "Digər tərəf qonaqlarını özü əlavə edə və göndərə bilər"; **invite form**: email field + side selector (Bəy tərəfi / Gəlin tərəfi) + button "Dəvət yarat"; result card with a large **8-character code** (e.g. "K7D2 M9QX", monospaced, copy button), share button, expiry "14 gün etibarlıdır"; member list with roles ("Sahib", "Ortaq") and side.
- **Joiner view ("Kodla qoşul"):** code input with 8 segmented boxes, button "Qoşul", success "Aysel və Ramin tədbirinə qoşuldunuz".
- **Errors:** invalid or expired code, email mismatch.

### Screen 12 — Alış (Purchase)
- **Purpose:** buy a premium template or extra guest limit — trustworthy and clear.
- **Layout:** premium template hero (animated preview thumbnail) with gold "Premium" badge; **what you get** checklist ("300 qonaq", "Animasiyalı premium dizayn", "Loqo yazısı olmadan", "Bu tədbir üçün birdəfəlik"); **price "19,99 ₼"** prominent with "Birdəfəlik ödəniş, abunə deyil"; primary button **"Al"** (native store sheet opens); text link **"Alışları bərpa et"**; secondary product card "Limiti artır: +200 qonaq" with its price; small legal text and links to terms.
- **States:** processing ("Ödəniş yoxlanılır…"), success (sparkle, "Premium aktivdir"), failure ("Ödəniş alınmadı, kartınızdan pul tutulmayıb"), pending.

## 7. Deliverables

1. **Design tokens** page: colors (light/dark), type scale, spacing, radius, shadows — with names an engineer can map to code (e.g. `color.brand.primary`, `radius.card`).
2. **Component library** with all variants and states (section 5).
3. **All 12 screens** plus the sub-screens and states listed above, in **light and dark mode**, at 393×852.
4. **One Russian-language variant** of screens 3, 6 and 8 to prove text expansion.
5. **Android notes**: where Material 3 behavior differs.
6. **Clickable prototype flow:** Giriş → Tədbirlər → Tədbir yaratma (6 addım) → Şablon kataloqu → Fərdiləşdirmə → Qonaq əlavə et (Excel) → Qonaqlar → Göndərmə → Statistika.
7. A short **design rationale** (5–8 bullet points): why these colors, fonts and layouts serve a stressed family managing 300 guests.

## 8. Quality checklist (verify before finishing)

- [ ] Every Azerbaijani letter (ə, ğ, ş, ç, ö, ü, ı, İ) renders correctly in both fonts; Cyrillic too.
- [ ] Contrast AA everywhere, including gold on ivory and text on status pills.
- [ ] No screen relies on color alone — status pills have text labels.
- [ ] Primary action on each screen is obvious and reachable with the thumb.
- [ ] Empty, loading and error states exist for every data screen.
- [ ] No real people's photos, no real brand logos except a WhatsApp icon used only as a functional indicator.
- [ ] Layouts survive 130% font scale and Russian text.
