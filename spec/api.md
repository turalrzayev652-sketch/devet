# api.md — Tətbiq ↔ backend müqaviləsi

Hər ekranın (`spec/screens.md`) hansı cədvəl, RPC, Storage və Edge Function çağırışını etdiyi, sorğu/cavab formaları və xəta kodları. Mənbə: `backend/supabase/migrations/001–012`, `backend/supabase/functions/`, `spec/test-vectors/`. Backend dəyişəndə bu fayl da yenilənir; §9-dakı icazə cədvəli skriptlə miqrasiyalara qarşı yoxlanılır.

Qonaq səhifəsinin (veb) RPC-ləri — `get_preview`, `get_invite`, `submit_rsvp` — `PRODUCT.md` §6 və `templates.md` §6-dadır; tətbiq onları çağırmır.

---

## 0. Ümumi qaydalar

### 0.1 Bağlantı
- **Kitabxanalar:** Android `supabase-kt` (Postgrest, Auth, Storage, Functions modulları), iOS `supabase-swift`. Aşağıdakı nümunələr PostgREST HTTP formasındadır — SDK çağırışları birbaşa bunlara uyğun gəlir.
- **Ünvan və açar:** `SUPABASE_URL`, `SUPABASE_ANON_KEY` build konfiqurasiyasından. **Tətbiqdə yalnız anon açar olur** (CLAUDE.md); `service_role` heç vaxt.
- **Başlıqlar:** `apikey: <anon>` + `Authorization: Bearer <istifadəçinin access token-i>` (SDK özü qoyur). Bütün giriş RLS ilə məhdudlaşır.
- **Tarix/saat:** ISO 8601, `timestamptz` (`2027-07-12T18:00:00+04:00`). Göstərmə `Asia/Baku` ilə (templates.md §3.1).
- **ID-lər:** `uuid`; qonaq kodu 8 simvol (`K7D2M9QX`), tətbiq onu **yaratmır** — server verir.

### 0.2 Xəta modeli
Tətbiq hər xətanı aşağıdakı kateqoriyalardan birinə salır və mesajı `app.json`-dan göstərir (mətnlər T42+ mərhələsində əlavə olunur).

| Mənbə | Necə tanınır | Kateqoriya / kod | Tətbiqin davranışı |
| --- | --- | --- | --- |
| Şəbəkə | timeout, bağlantı yoxdur | `network` | `common.error.network` + "Yenidən cəhd et"; daxil edilən məlumat itmir |
| Auth | 401 / token bitib | `unauthorized` | sessiyanı yeniləməyə cəhd → olmazsa [1 Giriş] |
| RLS / icazə | PostgREST `42501`, və ya `update`/`delete` 0 sətir qaytarır | `forbidden` | "Bu əməliyyata icazəniz yoxdur" (adətən UI düyməni göstərmir) |
| Qonaq limiti | `P0001`, `message = guest_limit_exceeded`, `hint = purchase_required`, `detail = limit=N` | `guest_limit_exceeded` | limit sheet-i (screens.md §7) → [12] |
| CHECK pozulması | `23514` | `validation` | tətbiq validasiyası bunu əvvəlcədən tutmalıdır; tutmayıbsa ümumi "Məlumat yanlışdır" |
| Unikallıq | `23505` | `conflict` | ümumi xəta (normal axında olmamalıdır) |
| RPC / Edge Function | `{ "ok": false, "error": "<kod>" }` | həmin kod | §5, §6 cədvəlləri |

### 0.3 Status hesablanması (qonaq)
`design.md` §2.2 ilə eyni, tətbiqdə hesablanır:
`rsvp_status = yes` → **coming** (pill: "Gəlir {rsvp_count}"); `no` → **declined**; `pending` və `opened_at` dolu → **viewed**; `pending` və `sent_at` dolu → **pending** ("Cavab yoxdur"); qalan → **unsent**.

### 0.4 Göstərilən ad
`displayName(guest, lang)` — `invite.json` → `salutation.*` + `salutation.family` (server `display_name_forms` ilə eyni; `tools/i18n/check-invite.mjs` yoxlayır). `lang = guests.lang ?? events.default_lang`.

