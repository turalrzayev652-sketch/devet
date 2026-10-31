# TASKS.md — Ardıcıl iş siyahısı

**Necə istifadə etmək:** Claude Code-a hər sessiyada belə yazın:

> `TASKS.md`-dəki növbəti tamamlanmamış tapşırığı CLAUDE.md qaydalarına uyğun icra et.

Agent bir tapşırığı bitirir, hesabat verir və dayanır. Siz yoxlayırsınız, sonra növbəti sessiyaya keçirsiniz.

- `[SİZ]` işarəli tapşırıqlar sizindir; agent onları keçir.
- Hər tapşırıqda **Asılılıq** (əvvəl bitməli olanlar) və **Hazırdır, əgər** (qəbul meyarları) var.
- Saatlar təxminidir və sizin vaxtınızdır (tapşırıq vermə, yoxlama, telefonda sınaq).

---

## Faza 0 — Hazırlıq

- [ ] **T00 [SİZ] Hesablar və yoxlamalar** (~7 saat)
  - Bankın kənar fəaliyyət qaydalarını yoxlayın.
  - Google Play Developer ($25) və Apple Developer ($99) hesabları; hər ikisində Azərbaycandan ödəniş (merchant / Paid Apps) profilinin açıla bildiyini yoxlayın.
  - Supabase, Cloudflare və GitHub hesabları.
  - Fərdi sahibkar (VÖEN) qeydiyyatı; rəqəmsal satışın vergi rejimini mühasiblə dəqiqləşdirin.
  - Xcode quraşdırılmış Mac kompüter (iOS üçün mütləqdir).

- [x] **T01 Layihə skeleti** (~1 saat)
  - Asılılıq: —
  - Qovluqlar: `/spec`, `/backend`, `/web`, `/android`, `/ios`, `/tools`. Hər birində qısa `README.md`.
  - Kök `.gitignore` (Android, Xcode, Node, `.env`), `.env.example` (SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY, PUBLIC_BASE_URL).
  - `/spec/PRODUCT.md` artıq mövcuddur — onu dəyişmə. `/spec` içində əlavə boş şablon fayllar yarat: `screens.md`, `api.md`, `templates.md`, `design.md`, `i18n/app.json`, `i18n/invite.json`, `test-vectors/`.
  - Hazırdır, əgər: struktur yaradılıb, git-də ilk commit var, heç bir sirr commit olunmayıb.

- [x] **T02 [SİZ] Ekran eskizləri** (~5 saat)
  - Əvəz olundu (sahibin qərarı, 2026-10-31): `spec/DESIGN_PROMPT.md` brifi əsasında HTML prototip — `design/prototype/` (13 ekran, 106 hal), `design/components.html`.
  - 12 əsas ekranın kağız və ya Figma eskizi: giriş, tədbirlər siyahısı, tədbir yaratma (addımlar), şablon kataloqu, şablon fərdiləşdirmə, qonaqlar siyahısı, qonaq əlavə etmə (əl/kontakt/Excel), göndərmə axını, statistika, masalar, ortaq ailə, alış ekranı.
  - Şəkilləri `/spec/sketches/` qovluğuna qoyun.

---

## Faza 1 — Backend (Supabase)

- [x] **T10 Supabase layihəsi və əsas sxem**
  - ⚠️ Qeyd: PGlite ilə yoxlanıb; `supabase db reset` Docker quraşdırılanda hələ də yoxlanmalıdır.
  - Asılılıq: T01
  - `supabase init` (`/backend/supabase`). Miqrasiya `001_schema.sql`:
    - enum-lar: `event_type` (wedding, engagement, henna, birthday, jubilee), `member_role` (owner, cohost), `side` (groom, bride, none), `rsvp_status` (pending, yes, no), `salutation` (muellim, xanim, bey, none), `purchase_kind` (template, limit_addon), `store` (google, apple), `lang` (az, ru, en, tr).
    - cədvəllər: `profiles`, `events`, `event_members`, `event_invites`, `templates`, `purchases`, `guests`, `app_config` — sahələr `/spec/PRODUCT.md` bölmə 5-ə tam uyğun.
    - `guests.code`: 8 simvol, unikal, təxmin edilməz (base32, crypto random) — default funksiya ilə.
    - `guests.phone_e164`: E.164 formatı üçün CHECK.
    - `events.guest_limit`: hesablanan sahə (və ya funksiya) — şablon limiti + `limit_addon` alışları.
    - lazımi indekslər (`guests.event_id`, `guests.code`).
  - `seed.sql`: 1 demo istifadəçi, 1 tədbir, 10 qonaq, 2 pulsuz şablon qeydi.
  - Hazırdır, əgər: `supabase db reset` səhvsiz işləyir, seed məlumatı görünür.

