# PRODUCT.md — Məhsul spesifikasiyası (mənbə həqiqəti)

Bu fayl bütün məhsul qərarlarını saxlayır. Kod yazarkən buradakı qaydalar əsasdır. Burada olmayan və ya ziddiyyətli bir şey görsən — **təxmin etmə, sual ver**.

Hələ seçilməmiş dəyərlər `{{PLACEHOLDER}}` kimi yazılıb; onları kodda konfiqurasiya dəyəri kimi saxla, birbaşa koda yazma.

| Placeholder | Hazırkı dəyər |
| --- | --- |
| `{{BRAND_NAME}}` | Hələ seçilməyib. Müvəqqəti: `Devet` |
| `{{PUBLIC_BASE_URL}}` | Müvəqqəti: Cloudflare Pages ünvanı (`https://<layihə>.pages.dev`) |
| `{{ANDROID_APP_ID}}` | `az.devet.app` (müvəqqəti) |
| `{{IOS_BUNDLE_ID}}` | `az.devet.app` (müvəqqəti) |

---

## 1. Məhsul bir cümlədə

Ailə tətbiqdə tədbir yaradır, HTML şablon seçir, qonaqları əlavə edir və hər qonağa **adı ilə** dəvəti WhatsApp-da bir toxunuşla göndərir; qonaq linki brauzerdə açıb cavab verir, ailə isə kimin neçə nəfərlə gələcəyini tətbiqdə görür.

## 2. İstifadəçilər və rollar

| Rol | Kimdir | Nə edə bilir |
| --- | --- | --- |
| Owner | Tədbiri yaradan ailə üzvü | Hər şey, o cümlədən tədbiri silmək, cohost dəvət etmək, alış etmək |
| Cohost | Owner-in dəvət etdiyi ikinci ailə (məs. gəlin tərəfi) | Tədbiri və qonaqları redaktə, qonaq əlavə, göndərmə, statistika, alış. **Silə bilməz**, cohost dəvət edə bilməz |
| Guest | Dəvət olunan şəxs | Yalnız öz dəvət səhifəsini açır və cavab verir. Hesabı yoxdur |

Bir tədbirdə maksimum 1 owner və 1 cohost.

## 3. Əsas axınlar

### 3.1 Ailə axını
1. Qeydiyyat / giriş (e-poçt + şifrə).
2. Tədbir yaratma: növ → adlar → tarix və saat → məkan (ad + xəritə linki və ya koordinat) → əsas dil → "masadakıları göstər" (defolt: xeyr).
3. Şablon seçimi və fərdiləşdirmə (rəng, şrift, mətnlər, şəkillər, musiqi). Pullu şablon alınmayıbsa: önizləmə mümkündür, göndərmə bağlıdır.
4. Qonaq əlavə etmə: əl ilə, telefon kontaktlarından, Excel-dən.
5. Hər qonağa: hitab, "ailəliklə" və ya nəfər sayı, tərəf, masa nömrəsi, dil.
6. Göndərmədən əvvəl **məcburi önizləmə**: bütün adların siyahısı.
7. Göndərmə: qonaq-qonaq `wa.me` axını.
8. Statistika: göndərildi, baxdı, gəlir, gəlmir, cavab yoxdur, ümumi nəfər.

### 3.2 Qonaq axını
1. WhatsApp-da adlı önizləmə ilə link gəlir: `{{PUBLIC_BASE_URL}}/i/<kod>`.
2. Səhifə açılır: adlı müraciət, tədbir məlumatı, geri sayım, şəkillər, musiqi düyməsi, xəritə.
3. Cavab: "Gəlirəm" (+ neçə nəfər, maksimum dəvət olunan say) və ya "Gəlmirəm". Cavabı sonra dəyişmək olar.
4. Masa nömrəsi təyin edilibsə göstərilir; ailə icazə veribsə masadakı digər qonaqların adları da.

## 4. Tədbir növləri

`wedding` (toy), `engagement` (nişan), `henna` (xınayaxdı), `birthday` (ad günü), `jubilee` (yubiley).

## 5. Məlumat modeli

Bütün cədvəllərdə `id uuid pk default gen_random_uuid()`, `created_at timestamptz default now()`, `updated_at timestamptz`.

### profiles
| Sahə | Tip | Qeyd |
| --- | --- | --- |
| id | uuid | = auth.users.id |
| email | text | |
| display_name | text | |
| ui_lang | lang | defolt `az` |

### events
| Sahə | Tip | Qeyd |
| --- | --- | --- |
| type | event_type | |
| title_names | text | məs. "Aysel və Ramin" |
| host_names | text null | valideyn adları (dəvət mətnində istifadə üçün) |
| starts_at | timestamptz | |
| venue_name | text | |
| venue_address | text null | |
| venue_lat, venue_lng | double null | |
| maps_url | text null | |
| default_lang | lang | |
| template_id | text fk → templates.id | |
| customization | jsonb | `{ colors: {...}, fonts: {...}, texts: {...}, photos: [path], music: path }` |
| show_tablemates | boolean | defolt false |
| is_paid | boolean | pullu şablon bu tədbir üçün alınıbmı |
| status | text | `draft`, `active`, `archived` |