---

## 1. Məlumat formaları

### Event (`events`)
```json
{ "id": "uuid", "type": "wedding|engagement|henna|birthday|jubilee", "title_names": "Aysel və Ramin",
  "host_names": "…|null", "starts_at": "2027-07-12T18:00:00+04:00", "venue_name": "Ağ Saray şadlıq evi",
  "venue_address": "…|null", "venue_lat": 40.4093, "venue_lng": 49.8671, "maps_url": "https://…|null",
  "default_lang": "az|ru|en|tr", "template_id": "free-01|null", "customization": { },
  "show_tablemates": false, "is_paid": false, "status": "draft|active|archived",
  "created_by": "uuid|null", "created_at": "…", "updated_at": "…|null" }
```
- `is_paid` yalnız server (`verify-purchase`) yazır. `status`-u tətbiq yazmır: ilk `sent_at`-də server `active` edir (miqrasiya 010); "Arxiv" tətbiqdə hesablanır (`starts_at + 7 gün < indi`).
- `customization` forması: templates.md §2 (`colors`, `fonts`, `texts`, `photos`, `music`).

### Guest (`guests`)
```json
{ "id": "uuid", "event_id": "uuid", "code": "K7D2M9QX", "salutation": "muellim|xanim|bey|none", "name": "Elçin",
  "with_family": true, "invited_count": 4, "phone_e164": "+994501234567|null", "side": "groom|bride|none",
  "table_no": "12|null", "lang": "az|ru|en|tr|null", "preview_path": "previews/K7D2M9QX.jpg|null",
  "sent_at": "…|null", "opened_at": "…|null", "rsvp_status": "pending|yes|no", "rsvp_count": 0,
  "rsvp_at": "…|null", "added_by": "uuid|null" }
```
- `code`, `opened_at` — yalnız server. `phone_e164` tədbirdən 90 gün sonra `null` olur (T16).
- Validasiya (tətbiq, `test-vectors/` ilə eyni): ad 1–80, `invited_count` 1–50, telefon `phones.json`, masa ≤ 12 simvol.

### Digərləri
| Cədvəl | Tətbiqin gördüyü sütunlar | Qeyd |
| --- | --- | --- |
| `profiles` | `id, email, display_name, ui_lang` | yalnız öz sətri |
| `templates` | `id, name{az,ru,en,tr}, is_premium, store_product_id, version, thumbnail_url, langs, sort_order, active` | hamı oxuyur |
| `event_members` | `event_id, user_id, role (owner|cohost), side` | üzvü olduğu tədbirlər |
| `event_invites` | `event_id, email, side, token, accepted_at, expires_at` | yalnız owner |
| `purchases` | `event_id, kind, template_id, store, store_transaction_id, verified_at, refunded_at` | yalnız öz alışları |
| `app_config` | `key, value` (`daily_send_warning`, `free_guest_limit`, …) | girişli istifadəçi oxuyur |

---

## 2. Ekranlar → çağırışlar

### [1] Giriş / Qeydiyyat / Bərpa
| Hərəkət | Çağırış | Uğur | Xəta |
| --- | --- | --- | --- |
| Giriş | Auth `signInWithPassword(email, password)` | sessiya → [2] | `invalid_credentials` → `auth.error.invalid_credentials`; `email_not_confirmed` → təsdiq ekranı |
| Qeydiyyat | Auth `signUp(email, password, data: { display_name })`, sonra (təsdiqdən sonra) `profiles` update `display_name` | "E-poçtunuzu təsdiqləyin" | `user_already_exists` → "Bu e-poçtla hesab artıq var"; `weak_password` → ≥ 6 simvol |
| Təsdiqi yenidən göndər | Auth `resend(type: signup, email)` | bildiriş | `over_email_send_rate_limit` → "Bir az gözləyin" |
| Şifrə bərpası | Auth `resetPasswordForEmail(email, redirectTo: az.devet.app://auth/reset-password)` | həmişə "E-poçtunuzu yoxlayın" (hesab varlığı açılmır) | — |
| Yeni şifrə (deep link) | Auth `updateUser(password)` | → [2] | `weak_password` |
| Sessiya | SDK özü saxlayır və yeniləyir | — | yenilənmə alınmasa → [1] |