- [x] **T11 RLS qaydaları**
  - ⚠️ Qeyd: 53 RLS yoxlaması PGlite ilə keçib; rəsmi `supabase test db` testləri T18-də yazılacaq.
  - Asılılıq: T10
  - Bütün cədvəllərdə RLS aktivdir.
  - `profiles`: istifadəçi yalnız özünü görür və dəyişir.
  - `events`, `guests`: yalnız `event_members`-də olan istifadəçilər oxuyur/yazır; `owner` silə bilər, `cohost` silə bilməz.
  - `templates`: hamı oxuyur, heç kim yazmır (yalnız service role).
  - `purchases`: istifadəçi yalnız öz alışlarını oxuyur; yazmaq yalnız service role.
  - Hazırdır, əgər: T18-dəki testlər keçir. Hesabatda "İnsan yoxlaması lazımdır" bölməsi var.

- [x] **T12 Qonaq funksiyaları (RPC)**
  - ⚠️ Qeyd: `backend/supabase/tests/sql/guest_rpc.sql` PGlite ilə keçib; real Supabase-də hələ işlədilməyib.
  - Asılılıq: T11
  - `get_preview(code)` — **yan təsirsiz**: qonağın göstəriləcək adı (hitab ilə), tədbir başlığı, tarix, dil, önizləmə şəklinin yolu. WhatsApp-ın link yoxlayıcısı bunu çağırır, ona görə "baxdı" yazmır.
  - `get_invite(code)` — tədbirin ictimai sahələri, şablon, fərdiləşdirmə, qonaq məlumatı (ad, hitab, dəvət olunan nəfər, masa, cavab), `show_tablemates` açıqdırsa eyni masadakı qonaqların adları. İlk çağırışda `opened_at` yazır.
  - `submit_rsvp(code, status, count)` — `count` ≤ dəvət olunan nəfər; `no` olanda count = 0; `rsvp_at` yazır.
  - Hamısı `security definer`, `anon` üçün icazəli, yalnız bu funksiyalar.
  - Mövcud olmayan və ya keçmiş tədbirin kodu üçün aydın xəta kodu qaytarır.
  - Hazırdır, əgər: SQL testləri hər üç funksiyanı, o cümlədən səhv kod və limitdən çox nəfər hallarını yoxlayır.

- [x] **T13 Qonaq limiti**
  - ⚠️ Qeyd: `backend/supabase/tests/sql/guest_limit.sql` PGlite ilə keçib; real Supabase-də hələ işlədilməyib.
  - Asılılıq: T12
  - Trigger: tədbirdə qonaq sayı `guest_limit`-i keçə bilməz (insert və toplu import üçün).
  - Pulsuz şablon → 100, pullu → 300, hər `limit_addon` alışı → +200 (rəqəm konfiqurasiya cədvəlində saxlanır, koda yazılmır).
  - Hazırdır, əgər: limitdən artıq insert rədd olunur və test bunu göstərir.

- [x] **T14 Ortaq ailə dəvəti**
  - ⚠️ Qeyd: `backend/supabase/tests/sql/cohost_invite.sql` PGlite ilə keçib; real Supabase-də hələ işlədilməyib.
  - Asılılıq: T11
  - `event_invites` (event_id, email, side, token, accepted_at). RPC `create_cohost_invite(event_id, email, side)` (yalnız owner) və `accept_cohost_invite(token)` (girişli istifadəçi; e-poçt uyğun gəlməlidir).
  - Hazırdır, əgər: testdə ikinci istifadəçi dəvəti qəbul etdikdən sonra tədbiri görür, başqa tədbiri görmür.