`guest_limit` saxlanılmır — funksiya ilə hesablanır (bax 7).

### event_members
| Sahə | Tip | Qeyd |
| --- | --- | --- |
| event_id | uuid fk | |
| user_id | uuid fk | |
| role | member_role | `owner`, `cohost` |
| side | side | `groom`, `bride`, `none` |
| unique(event_id, user_id) | | |

### event_invites
| Sahə | Tip | Qeyd |
| --- | --- | --- |
| event_id | uuid fk | |
| email | text | |
| side | side | |
| token | text unique | 8 simvol, təsadüfi |
| accepted_at | timestamptz null | |
| expires_at | timestamptz | yaradılandan 14 gün sonra |

### templates
| Sahə | Tip | Qeyd |
| --- | --- | --- |
| id | text pk | məs. `free-01`, `premium-01` |
| name | jsonb | 4 dildə ad |
| is_premium | boolean | |
| store_product_id | text null | pullu şablon üçün mağaza məhsul kodu |
| version | int | |
| thumbnail_url | text | |
| langs | lang[] | dəstəklənən dillər |
| sort_order | int | |
| active | boolean | |

### purchases
| Sahə | Tip | Qeyd |
| --- | --- | --- |
| user_id | uuid fk | |
| event_id | uuid fk | |
| kind | purchase_kind | `template`, `limit_addon` |
| template_id | text null | kind = template olanda |
| store | store | `google`, `apple` |
| store_transaction_id | text unique | idempotentlik üçün |
| amount_minor | int null | |
| currency | text null | |
| verified_at | timestamptz | |
| refunded_at | timestamptz null | geri qaytarılıbsa limit/şablon bağlanır |

Yalnız service role yazır (Edge Function `verify-purchase`).

### guests
| Sahə | Tip | Qeyd |
| --- | --- | --- |
| event_id | uuid fk | |
| code | text unique | 8 simvol, base32 (I, L, O, U olmadan), crypto random |
| salutation | salutation | `muellim`, `xanim`, `bey`, `none` |
| name | text | |
| with_family | boolean | "ailəliklə" |
| invited_count | int | defolt 1; with_family = true olsa belə ailə sayını yazmaq olar |
| phone_e164 | text null | E.164; 90 gündən sonra silinir |
| side | side | |
| table_no | text null | məs. "12" və ya "VIP-1" |
| lang | lang null | null = events.default_lang |
| preview_path | text null | `previews/<code>.jpg` |
| sent_at | timestamptz null | |
| opened_at | timestamptz null | ilk `get_invite` çağırışı |
| rsvp_status | rsvp_status | defolt `pending` |
| rsvp_count | int | defolt 0 |
| rsvp_at | timestamptz null | |
| added_by | uuid fk | |

### app_config (açar–dəyər)
| key | value | Qeyd |
| --- | --- | --- |
| free_guest_limit | 100 | |
| premium_guest_limit | 300 | |
| addon_guest_step | 200 | hər limit artırma alışı |
| daily_send_warning | 120 | gündəlik göndərmə xəbərdarlığı |
| phone_retention_days | 90 | |

## 6. RPC müqavilələri (qonaq tərəfi, `anon`)

### get_preview(code text) — yan təsirsiz
```json
{ "ok": true, "lang": "az", "display_name": "Elçin müəllim və ailəsi",
  "event_type": "wedding", "title_names": "Aysel və Ramin",
  "starts_at": "2027-07-10T18:00:00+04:00", "preview_url": "https://.../previews/K7D2M9QX.jpg",
  "template_id": "premium-01" }
```

### get_invite(code text) — ilk çağırışda opened_at yazır
```json
{ "ok": true,
  "event": { "type": "wedding", "title_names": "...", "host_names": "...", "starts_at": "...",
             "venue_name": "...", "venue_address": "...", "maps_url": "...", "lat": 40.4, "lng": 49.8,
             "template_id": "premium-01", "customization": { }, "is_paid": true },
  "guest": { "salutation": "muellim", "name": "Elçin", "with_family": true, "invited_count": 4,
             "lang": "az", "table_no": "12", "rsvp_status": "pending", "rsvp_count": 0 },
  "tablemates": ["Rəşad bəy", "Leyla xanım"] }
```
`tablemates` yalnız `show_tablemates = true` və `table_no` doludursa; qonağın özü daxil deyil.

### submit_rsvp(code text, status rsvp_status, count int)
- `yes` → 1 ≤ count ≤ invited_count; `no` → count = 0.
- Cavab: `{ "ok": true, "rsvp_status": "yes", "rsvp_count": 3 }`.