`profiles` sətri qeydiyyatda trigger ilə yaranır (`handle_new_user`), tətbiq insert etmir.

**E-poçt linkləri (qərar 2026-10-31):** xüsusi sxem, PKCE axını. Qeydiyyat təsdiqi `signUp(..., redirectTo: az.devet.app://auth/callback)`, bərpa `az.devet.app://auth/reset-password`; link `?code=…` ilə gəlir → `exchangeCodeForSession(code)`. Bərpa linkindən sonra "Yeni şifrə" ekranı. Xəta (`error_code`, məs. `otp_expired`) → "Link etibarsızdır". Supabase panelində Redirect URLs: `az.devet.app://auth/**`.

### [2] Tədbirlərim
```http
GET /rest/v1/events?select=id,type,title_names,starts_at,venue_name,template_id,status,
    templates(thumbnail_url),event_members(user_id,role),guests(rsvp_status,rsvp_count,sent_at,opened_at)
    &order=starts_at.asc
```
- Rol: `event_members` içində öz `user_id`-si. Mini statistika `guests`-dən tətbiqdə sayılır (≤ 300 sətir/tədbir).
- Arxiv: `starts_at + 7 gün < indi`.
- **Sil** (owner): `DELETE /rest/v1/events?id=eq.<id>` → 1 sətir; cohost üçün RLS 0 sətir qaytarır → `forbidden`. Qonaqlar, üzvlər, dəvətlər, alışlar kaskadla silinir.
- **Arxivlə:** yalnız lokal görünüş seçimi (v1-də serverdə sahə yoxdur).

### [3] Tədbir yaratma / redaktə
```http
POST /rest/v1/events            Prefer: return=representation
{ "type": "wedding", "title_names": "Aysel və Ramin", "host_names": null,
  "starts_at": "2027-07-12T18:00:00+04:00", "venue_name": "Ağ Saray şadlıq evi", "venue_address": null,
  "maps_url": "https://www.google.com/maps/place/…", "venue_lat": 40.4093, "venue_lng": 49.8671,
  "default_lang": "az", "show_tablemates": false }
```
- `created_by` göndərilmir (defolt `auth.uid()`); başqasının id-si → `42501`. Trigger yaradanı owner edir; `return=representation` sətri dərhal qaytarır.
- `venue_lat/lng` — `maps_url`-dən tətbiqdə çıxarılır (`test-vectors/maps.json`); çıxmasa `null`.
- Redaktə: `PATCH /rest/v1/events?id=eq.<id>` yalnız dəyişən sahələrlə (owner və cohost). Keçmiş tarix tətbiqdə qadağandır (§15.4).

### [4] Şablon kataloqu
```http
GET /rest/v1/templates?select=*&active=eq.true&order=sort_order.asc
```
- Növə uyğunluq: `/templates/<id>/template.json → event_types` (veb host, `PUBLIC_BASE_URL`), kataloq açılanda keşlənir.
- Qiymət: mağaza SDK (`store_product_id` → Play `ProductDetails` / StoreKit `Product`), koda yazılmır.
- Önizləmə: WebView `PUBLIC_BASE_URL/templates/<id>/index.html?preview=1` (§2 [5]).

### [5] Fərdiləşdirmə
| Hərəkət | Çağırış |
| --- | --- |
| Şablon meta | `GET {PUBLIC_BASE_URL}/templates/<id>/template.json` (css_vars, fonts, texts, photos.max, music) |
| Canlı önizləmə | WebView `?preview=1`; məlumat `window.postMessage({ type: 'invite:data', payload })`, payload = `get_invite` cavabı + `media`, `tier`, `brand` (templates.md §6.2). Şəkil/musiqi üçün §4-dəki imzalı linklər |
| Şəkil yükləmə | sıxma (≤ 1600 px, JPEG ≤ 2 MB) → Storage `event-media/<event_id>/photos/<uuid>.jpg` |
| Musiqi yükləmə | `event-media/<event_id>/music/<uuid>.<mp3|m4a|aac|ogg>` (≤ 5 MB) |
| Yadda saxla | `PATCH /rest/v1/events?id=eq.<id>` `{ "template_id": "premium-01", "customization": { … } }` |
| Silinmiş şəkil | Storage `remove([path])` + `customization.photos`-dan çıxarmaq |