- [x] **T15 Storage**
  - ⚠️ Qeyd: `backend/supabase/tests/sql/storage.sql` PGlite-də (storage sxemi imitasiyası ilə) keçib; real Storage API ilə yüklənmə hələ sınanmayıb.
  - Asılılıq: T11
  - Bucket-lər: `event-media` (şəkil, musiqi; yalnız tədbir üzvləri yazır, ictimai oxuma imzalı URL ilə), `previews` (adlı önizləmə şəkilləri; ictimai oxuma, yazma yalnız tədbir üzvləri; fayl adı = qonaq kodu).
  - Fayl ölçüsü limitləri: şəkil ≤ 2 MB, musiqi ≤ 5 MB, önizləmə ≤ 150 KB.
  - Hazırdır, əgər: icazə testləri keçir.

- [x] **T16 Məlumatların saxlanma müddəti**
  - ⚠️ Qeyd: `backend/supabase/tests/sql/phone_retention.sql` PGlite-də (pg_cron imitasiyası ilə) keçib; real pg_cron işi hələ yoxlanmayıb.
  - Asılılıq: T10
  - `pg_cron` işi: tədbir tarixindən 90 gün sonra qonaqların telefon nömrələri silinir (adlar və statistika qalır).
  - Hazırdır, əgər: test tarixi keçmiş tədbirdə telefonların silindiyini göstərir.

- [x] **T17 Hesabın silinməsi** (sahibin qərarı 2026-10-30; App Store və Google Play tələbi)
  - ⚠️ Qeyd: SQL (pgTAP 14) və Edge Function (TS 6) testləri PGlite/imitasiya ilə keçib; real Supabase-də hələ işlədilməyib. Tətbiq UI-si — T42 (Parametrlər).
  - Asılılıq: T11, T15
  - `delete-account` Edge Function: owner olduğu tədbirlərin faylları (event-media, previews) Storage API ilə silinir, sonra tədbirlər silinir, cohost üzvlükləri çıxarılır, sonra Auth istifadəçisi silinir. Cohost kimi edilən alışlar tədbirdə qalır.
  - Hazırdır, əgər: testlər silinmə sırasını, başqasının tədbirinin qalmasını və Storage xətasında heç nəyin silinmədiyini göstərir.

- [x] **T18 Təhlükəsizlik testləri**
  - ⚠️ Qeyd: 6 pgTAP faylı (42 test) PGlite-də pgTAP imitasiyası ilə keçib; `supabase test db` Docker qurulanda işlədilməlidir.
  - Asılılıq: T11–T15
  - `/backend/supabase/tests/` — pgTAP və ya SQL skriptləri: A istifadəçisi B-nin tədbirini, qonaqlarını, alışlarını görə və dəyişə bilmir; anon yalnız RPC çağıra bilir; cohost silə bilmir.
  - Hazırdır, əgər: `supabase test db` tam keçir.

---

## Faza 2 — Qonaq səhifəsi və şablonlar (Cloudflare Pages)

- [x] **T20 Web layihəsi**
  - Asılılıq: T12
  - `/web`: `public/core/`, `public/templates/<template_id>/`, `functions/i/[code].js`, `wrangler.toml`. Lokal işə salma: `npx wrangler pages dev`.
  - Mühit dəyişənləri: SUPABASE_URL, SUPABASE_ANON_KEY, PUBLIC_BASE_URL.
  - Hazırdır, əgər: lokal server açılır, `/i/test` səhifəsi 404 əvəzinə "kod tapılmadı" ekranını göstərir.

- [x] **T21 Qonaq səhifəsinin lüğəti**
  - Asılılıq: T01
  - `/spec/i18n/invite.json` — 4 dildə bütün sabit mətnlər (dəvət cümlələri, "Gəlirəm", "Gəlmirəm", "Neçə nəfər?", "Masanız", "Yol", geri sayım vahidləri, xəta mesajları).
  - Hitab qaydaları hər dil üçün: müəllim/xanım/bəy/yox + "ailəliklə" (məs. az: "Elçin müəllim və ailəsi", ru, en, tr formaları).
  - Hazırdır, əgər: JSON sxemə uyğundur və hər açar 4 dildə var (yoxlama skripti).

