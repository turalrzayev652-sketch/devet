# screens.md — Tətbiq ekranları (QARALAMA)

> **Vəziyyət:** qaralama; §15-dəki qərarlar sahib tərəfindən verilib (2026-10-30). T02 eskizləri olmadan, `PRODUCT.md`, `TASKS.md` və artıq yazılmış backend müqavilələri (miqrasiyalar 001–009, Edge Functions, `test-vectors/`) əsasında yazılıb. Eskizlər gələndə görünüş və yerləşmə uyğunlaşdırılacaq; davranış qaydaları (validasiya, xəta kodları, keçidlər) burada müəyyən olunur. **[SİZ] redaktə edib təsdiqləyin** — təsdiqə qədər T30 açıq qalır.
>
> Bütün mətnlər `/spec/i18n/app.json`-dan (az, ru, en, tr). Android və iOS-da axın, validasiya və xəta mesajları **eynidir** (CLAUDE.md paritet qaydası). Qəbul edilmiş qərarlar §15-dədir.

---

## 0. Naviqasiya xəritəsi

```
[1 Giriş/Qeydiyyat] ──► [2 Tədbirlər] ──► [Tədbir mərkəzi] ─┬─► [4 Şablon kataloqu] ─► [5 Fərdiləşdirmə]
        ▲                    │   │                         ├─► [6 Qonaqlar] ─► [7 Qonaq əlavə et]
        │ çıxış              │   └─► [11b Kodla qoşul]       ├─► [10 Masalar]
        └──── [Parametrlər] ◄┘                             ├─► [8 Göndərmə] (önizləmə → wa.me axını)
                                                           ├─► [9 Statistika]
             [3 Tədbir yaratma] ◄── "+"                    ├─► [11 Ortaq ailə]
                                                           └─► [3 Tədbiri redaktə et]
             [12 Alış] — şablon/limit/göndərmə tələb edəndə istənilən ekrandan açılır (modal)
```

**Tədbir mərkəzi** (eskizdə ayrıca ekran sayılmır): tədbirin başlığı, tarixi, şablon kartı, qısa statistika (göndərildi / gəlir / qonaq sayı / limit) və bölmələrə keçid düymələri. Owner üçün "Tədbiri sil" (təsdiq dialoqu ilə); cohost bunu görmür.

Ümumi qaydalar:
- **Şəbəkə xətası** hər ekranda eyni: `common.error.network` + "Yenidən cəhd et". Yazma əməliyyatı uğursuzdursa, daxil edilmiş məlumat itmir.
- **Yüklənmə:** 300 ms-dən uzun çəkərsə skeleton/indikator.
- **Rol:** owner hər şeyi, cohost silmədən başqa hər şeyi edə bilər (PRODUCT §2). Server bunu RLS ilə təmin edir; tətbiq icazəsiz düymələri göstərmir.

---

## 1. Giriş və qeydiyyat

**Məzmun:** e-poçt, şifrə; "Daxil ol"; "Qeydiyyatdan keç" keçidi; "Şifrəni unutmusunuz?" keçidi. Yalnız e-poçt + şifrə (Google/Apple/telefon yoxdur).

| Hal | Davranış |
| --- | --- |
| Qeydiyyat | e-poçt, şifrə, şifrə təkrarı → Supabase Auth `signUp` → "E-poçtunuzu təsdiqləyin" ekranı (e-poçt təsdiqi açıqdır — T14 təhlükəsizlik qeydi). |
| Giriş | `signInWithPassword` → [2 Tədbirlər]. Sessiya yadda qalır; tətbiq açılanda etibarlı sessiya varsa birbaşa [2]. |
| Şifrə bərpası | e-poçt → `resetPasswordForEmail` → "Link göndərildi" (e-poçt mövcud olmasa da eyni mesaj — hesab varlığı açılmır). Linkdən gələndə yeni şifrə ekranı. |
| Çıxış | Parametrlərdə; təsdiqsiz. |

**Validasiya:** e-poçt formatı (`a@b.c`); şifrə ≥ 6 simvol (§15.1); təkrar eyni olmalıdır. Düymə validasiya keçənə qədər aktiv deyil.