### [6] Qonaqlar
```http
GET /rest/v1/guests?select=*&event_id=eq.<id>&order=name.asc
POST /rpc/event_guest_limit   { "p_event_id": "<id>" }   → 100 | 300 | 500 … | null (üzv deyil)
```
- Filtr və axtarış tətbiqdə (bütün siyahı yüklənir; `max_rows = 1000`).
- Redaktə: `PATCH /rest/v1/guests?id=eq.<id>` (yalnız §9 sütunları). Toplu masa/tərəf: `PATCH /rest/v1/guests?id=in.(…)` `{ "table_no": "14" }`.
- Sil (owner): `DELETE /rest/v1/guests?id=eq.<id>`; cohost → 0 sətir (`forbidden`).
- Ad/hitab/dil dəyişəndə: köhnə `previews/<code>.jpg` yenidən yaradılır (§2 [8]).

### [7] Qonaq əlavə etmə
```http
POST /rest/v1/guests            Prefer: return=representation
[ { "event_id": "<id>", "salutation": "muellim", "name": "Elçin", "with_family": true, "invited_count": 4,
    "phone_e164": "+994501234567", "side": "groom", "table_no": "12", "lang": null } ]
```
- `added_by` göndərilmir (defolt `auth.uid()`). `code` göndərilmir — göndərilsə `42501`.
- Telefon tətbiqdə `phones.json` qaydaları ilə normallaşdırılır; Excel `excel.json` qaydaları ilə (sütun uyğunlaşdırma, sətir xətaları, `duplicate_phone` xəbərdarlığı).
- **Toplu idxal bir sorğu ilə** (massiv): limit aşılsa server **hamısını** rədd edir → `guest_limit_exceeded` (`detail: limit=N`). Tətbiq idxal vəziyyətini saxlayır və alışdan sonra təkrar göndərir.
- Kontaktlar: sistem seçicisi (icazəsiz), şəbəkə çağırışı yoxdur.

### [8] Göndərmə
| Addım | Çağırış |
| --- | --- |
| Ön şərtlər | event (`template_id`, `is_paid`), `templates.is_premium`, guests |
| Adlı önizləmə şəkli | tətbiqdə 1200×630 JPEG ≤ 80 KB → Storage **upsert** `previews/<CODE>.jpg` → `PATCH guests { "preview_path": "previews/<CODE>.jpg" }` |
| Mesaj | `app.json → wa_message.<type>` qonağın dilində: `{display_name}`, `{title_names}`, `{link}` = `{PUBLIC_BASE_URL}/i/<code>` |
| Göndər | `https://wa.me/<e164 rəqəmləri, + olmadan>?text=<url-encoded mesaj>` (sistem açır; şəbəkə çağırışı yoxdur) |
| "Bəli, növbəti" | `PATCH /rest/v1/guests?id=eq.<id>` `{ "sent_at": "<indi>" }` — ilkində server tədbiri `active` edir |
| Gündəlik xəbərdarlıq | `GET /rest/v1/app_config?key=eq.daily_send_warning` (keşlə) + bu tədbirdə bu gün (`Asia/Baku`) `sent_at` sayı |
| Telefonsuz — "Linki kopyala" | lokal: `{PUBLIC_BASE_URL}/i/<code>` panoya |

### [9] Statistika
Bütün rəqəmlər `GET /rest/v1/guests?select=side,table_no,sent_at,opened_at,rsvp_status,rsvp_count&event_id=eq.<id>`-dən tətbiqdə hesablanır (screens.md §9 cədvəli). Aşağı çəkib yeniləmə = eyni sorğu. İxrac (T4B) lokal fayl + paylaşma menyusu.