- [x] **T22 Şablon müqaviləsi**
  - Asılılıq: T21
  - `/spec/templates.md`: `template.json` sxemi (id, ad, versiya, pulsuz/pullu, limit, CSS dəyişənləri, dəstəklənən bloklar), `data-bind` açarlarının siyahısı, blok konteynerləri (`rsvp`, `map`, `countdown`, `music`, `gallery`, `table`, `watermark`).
  - Hazırdır, əgər: sənəd hazırdır və T23-də istifadə olunur.

- [x] **T23 invite-core.js**
  - ⚠️ Qeyd: E2E real SQL funksiyaları ilə PGlite-də (Supabase RPC imitasiyası) və real brauzerdə yoxlanıb; real Supabase ilə hələ sınanmayıb. Media (qalereya/musiqi) T24-dən sonra görünəcək.
  - Asılılıq: T20, T21, T22
  - `get_invite` çağırır, dili seçir (qonağın dili → tədbirin dili), hitabı formatlayır, `data-bind` sahələrini doldurur.
  - Bloklar: cavab forması (`submit_rsvp`), xəritə (Google Maps və Waze linkləri), geri sayım, musiqi (yalnız toxunuşla başlayır), qalereya, masa bloku (masadakılar açıqdırsa), pulsuz şablonda watermark.
  - **Önizləmə rejimi:** `?preview=1` ilə RPC çağırmadan, tətbiqin WebView-dan ötürdüyü JSON ilə işləyir (`window.__INVITE_DATA__` və ya `postMessage`).
  - Xəta ekranları: kod tapılmadı, tədbir keçib, şəbəkə xətası.
  - Hazırdır, əgər: seed tədbirinin 3 qonaq kodu ilə səhifə 4 dildə düzgün açılır və cavab bazaya düşür.

- [x] **T24 Adlı WhatsApp önizləməsi (Pages Function)**
  - ⚠️ Qeyd: `curl -A "WhatsApp/2.0"` real `wrangler pages dev`-də (PGlite RPC ilə) adlı og-teqləri göstərir. Real WhatsApp-da önizləmə ictimai deploy və real Supabase tələb edir — T2B-də yoxlanmalıdır.
  - Asılılıq: T23, T15
  - `functions/i/[code].js`: `get_preview` çağırır, şablonun `index.html`-ini `env.ASSETS` ilə götürür, `<head>`-ə `og:title` ("Elçin müəllim, sizi toyumuza dəvət edirik"), `og:description`, `og:image` (previews/<kod>.jpg, yoxdursa tədbirin ümumi şəkli), `og:url` əlavə edir və konfiqurasiya skriptini yerləşdirir.
  - Keşləmə: qısa müddətli (məs. 5 dəq), çünki ad dəyişə bilər.
  - **Qərar (2026-10-29):** `event-media` qapalı bucket-dir. Qonaq səhifəsi üçün şəkil/musiqi imzalı linklərini bu Pages Function `SUPABASE_SERVICE_ROLE_KEY` ilə (yalnız Cloudflare mühit dəyişənində) yaradır və `customization` yollarını linklərlə əvəz edir. Açar heç vaxt `web/public`-ə düşmür.
  - Hazırdır, əgər: `curl -A "WhatsApp/2.0" https://.../i/<kod>` cavabında adlı og-teqlər var; real WhatsApp-da önizləmə adla görünür.

- [ ] **T25 [SİZ] Şablon dizaynları**
  - 2 pulsuz və 2 pullu (premium, animasiyalı) şablonun dizaynı: rənglər, şriftlər, kompozisiya, animasiya ideyası. Faylları `/spec/designs/` qovluğuna qoyun.

- [ ] **T26 Pulsuz şablon 1**
  - Asılılıq: T23, T25
  - `public/templates/free-01/`: `index.html`, `style.css`, `motion.js`, `template.json`. CSS dəyişənləri ilə rəng/şrift. Bütün bloklar.
  - Hazırdır, əgər: ilk yükləmə < 1,5 MB, `prefers-reduced-motion` işləyir, 4 dildə mətn sığır (rus və türk mətnləri daha uzundur).