**Xətalar:** səhv e-poçt/şifrə → `auth.error.invalid_credentials`; təsdiqlənməmiş e-poçt → təsdiq ekranı + "Yenidən göndər"; şəbəkə → ümumi.

## 2. Tədbirlər siyahısı

**Məzmun:** istifadəçinin üzvü olduğu tədbirlər (RLS), tarixə görə — gələcəklər yuxarıda; tədbir tarixindən 7 gün keçənlər "Arxiv" bölməsində (§15.2). Kart: növ ikonası, `title_names`, tarix, rol nişanı (owner / ortaq), qısa say ("12/80 göndərildi").

**Düymələr:** "+" → [3]; "Kodla qoşul" → [11b]; Parametrlər (dil, çıxış, hesabı sil — §15.9).

**Boş hal:** illüstrasiya + "İlk tədbirinizi yaradın" + "Yarat" düyməsi + "Dəvət kodum var" keçidi.

**Aşağı çəkib yeniləmə** var.

## 3. Tədbir yaratma (addımlar) və redaktə

Addımlar, irəli/geri, hər addımda validasiya. Son addımda "Yarat" → `events` insert (`created_by` = istifadəçi; trigger onu owner edir) → [Tədbir mərkəzi]. Redaktə eyni formadan istifadə edir (bir səhifədə bölmələr).

| Addım | Sahələr | Validasiya |
| --- | --- | --- |
| 1. Növ | toy / nişan / xınayaxdı / ad günü / yubiley | biri seçilməlidir |
| 2. Adlar | `title_names` ("Aysel və Ramin"), `host_names` (məcburi deyil, "valideyn adları") | `title_names` 1–80 simvol; `host_names` ≤ 120 |
| 3. Tarix və saat | tarix + saat seçici | gələcəkdə olmalıdır; redaktədə də keçmiş tarix seçilə bilməz (§15.4) |
| 4. Məkan | `venue_name`, `venue_address` (məcburi deyil), xəritə linki (`maps_url`) | ad 1–120; link varsa `http(s)`. Linkdən koordinat avtomatik çıxarılır (`test-vectors/maps.json`) və `venue_lat`/`venue_lng`-ə yazılır — Waze düyməsi bunlarla işləyir; qısa link (`maps.app.goo.gl`) koordinatsız qalır (§15.3) |
| 5. Əsas dil | az / ru / en / tr (defolt: tətbiqin dili) | — |
| 6. Masadakılar | "Masadakı digər qonaqları göstər" açar | defolt **bağlı** |

**Xətalar:** şəbəkə — forma məlumatı saxlanır. Redaktədə başqa ailə eyni anda dəyişibsə son yazılan qalır (§15.8).

**Silmə** (yalnız owner): təsdiq dialoqu tədbirin adını göstərir; bütün qonaqlar və statistika silinir.

## 4. Şablon kataloqu

**Məzmun:** `templates` (aktivlər, `sort_order`), kartda `thumbnail_url`, ad (cihaz dilində), nişan: "Pulsuz · 100 qonaq" və ya "Premium · 300 qonaq · {qiymət}" (qiymət mağazadan, koda yazılmır). Tədbir növünə uyğun olmayan şablonlar (template.json `event_types`) gizlədilir.

**Düymələr:** kart → [5] həmin şablonla. Seçilmiş şablon "Seçilib" nişanı ilə.

**Boş hal:** yalnız şəbəkə xətasında mümkündür.

## 5. Şablon fərdiləşdirmə

**Məzmun:** yuxarıda WebView-da canlı önizləmə (`/templates/<id>/index.html?preview=1`, məlumat `postMessage({type:'invite:data'})` ilə — templates.md §6.2); aşağıda bölmələr:
- **Rənglər** — `template.json → css_vars` (`color`), palitra + HEX.
- **Şriftlər** — `css_vars` (`font`) seçimləri.
- **Mətnlər** — `texts` yerləri, hər birinin `max_length` sayğacı.
- **Şəkillər** — 0…`photos.max` (≤ 6): qalereyadan seçim → sıxma (uzun tərəf ≤ 1600 px, JPEG ≤ 2 MB) → `event-media/<event_id>/photos/<uuid>.jpg`; sürüşdürüb sıralama; silmə.
- **Musiqi** — fayl seçimi (mp3/m4a/aac/ogg ≤ 5 MB) → `event-media/<event_id>/music/<uuid>.<ext>`; "Musiqi yoxdur". Müəllif hüququ xəbərdarlığı (istifadə şərtləri §5).
- Önizləmə üçün qonaq: siyahıdan ilk qonaq və ya nümunə ad; dil seçici (4 dil).