### [10] Masalar
- Siyahı: [6]-nın sorğusu, `table_no` üzrə qruplaşdırma (təbii sıralama).
- "Masadakıları göstər": `PATCH /rest/v1/events?id=eq.<id>` `{ "show_tablemates": true }`.
- Toplu təyin: `PATCH /rest/v1/guests?id=in.(<ids>)` `{ "table_no": "14" }`.

### [11] Ortaq ailə
| Hərəkət | Çağırış | Cavab |
| --- | --- | --- |
| Üzvlər | `GET /rest/v1/event_members?select=user_id,role,side&event_id=eq.<id>` | — |
| Dəvət yarat (owner) | `POST /rpc/create_cohost_invite` `{ "event_id": "<id>", "email": "ramin@…", "side": "bride" }` | `{ ok, token, expires_at }` |
| Açıq dəvət (owner) | `GET /rest/v1/event_invites?event_id=eq.<id>&accepted_at=is.null` | — |
| Kodla qoşul | `POST /rpc/accept_cohost_invite` `{ "token": "K7D2M9QX" }` | `{ ok, event_id }` |
| Ortağı çıxar (owner) | `DELETE /rest/v1/event_members?event_id=eq.<id>&role=eq.cohost` | 1 sətir |

Ortağın adı/e-poçtu: v1-də `event_members` yalnız `user_id` verir; owner üçün ad dəvətin `email`-indən göstərilir (§10 açıq məsələ 2).

### [12] Alış
1. Məhsullar: mağaza SDK — premium şablonlar üçün `templates.store_product_id`, limit üçün `app_config.limit_addon_product_id` (`limit_addon_200`).
2. Alış: Android `BillingFlowParams` + `setObfuscatedAccountId(userId)` + `setObfuscatedProfileId(eventId)`; iOS `product.purchase(options: [.appAccountToken(userId)])`.
3. Server yoxlaması: `POST /functions/v1/verify-purchase` (§6.1).
4. Uğurdan sonra event (`is_paid`) və `event_guest_limit` yenidən oxunur.
5. **Bərpa / gözləmədə:** tətbiq açılanda və "Alışları bərpa et"-də mağazanın təsdiqlənmiş, amma serverə çatmamış alışları yenidən `verify-purchase`-ə göndərilir (idempotent).

### [12a] Daha çox
Yuxarıdakı ekranların çağırışları; "Tədbiri sil" = [2]-dəki `DELETE events`.

### [12b] Parametrlər
| Hərəkət | Çağırış |
| --- | --- |
| Profil | `GET /rest/v1/profiles?select=*` (bir sətir); `PATCH /rest/v1/profiles?id=eq.<uid>` `{ "display_name": "…", "ui_lang": "ru" }` |
| Çıxış | Auth `signOut()` |
| Hesabı sil | `POST /functions/v1/delete-account` (§6.2) → `signOut()` → [1] |

---

## 3. RPC-lər (tətbiq)

| Funksiya | Parametrlər | Cavab | Xətalar | Kim |
| --- | --- | --- | --- | --- |
| `event_guest_limit` | `p_event_id uuid` | `int` (üzv deyilsə `null`) | — | üzv |
| `create_cohost_invite` | `event_id uuid, email text, side side` | `{ ok: true, token, expires_at }` | `not_owner`, `invalid_email`, `cohost_exists` | owner |
| `accept_cohost_invite` | `token text` | `{ ok: true, event_id }` | `not_authenticated`, `not_found`, `expired`, `email_mismatch`, `already_member`, `cohost_exists` | girişli istifadəçi |

Mesajlar: screens.md §11, §11b.

## 4. Storage