- [ ] **T27 Pulsuz şablon 2** — T26 ilə eyni meyarlar.
- [ ] **T28 Premium şablon 1** — T26 meyarları + premium animasiyalar; zəif Android telefonda axıcılıq yoxlanır.
- [ ] **T29 Premium şablon 2** — T28 ilə eyni meyarlar.

- [ ] **T2A Performans və önizləmə testləri**
  - Asılılıq: T26–T29
  - Skript: hər şablon üçün Lighthouse (mobil) və ölçü yoxlaması; og-teqlərin olması.
  - Hazırdır, əgər: bütün şablonlar büdcəyə sığır; hesabatda nəticələr cədvəli var.

- [ ] **T2B [SİZ] Real sınaq**
  - Supabase panelindən bir tədbir və 10 qonaq yaradın, linkləri öz WhatsApp-ınızdan tanışlara göndərin, önizləməni və cavabı yoxlayın.

---

## Faza 3 — Tətbiq spesifikasiyası

- [ ] **T30 Ekran axınları**
  - Asılılıq: T02
  - Agent `/spec/sketches/` və bu plana əsasən `/spec/screens.md` qaralamasını yazır: hər ekran üçün məzmun, düymələr, keçidlər, boş və xəta halları, validasiya. **[SİZ] sonra redaktə edib təsdiqləyirsiniz.**
  - Vəziyyət: sizin istəyinizlə eskizsiz qaralama yazılıb (12 ekran + naviqasiya, rol cədvəli, xəta kodları backend ilə yoxlanıb). **Qalıb:** T02 eskizlərinə uyğunlaşdırma, §15-dəki 9 açıq sual və sizin təsdiqiniz.
  - Hazırdır, əgər: 12 ekranın hamısı təsvir olunub və siz təsdiqləmisiniz.

- [ ] **T31 API müqaviləsi**
  - Asılılıq: T30, T18
  - `/spec/api.md`: hər ekranın hansı cədvəl/RPC/Storage çağırışını etdiyi, sorğu və cavab formaları, xəta kodları.

- [x] **T32 i18n generatoru**
  - Asılılıq: T01
  - `/spec/i18n/app.json` (açar → az/ru/en/tr) və `/tools/i18n` skripti: Android `values*/strings.xml` və iOS `Localizable.xcstrings` yaradır. Çatışmayan tərcümədə skript xəta verir.
  - Hazırdır, əgər: nümunə açarlarla hər iki platforma faylı yaranır.

- [x] **T33 Ortaq test vektorları**
  - Vəziyyət: `phones.json`, `excel.json`, `maps.json` və qaydalar (`spec/test-vectors/README.md`), JS istinad testi keçir. `spec/design.md` dizayn tapşırığında yazıldı (tokenlər, şriftlər yoxlanılıb, kontrast AA).
  - Asılılıq: T01
  - `/spec/test-vectors/phones.json`: Azərbaycan nömrələrinin müxtəlif yazılışları → E.164 (`050 123 45 67`, `+994501234567`, `994 50 123-45-67`, `0501234567`, səhv nömrələr) və gözlənilən nəticə.
  - `/spec/test-vectors/excel.json`: Excel sütun adlarının 4 dildə variantları (Ad, Имя, Name, İsim; Telefon, Телефон, Phone…) və xətalı sətir nümunələri.
  - `/spec/design.md`: rənglər, şriftlər, boşluqlar, düymə stilləri (T02 eskizlərindən).

---

## Faza 4 — Android və iOS (paralel)

Hər modul üçün əvvəl **A** (Android), sonra **I** (iOS). Hər iki tapşırıq bitmədən növbəti modula keçmə.

- [ ] **T41A / T41I Layihə quruluşu və dizayn sistemi**
  - Asılılıq: T32, T33
  - Android: Kotlin, Compose, minSdk 26, `supabase-kt`, naviqasiya, DI. iOS: SwiftUI, iOS 16+, `supabase-swift`. Dizayn tokenləri `/spec/design.md`-dən. i18n faylları generatordan.
  - Hazırdır, əgər: boş tətbiq 4 dildə açılır, dil sistem dilinə görə seçilir, CI-də build keçir.