**Davranış:** hər dəyişiklik önizləmədə dərhal görünür; "Yadda saxla" → `events.template_id`, `events.customization`. Saxlanmamış dəyişikliklə çıxanda dialoq.

**Pullu şablon alınmayıbsa** (`is_premium` və `!is_paid`): önizləmə və saxlama işləyir, üstdə "Göndərmək üçün alın" zolağı → [12]. Göndərmə [8]-də bloklanır.

**Xətalar:** şəkil > 2 MB sıxmadan sonra da → "Şəkil çox böyükdür"; musiqi > 5 MB → "Fayl 5 MB-dan böyük olmamalıdır"; yükləmə uğursuz → həmin şəkildə "Yenidən cəhd et".

## 6. Qonaqlar siyahısı

**Məzmun:** sətir: göstərilən ad (hitab + "ailəliklə", PRODUCT §8), nəfər, tərəf nişanı, masa, cavab nişanı (gözlənilir / gəlir N / gəlmir), göndərilmə işarəsi. Üstdə: `say / limit` ("84 / 100").

**Filtrlər:** tərəf (bəy / gəlin / ümumi), masa, cavab (gözlənilir / gəlir / gəlmir), göndərilmə (göndərilib / göndərilməyib), "telefonsuz". **Axtarış:** ad və telefon üzrə.

**Düymələr:** "+" → [7]; sətrə toxunma → qonaq redaktəsi (§6.1); uzun basma → çoxlu seçim → "Masa təyin et" (→ [10] seçici), "Tərəf", "Dil", "Sil" (yalnız owner). "İxrac" (T4B).

**Boş hal:** "Qonaq əlavə edin" + üç yol (əl ilə / kontaktlar / Excel).

### 6.1 Qonaq redaktəsi
Sahələr: hitab (müəllim / xanım / bəy / yox), ad, "ailəliklə" açarı, dəvət olunan nəfər, telefon, tərəf, masa, dil (boş = tədbirin dili). Altında önizləmə: göstəriləcək ad seçilmiş dildə.
**Validasiya** (`test-vectors/` ilə eyni): ad 1–80; nəfər 1–50; telefon `phones.json` qaydaları (boş ola bilər); masa ≤ 12 simvol.
Ad/hitab/dil dəyişəndə adlı önizləmə şəkli yenidən yaradılır (T47).

## 7. Qonaq əlavə etmə

Üç yol, bir ekranda tablar:

**7a. Əl ilə** — §6.1 forması; "Yadda saxla və növbəti" (forma təmizlənir, tərəf/masa/dil saxlanır).

**7b. Kontaktlardan** — sistem seçicisi (Android contact picker, iOS `CNContactPickerViewController`), çoxlu seçim; hər kontaktdan ad + mobil nömrə. Bir neçə mobil nömrə varsa seçim dialoqu; tək mobil nömrə avtomatik götürülür; mobil nömrə yoxdursa telefonsuz əlavə olunur (§15.7). Sonra yoxlama siyahısı: hər sətirdə hitab/nəfər/tərəf düzəlişi, xətalı nömrələr qırmızı.

**7c. Excel (.xlsx)** — fayl seçimi → başlıqların avtomatik uyğunlaşdırılması (`excel.json → columns`) → **sütun uyğunlaşdırma ekranı** (hər sütun üçün sahə seçimi, "nəzərə alma") → nəticə: "N qonaq əlavə olunacaq, M sətir xətalıdır" → xətalı sətirlərin siyahısı (sətir nömrəsi + xəta) → "İdxal et". 300 sətir < 5 san.

**Xəta mətnləri** (app.json-a T45-də):