| Bucket | Yol | Növ / ölçü | Oxu | Yaz |
| --- | --- | --- | --- | --- |
| `event-media` (qapalı) | `<event_id>/photos/<uuid>.jpg` | image/*, ≤ 2 MB (bucket ≤ 5 MB) | üzvlər (`createSignedUrl`) | üzvlər |
| `event-media` | `<event_id>/music/<uuid>.<ext>` | audio/*, ≤ 5 MB | üzvlər | üzvlər |
| `previews` (ictimai) | `<CODE>.jpg` (kökdə) | image/jpeg, ≤ 150 KB | ictimai link: `{SUPABASE_URL}/storage/v1/object/public/previews/<CODE>.jpg`; siyahı yoxdur | həmin qonağın tədbirinin üzvləri |

- Tətbiq önizləmə üçün imzalı link yaradır (`createSignedUrl(path, 3600)`); qonaq səhifəsi üçün linkləri Pages Function imzalayır (T24).
- Xətalar: 400/413 (ölçü/növ) → "Fayl çox böyükdür" / "Bu fayl növü dəstəklənmir"; 403 → `forbidden`; şəbəkə → həmin plitədə "Yenidən cəhd et".

## 5. Qonaq limiti

Server tərəfi: pulsuz 100, pullu 300, hər aktiv `limit_addon` +200 (`app_config`). Hər qonaq insert-ində trigger yoxlayır; toplu insert ya tam keçir, ya tam rədd olunur. Tətbiq limiti göstərmək üçün `event_guest_limit` çağırır, sayı `guests` sorğusundan bilir; yoxlama yalnız serverdə etibarlıdır.

## 6. Edge Functions

### 6.1 `POST /functions/v1/verify-purchase`
Sorğu (`Authorization: Bearer <user token>`):
```json
{ "store": "google", "event_id": "uuid", "product_id": "template_premium_01", "purchase_token": "<Play token>" }
{ "store": "apple",  "event_id": "uuid", "product_id": "limit_addon_200",     "transaction_id": "2000000001" }
```
Uğur `200`: `{ "ok": true, "status": "created|already_recorded", "kind": "template|limit_addon", "is_paid": true, "guest_limit": 300 }`

| HTTP | `error` | Ekran davranışı (screens.md §12) |
| --- | --- | --- |
| 400 | `invalid_request` | "Bu məhsul hazırda alına bilməz" |
| 401 | `unauthorized` | → [1] |
| 403 | `not_member` | → [2] |
| 404 | `purchase_not_found` | "Alış tamamlanmadı" |
| 409 | `transaction_used`, `refunded` | "Bu alış bu tədbir üçün istifadə edilə bilməz" |
| 422 | `purchase_pending` | gözləmədə halı |
| 422 | `purchase_cancelled` | "Alış tamamlanmadı" |
| 422 | `purchase_mismatch`, `revoked` | "Bu alış bu tədbir üçün istifadə edilə bilməz" |
| 422 | `test_purchase_not_allowed` | "Test alışları qəbul edilmir" |
| 422 | `unknown_product`, `template_mismatch` | "Bu məhsul hazırda alına bilməz" / "Alış seçilmiş şablona uyğun deyil" |
| 502 | `store_unavailable` | "Alışınız qorunub, bir az sonra yenidən yoxlanacaq" + bərpa |
| 503 | `store_not_configured` | eyni |

### 6.2 `POST /functions/v1/delete-account`
Sorğu: body yoxdur, `Authorization: Bearer <user token>`.
Uğur `200`: `{ "ok": true, "deleted_events": 1, "left_events": 0 }` → tətbiq `signOut()`.

| HTTP | `error` | Davranış |
| --- | --- | --- |
| 401 | `unauthorized` | → [1] |
| 502 | `storage_unavailable` | heç nə silinməyib — "Hesab silinmədi, yenidən cəhd edin" |
| 502 | `delete_failed` | qismən silinib — təkrar təhlükəsizdir, eyni mesaj |

### 6.3 `store-notifications` (yalnız mağazalar)
Tətbiq çağırmır. Google RTDN / Apple Server Notifications V2 → geri qaytarma mağaza API-si ilə təsdiqlənəndə `is_paid` və limit yenilənir; tətbiq bunu növbəti oxunuşda görür.

## 7. Realtime
v1-də yoxdur: ekranlar açılanda və aşağı çəkib yeniləyəndə oxunur. İki ailə eyni anda redaktə edəndə son yazılan qalır (screens.md §15.8).

## 8. Bütün xəta kodları (indeks)

| Kod | Mənbə | Bölmə |
| --- | --- | --- |
| `network`, `unauthorized`, `forbidden`, `validation`, `conflict` | tətbiq kateqoriyası | §0.2 |
| `guest_limit_exceeded` | trigger (P0001) | §0.2, §5 |
| `invalid_credentials`, `email_not_confirmed`, `user_already_exists`, `weak_password`, `over_email_send_rate_limit` | Supabase Auth | §2 [1] |
| `not_owner`, `invalid_email`, `cohost_exists`, `not_authenticated`, `not_found`, `expired`, `email_mismatch`, `already_member` | cohost RPC | §3 |
| `invalid_request`, `not_member`, `purchase_not_found`, `transaction_used`, `refunded`, `purchase_pending`, `purchase_cancelled`, `purchase_mismatch`, `test_purchase_not_allowed`, `revoked`, `unknown_product`, `template_mismatch`, `store_unavailable`, `store_not_configured` | `verify-purchase` | §6.1 |
| `storage_unavailable`, `delete_failed` | `delete-account` | §6.2 |
| `empty`, `invalid`, `not_mobile` | telefon (tətbiq) | `test-vectors/phones.json` |
| `name_column_missing`, `name_missing`, `phone_invalid`, `phone_not_mobile`, `salutation_invalid`, `invited_count_invalid`, `with_family_invalid`, `side_invalid`, `table_no_invalid`, `no_rows`, `duplicate_phone` | Excel (tətbiq) | `test-vectors/excel.json` |
| `empty`, `invalid_url` | xəritə linki (tətbiq) | `test-vectors/maps.json` |

## 9. Tətbiqin yaza biləcəyi sütunlar (miqrasiya 002 ilə eyni)

<!-- writable-columns: skriptlə yoxlanılır -->
| Cədvəl | Əməliyyat | Sütunlar |
| --- | --- | --- |
| profiles | update | display_name, ui_lang |
| events | insert | type, title_names, host_names, starts_at, venue_name, venue_address, venue_lat, venue_lng, maps_url, default_lang, template_id, customization, show_tablemates, status, created_by |
| events | update | type, title_names, host_names, starts_at, venue_name, venue_address, venue_lat, venue_lng, maps_url, default_lang, template_id, customization, show_tablemates, status |
| events | delete | (yalnız owner, RLS) |
| guests | insert | event_id, salutation, name, with_family, invited_count, phone_e164, side, table_no, lang, preview_path, sent_at, rsvp_status, rsvp_count, rsvp_at, added_by |
| guests | update | salutation, name, with_family, invited_count, phone_e164, side, table_no, lang, preview_path, sent_at, rsvp_status, rsvp_count, rsvp_at |
| guests | delete | (yalnız owner, RLS) |
| event_members | delete | (yalnız owner, yalnız cohost sətri) |
| event_invites | delete | (yalnız owner) |
<!-- /writable-columns -->

`status` və `created_by` texniki olaraq yazıla bilir, amma tətbiq onları göndərmir (§1). `is_paid`, `code`, `opened_at` yalnız server tərəfindən yazılır.

## 10. Açıq məsələlər

1. **Tədbir kartlarının statistikası** ([2]) hər tədbir üçün qonaq sətirlərini yükləyir; çox tədbirli istifadəçidə ağır olarsa, `event_summaries()` RPC-si əlavə etmək olar (aqreqat serverdə).
2. **Ortağın adı:** `event_members` digər üzvün adını vermir (`profiles` yalnız özünü göstərir). v1-də owner ortağı dəvətin e-poçtu ilə görür; ad lazımdırsa `event_member_names(event_id)` RPC-si lazımdır.
3. **Gündəlik göndərmə sayı** tədbir üzrə hesablanır (`sent_at` göndərəni saxlamır); bir telefondan iki tədbirə göndərmə ayrı sayılır.