### Xəta kodları (hamısında eyni)
`{ "ok": false, "error": "not_found" | "event_past" | "invalid_count" | "rate_limited" }`

Tədbir tarixindən 7 gün sonra `get_invite` `event_past` qaytarır.

## 7. Biznes qaydaları

- **Qonaq limiti:** pulsuz şablon → `free_guest_limit`; tədbir üçün pullu şablon alınıbsa → `premium_guest_limit`; hər aktiv `limit_addon` alışı → `+addon_guest_step`. Limitdən artıq qonaq əlavə etmək server tərəfində rədd edilir; tətbiq bu halda alış təklif edir.
- **Pullu şablon** bir tədbir üçündür. Başqa tədbirdə istifadə üçün yenidən alınır.
- **Başlanğıc qiymət:** pullu şablon 19,99 AZN. Limit artırma qiyməti hələ seçilməyib — mağaza konsolunda təyin olunur, kodda qiymət yazılmır (qiyməti mağazadan oxu).
- **Watermark:** pulsuz şablonda səhifənin altında kiçik "{{BRAND_NAME}} ilə yaradılıb" yazısı və linki.
- **Ödəniş:** yalnız tətbiq daxilində. Mağaza məhsul kodları: hər pullu şablon üçün `templates.store_product_id`; limit artırma — `limit_addon_200`.
- **Göndərmə:** yalnız `wa.me`. Gündəlik `daily_send_warning`-dən çox göndərmədə xəbərdarlıq (bloklamır).
- **Məxfilik:** telefonlar tədbirdən `phone_retention_days` gün sonra silinir; linkdə ad/telefon olmur.

## 8. Hitab və dillər

Dillər: `az`, `ru`, `en`, `tr`. Qonağın dili = `guests.lang` ?? `events.default_lang`.

Göstərilən ad (`display_name`) qaydası (`/spec/i18n/invite.json` içində dəqiq formalar):

| salutation | az | ru | en | tr |
| --- | --- | --- | --- | --- |
| muellim | Elçin müəllim | Эльчин муаллим | Mr. Elchin | Elçin Bey |
| xanim | Leyla xanım | Лейла ханум | Ms. Leyla | Leyla Hanım |
| bey | Rəşad bəy | Рашад бей | Mr. Rashad | Reşad Bey |
| none | Elçin | Эльчин | Elchin | Elçin |

`with_family = true` → az: "… və ailəsi", ru: "… с семьёй", en: "… and family", tr: "… ve ailesi".

Qeyd: adın transliterasiyası **avtomatik edilmir** — ad necə yazılıbsa elə göstərilir. Yuxarıdakı cədvəl yalnız formanı göstərir.

## 9. WhatsApp mesaj mətni

`{{display_name}}` + tədbir növünə uyğun cümlə + link. Nümunə (az, toy):

> Hörmətli {{display_name}}! {{title_names}} toyuna dəvətlisiniz. Dəvətnamə: {{link}}

Bütün növlər və dillər üçün mətnlər `/spec/i18n/app.json`-da `wa_message.<event_type>` açarları ilə saxlanır.

## 10. Adlı önizləmə şəkli (og:image)

- Ölçü 1200×630, JPEG, ≤ 80 KB.
- Məzmun: şablonun fon rəngi/şəkli + "{{display_name}}" (iri) + tədbir cümləsi və tarix (qonağın dilində).
- Telefonda yaradılır, `previews/<code>.jpg`-ə yüklənir; ad, hitab və ya dil dəyişəndə yenilənir.
- `og:title`: "{{display_name}}, sizi {{title_names}} toyuna dəvət edirik" (dilə və növə görə).

## 11. Qonaq səhifəsinin blokları

| Blok | Məzmun | Qeyd |
| --- | --- | --- |
| hero | adlı müraciət, adlar, tarix | |
| countdown | gün/saat/dəqiqə | tədbir keçibsə gizlənir |
| gallery | cütlüyün şəkilləri | 0–6 şəkil |
| music | musiqi düyməsi | avtomatik başlamır |
| map | məkan adı, ünvan, Google Maps və Waze düymələri | |
| table | masa nömrəsi və (icazə varsa) masadakılar | |
| rsvp | gəlirəm/gəlmirəm, nəfər seçimi, təşəkkür ekranı | |
| watermark | pulsuz şablonda | |

## 12. Bu versiyada OLMAYANLAR

Korporativ tədbirlər; qrup üçün ümumi link; qonaqların şəkil yükləməsi və toy albomu; vizual zal planı; Google/Apple/telefonla giriş; saytda kartla ödəniş; endirim və tərəfdaş kodları; push bildirişləri; WhatsApp API və SMS; admin veb panel; çap üçün adlı PDF dəvətnamə.