| Kod | Harada |
| --- | --- |
| `empty` / `invalid` / `not_mobile` | telefon (`phones.json`); `not_mobile`: "WhatsApp üçün mobil nömrə lazımdır" |
| `name_column_missing` | Excel başlığı — "Ad sütunu tapılmadı" + uyğunlaşdırma ekranı |
| `name_missing`, `phone_invalid`, `phone_not_mobile`, `salutation_invalid`, `invited_count_invalid`, `with_family_invalid`, `side_invalid`, `table_no_invalid` | Excel sətirləri (`excel.json`) |
| `no_rows` | boş fayl |
| `duplicate_phone` | **xəbərdarlıq**: "Bu nömrə artıq {ad} üçün var" — əlavə etməyə mane olmur |

**Limit:** server `guest_limit_exceeded` (hint `purchase_required`) qaytararsa — toplu idxal **tam** rədd olunur (T13) — dialoq: "Limit doldu ({limit}). N qonaq əlavə olunmadı." + "Limiti artır" → [12] (limit_addon) / pulsuz şablondadırsa "Premium şablon seç" → [4]. İdxal ekranı saxlanır ki, alışdan sonra təkrar edilsin.

## 8. Göndərmə axını

**Ön şərtlər** (biri pozulubsa ekran səbəbi və düyməni göstərir):
1. Şablon seçilib (yoxdursa → [4]).
2. Pullu şablon alınıb (deyilsə → [12]).
3. Ən azı bir telefonlu, göndərilməmiş qonaq var.

**8a. Məcburi önizləmə** (T47): bütün göndəriləcək qonaqların göstəriləcək adlarının siyahısı (qonağın dilində) — səhv ad varsa toxunub düzəltmək olar. Hər qonaq üçün 1200×630 adlı önizləmə şəkli yaradılıb `previews/<kod>.jpg`-ə yüklənir (irəliləmə zolağı; 300 şəkil < 30 san). "Hamısı düzdür, göndərməyə başla".

**8b. Qonaq-qonaq axın:**
- Kart: göstərilən ad, telefon, mesajın önizləməsi (`wa_message.<növ>` qonağın dilində, `{display_name}`, `{title_names}`, `{link}` = `{PUBLIC_BASE_URL}/i/<kod>`).
- "Göndər" → `https://wa.me/<nömrə, + olmadan>?text=<encoded>` açılır. **Göndər düyməsini istifadəçi WhatsApp-da özü basır.**
- Tətbiqə qayıdanda: "Göndərildi?" → **Bəli** (`sent_at = now`, növbəti qonaq) / **Xeyr** (göndərilməmiş qalır) / "Keç".
- Üstdə irəliləmə: "14 / 60"; "Dayandır" istənilən vaxt; növbəti dəfə göndərilməmişlərdən davam edir.
- **Gündəlik xəbərdarlıq:** bu gün göndərilənlərin sayı `app_config.daily_send_warning`-ə (120) çatanda dialoq: WhatsApp hesabı bloklana bilər, sabah davam etmək tövsiyə olunur — **bloklamır**, "Davam et" var.
- Telefonsuz qonaqlar `wa.me` axınında yoxdur; siyahının sonunda ayrıca bölmədə hər biri üçün **"Linki kopyala"** (qonağın adlı linki panoya; ailə onu istədiyi yolla özü göndərir, `sent_at` yalnız "Göndərildi?" təsdiqindən sonra yazılır) (§15.5).
- Göndərilmişə yenidən göndərmək: qonaq redaktəsində "Yenidən göndər".

**Filtr:** "Göndərilməyənlər" [6]-da da var.

## 9. Statistika

| Göstərici | Mənbə |
| --- | --- |
| Göndərildi | `sent_at` dolu |
| Baxdı | `opened_at` dolu (qonaq səhifəni açıb; WhatsApp önizləməsi saymır — T24) |
| Gəlir / Gəlmir / Cavab yoxdur | `rsvp_status` = yes / no / pending |
| Gələcək ümumi nəfər | `rsvp_status = yes` olanların `rsvp_count` cəmi |

**Bölgü:** tərəf üzrə (bəy / gəlin / ümumi) və masa üzrə (hər masa: dəvətli / gəlir / nəfər). Göstəriciyə toxunma → [6] həmin filtrlə. **Aşağı çəkib yeniləmə.** Rəqəmlər seed ilə yoxlanır (T49).