- [ ] **T42A / T42I Giriş**
  - Asılılıq: T41
  - E-poçt + şifrə ilə qeydiyyat, giriş, çıxış, şifrə bərpası (Supabase Auth). Sessiya yadda qalır.
  - Hazırdır, əgər: ekran axını `/spec/screens.md`-yə uyğundur; səhv şifrə və şəbəkə xətası düzgün göstərilir.

- [ ] **T43A / T43I Tədbirlər və tədbir yaratma**
  - Asılılıq: T42
  - Tədbirlər siyahısı; yaratma addımları: növ → adlar → tarix/saat → məkan (ad + xəritə linki) → əsas dil → masadakıları göstər (defolt bağlı).
  - Hazırdır, əgər: tədbir bazada yaranır, redaktə və silmə (yalnız owner) işləyir.

- [ ] **T44A / T44I Şablon kataloqu və fərdiləşdirmə**
  - Asılılıq: T43, T26
  - Kataloq (pulsuz/pullu nişanı, limit). WebView-da `?preview=1` rejimi ilə canlı önizləmə. Rəng, şrift, mətnlər, cütlüyün şəkilləri (sıxılıb `event-media`-ya yüklənir), musiqi seçimi. Pullu şablon alınmayıbsa: önizləmə var, "Göndər" bağlıdır.
  - Hazırdır, əgər: dəyişikliklər önizləmədə dərhal görünür və saxlanılır.

- [ ] **T45A / T45I Qonaq əlavə etmə**
  - Asılılıq: T43, T33
  - Əl ilə; telefon kontaktlarından çoxlu seçim (Android contact picker, iOS `CNContactPickerViewController`); Excel `.xlsx` idxalı (sütun uyğunlaşdırma ekranı, səhv sətirlərin siyahısı). Nömrələr `phones.json` vektorlarına görə normallaşdırılır. Təkrar nömrə xəbərdarlığı. Limit dolanda alış təklifi.
  - Hazırdır, əgər: hər iki platformanın unit testləri eyni vektorlardan keçir; 300 sətirlik Excel 5 saniyədən tez idxal olunur.

- [ ] **T46A / T46I Qonaq siyahısı: masa, tərəf, dil, hitab**
  - Asılılıq: T45
  - Hər qonaq: hitab, ad, "ailəliklə" / nəfər, tərəf, masa nömrəsi, dil (boş = tədbirin dili). Filtr (tərəf, masa, cavab statusu) və axtarış. Toplu masa təyini.
  - Hazırdır, əgər: dəyişikliklər bazaya yazılır və filtr düzgün işləyir.

- [ ] **T47A / T47I Adlı önizləmə şəkilləri**
  - Asılılıq: T46, T15
  - Hər qonaq üçün 1200×630 JPEG (≤ 80 KB): şablonun fon şəkli/rəngi + "<Hitablı ad>, sizi … dəvət edirik" (qonağın dilində). Android `Canvas`, iOS `UIGraphicsImageRenderer`. `previews/<kod>.jpg`-ə yüklənir; ad və ya dil dəyişəndə yenidən yaradılır.
  - **Göndərmədən əvvəl məcburi önizləmə ekranı:** bütün adları yoxlamaq üçün siyahı.
  - Hazırdır, əgər: 300 şəkil 30 saniyədən tez yaradılır və yüklənir; real WhatsApp-da önizləmə adla görünür.

- [ ] **T48A / T48I Göndərmə axını**
  - Asılılıq: T47
  - Hər qonaq üçün mesaj mətni (qonağın dilində, link daxil) → `https://wa.me/<nömrə>?text=<encoded>`. "Göndər" WhatsApp-ı açır; tətbiqə qayıdanda "Göndərildi?" təsdiqi və "Növbəti qonaq". `sent_at` yazılır. Gündə 120-dən çox göndərmədə xəbərdarlıq. Göndərilməyənlər filtri.
  - Hazırdır, əgər: 10 qonaqlıq axın real telefonda dayanmadan işləyir.

- [ ] **T49A / T49I Statistika**
  - Asılılıq: T48
  - Göndərildi / baxdı / gəlir / gəlmir / cavab yoxdur; gələcək ümumi nəfər; tərəf və masa üzrə bölgü. Aşağı çəkib yeniləmə.
  - Hazırdır, əgər: rəqəmlər bazadakı məlumatla üst-üstə düşür (seed ilə test).