**Boş hal:** heç kimə göndərilməyib → "Dəvət göndərin" → [8].

## 10. Masalar

**Məzmun:** masaların siyahısı (`table_no` qiymətləri, təbii sıralama: 1, 2, 10, VIP-1): hər masada qonaq və nəfər sayı; "Masasız" qrupu.

**Düymələr:** masaya toxunma → həmin masanın qonaqları (çıxarmaq, başqa masaya köçürmək); "Toplu təyin et" → qonaq seçimi + masa nömrəsi (yeni və ya mövcud); "Masadakıları qonaqlara göstər" açarı (`events.show_tablemates`, defolt bağlı, izahat: "Qonaq öz dəvətnaməsində eyni masadakıların adlarını görəcək").

**Validasiya:** masa nömrəsi 1–12 simvol, boşluqlar kəsilir.

**Boş hal:** "Qonaqlara masa təyin edin".

## 11. Ortaq ailə

**Owner görünüşü:**
- Ortaq idarəçi yoxdursa: "İkinci ailəni dəvət edin" — e-poçt + tərəf (bəy / gəlin / ümumi) → `create_cohost_invite` → kod (8 simvol) böyük şriftlə, "Paylaş" (sistem paylaşma menyusu: kod + tətbiq yükləmə linki) və "Müddət: 14 gün". Yeni dəvət köhnəni əvəz edir.
- Varsa: e-poçt, tərəf, "Çıxar" (təsdiqlə; owner cohost-u silə bilər).

**Cohost görünüşü:** owner-in e-poçtu, öz tərəfi; dəvət yaratmaq yoxdur.

**Xətalar (`create_cohost_invite`):** `not_owner` (cohost üçün düymə görünmür), `invalid_email`, `cohost_exists` ("Tədbirin artıq ortaq idarəçisi var").

### 11b. Kodla qoşul
[2]-dən: 8 simvollu kod (böyük hərf avtomatik, boşluqlar silinir) → `accept_cohost_invite` → uğurlu → həmin [Tədbir mərkəzi].

| Kod | Mesaj |
| --- | --- |
| `not_found` | Kod tapılmadı və ya artıq istifadə olunub |
| `expired` | Dəvətin müddəti bitib — owner-dən yenisini istəyin |
| `email_mismatch` | Dəvət başqa e-poçt üçündür ({hesabınızın e-poçtu} ilə daxil olmusunuz) |
| `already_member` | Siz artıq bu tədbirin üzvüsünüz |
| `cohost_exists` | Tədbirin artıq ortaq idarəçisi var |
| `not_authenticated` | (sessiya bitib) → [1] |

## 12. Alış ekranı (modal)

**Açılır:** pullu şablon seçilib, amma alınmayıb ([5], [8]); limit dolub ([7]).

**Məzmun:** nə alınır və nə verir — "Premium şablon: watermark yoxdur, 300 qonaq" və ya "+200 qonaq"; qiymət mağazadan (lokal valyuta); "Bir tədbir üçün" qeydi; "Al"; "Alışları bərpa et"; istifadə şərtləri linki.

**Axın:** "Al" → Google Play Billing / StoreKit 2 (Android: `obfuscatedAccountId = userId`, `obfuscatedProfileId = eventId`; iOS: `appAccountToken = userId` — T4C müqaviləsi) → mağaza təsdiqi → `verify-purchase` → uğurlu: ekran bağlanır, tədbir yenilənir (`is_paid`, limit), "Alış uğurlu oldu".
**Gözləmədə ödəniş** (Google pending): "Ödəniş təsdiq gözləyir" — tətbiq açılanda təkrar yoxlanır.
**Bərpa:** mağazanın təsdiqlənmiş, amma serverdə yazılmamış alışları `verify-purchase`-ə yenidən göndərilir (idempotent).

**Xətalar (`verify-purchase`):**

| Kod | Mesaj / davranış |
| --- | --- |
| istifadəçi ləğv etdi (mağaza) | heç nə göstərilmir |
| `purchase_pending` | gözləmədə (yuxarı) |
| `purchase_cancelled`, `purchase_not_found` | "Alış tamamlanmadı" |
| `purchase_mismatch`, `revoked`, `refunded`, `transaction_used` | "Bu alış bu tədbir üçün istifadə edilə bilməz" + dəstək |
| `template_mismatch` | "Alış seçilmiş şablona uyğun deyil" — şablon dəyişibsə |
| `unknown_product`, `invalid_request` | "Bu məhsul hazırda alına bilməz" (tətbiq/məhsul konfiqurasiyası xətası — loglanır) |
| `test_purchase_not_allowed` | "Test alışları qəbul edilmir" (yalnız test hesablarında görünə bilər) |
| `not_member` | tədbirə çıxış yoxdur → [2] |
| `unauthorized` | → [1] |
| `store_unavailable`, `store_not_configured`, şəbəkə | "Alışınız qorunub, bir az sonra yenidən yoxlanacaq" + təkrar (alış mağazada qalır, bərpa ilə yazılır) |

---

## 13. Rol cədvəli

| Əməliyyat | Owner | Cohost |
| --- | --- | --- |
| Tədbiri redaktə | ✓ | ✓ |
| Tədbiri silmək | ✓ | — |
| Qonaq əlavə / redaktə | ✓ | ✓ |
| Qonaq silmək | ✓ | — |
| Göndərmə, statistika, masalar | ✓ | ✓ |
| Alış | ✓ | ✓ |
| Ortaq ailə dəvəti / çıxarmaq | ✓ | — |

## 14. Ekran → backend (T31 üçün ilkin)

| Ekran | Çağırışlar |
| --- | --- |
| 1 | Supabase Auth: `signUp`, `signInWithPassword`, `resetPasswordForEmail`, `updateUser`, `signOut` |
| 2 | `events` select (RLS), `event_members` (rol) |
| 3 | `events` insert/update/delete |
| 4 | `templates` select; mağazadan qiymət |
| 5 | Storage `event-media` upload/delete; `events` update (`template_id`, `customization`) |
| 6, 7 | `guests` select/insert/update/delete; `event_guest_limit(event_id)` |
| 8 | `guests` update (`sent_at`, `preview_path`); Storage `previews` upload; `app_config.daily_send_warning` |
| 9 | `guests` select (aqreqat tətbiqdə) |
| 10 | `guests` update (`table_no`); `events.show_tablemates` |
| 11 | `create_cohost_invite`, `accept_cohost_invite`, `event_members` select/delete, `event_invites` select |
| 12 | mağaza SDK + `verify-purchase` Edge Function |

## 15. Qəbul edilmiş qərarlar (2026-10-30)

| # | Mövzu | Qərar |
| --- | --- | --- |
| 1 | Şifrə | ≥ 6 simvol (Supabase defoltu). |
| 2 | Tədbir statusu | Avtomatik: yaradılanda `draft`; ilk qonağa `sent_at` yazılanda server trigger-i `active` edir (miqrasiya 010); tədbirdən 7 gün sonra siyahıda "Arxiv" bölməsinə düşür (`archived` tətbiqdə hesablanır, sahə dəyişmir). |
| 3 | Məkan | Google Maps linki + ünvan; koordinat linkdən çıxarılır (`maps.json` vektorları). Xəritə SDK yoxdur. |
| 4 | Tarix redaktəsi | Keçmiş tarix seçilə bilməz (yaratmada da, redaktədə də). |
| 5 | Telefonsuz qonaqlar | "Linki kopyala"; tətbiq özü heç nə göndərmir. |
| 6 | Mesaj dili | Həmişə qonağın dili (`guests.lang`, boşdursa `events.default_lang`). |
| 7 | Kontaktın bir neçə nömrəsi | Bir neçə mobil nömrə varsa seçim dialoqu; tək olanda avtomatik. |
| 8 | Eyni anda redaktə | Son yazılan qalır. |
| 9 | Hesabı silmək | Parametrlərdə "Hesabı sil": owner olduğu tədbirlər silinir, cohost olduğu tədbirlərdən çıxarılır. Backend ayrıca tapşırıq kimi yazılır (TASKS.md T17). |