- [ ] **T4AA / T4AI Ortaq ailə**
  - Asılılıq: T14, T43
  - Owner e-poçtla dəvət yaradır (paylaşılan link/kod); ikinci istifadəçi kodu tətbiqdə daxil edib qoşulur. Tərəf seçimi; siyahıda tərəfə görə filtr.
  - Hazırdır, əgər: iki fərqli hesabla eyni tədbir idarə olunur, cohost silə bilmir.

- [ ] **T4BA / T4BI İxrac**
  - Asılılıq: T49
  - Qonaq siyahısını Excel (`.xlsx`) və PDF kimi ixrac (ad, tərəf, masa, cavab, nəfər), paylaşma menyusu ilə.
  - Hazırdır, əgər: fayllar Excel/Numbers və PDF oxuyucusunda düzgün açılır, 4 dildə başlıqlar.

- [ ] **T4C Ödənişin server yoxlaması (Edge Function)**
  - Vəziyyət: kod, SQL (009) və testlər hazırdır (pgTAP 24, TS 38 — mağazalar imitasiya ilə). **Qalıb:** real sandbox/test alışları ilə sınaq — Play Console xidmət hesabı və App Store Connect açarı lazımdır (T00).
  - Asılılıq: T13
  - `verify-purchase` Edge Function: Google Play Developer API və App Store Server API ilə qəbzi yoxlayır, `purchases`-a yazır, tədbirin şablonunu açır və ya limiti artırır. İdempotent (eyni əməliyyat iki dəfə sayılmır). Geri qaytarma (refund) bildirişləri üçün endpoint.
  - Hazırdır, əgər: sandbox/test alışları ilə testlər keçir. Hesabatda "İnsan yoxlaması lazımdır" bölməsi var.

- [ ] **T4DA / T4DI Tətbiqdaxili alış**
  - Asılılıq: T4C, T44
  - Məhsullar: hər pullu şablon (19,99 AZN), `limit_addon_200`. Google Play Billing / StoreKit 2; alışdan sonra qəbz `verify-purchase`-ə göndərilir; "alışları bərpa et".
  - Hazırdır, əgər: test hesabları ilə alış, uğursuz alış, ləğv və bərpa ssenariləri işləyir.

---

## Faza 5 — Pilot və buraxılış

- [ ] **T50 Hüquqi səhifələr**
  - Asılılıq: T20
  - Agent 4 dildə məxfilik siyasəti və istifadə şərtləri qaralaması yazır, `/web/public/legal/`-da yerləşdirir. **[SİZ] hüquqşünasla yoxlayın.**
  - Vəziyyət: istifadə şərtləri qaralaması 4 dildə hazırdır (`web/public/legal/terms/`). **Qalıb:** məxfilik siyasəti — sahib (ad, VÖEN) və əlaqə e-poçtu verilənə qədər saxlanılıb; region: AB (Frankfurt).

- [ ] **T51 Mağaza mətnləri**
  - Asılılıq: T4DA, T4DI
  - Play Store və App Store üçün 4 dildə ad, qısa və uzun təsvir, açar sözlər qaralaması; ekran şəkilləri üçün demo məlumat (seed).

- [ ] **T52 [SİZ] Qapalı test və TestFlight**
  - Google Play qapalı testi (yeni hesabların tələblərini yoxlayın) və TestFlight; 10–15 tanış ailə.

- [ ] **T53 [SİZ] Pilot**
  - 5–10 real tədbir. Hər problemi `/spec/bugs.md`-yə yazın (addımlar, telefon modeli, ekran görüntüsü).

- [ ] **T54 Səhvlərin düzəldilməsi**
  - Asılılıq: T53
  - `/spec/bugs.md`-dəki hər səhv üçün ayrıca commit; hər iki platformada yoxlama.

- [ ] **T55 [SİZ] Mağazalara göndərmə**
  - Brend adı və domen seçilib, `PUBLIC_BASE_URL` yenilənib; hər iki tətbiq yoxlamaya göndərilir.
