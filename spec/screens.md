# screens.md — Tətbiq ekranları (QARALAMA)

> **Vəziyyət:** qaralama, HTML prototipə uyğunlaşdırılıb (2026-10-31). Görünüş və yerləşmə: `design/prototype/` (13 ekran, 106 hal) və `design/components.html`; tokenlər: `spec/design.md`. Bu sənəd **davranışı** müəyyən edir (validasiya, xəta kodları, keçidlər, backend çağırışları); prototip ilə ziddiyyət olarsa bu sənəd əsasdır. §15-dəki qərarlar sahib tərəfindən verilib (2026-10-30). **[SİZ] təsdiqləyin** — təsdiqə qədər T30 açıq qalır.
>
> Bütün mətnlər `/spec/i18n/app.json`-dan (az, ru, en, tr). Android və iOS-da axın, validasiya və xəta mesajları **eynidir** (CLAUDE.md paritet qaydası). Qəbul edilmiş qərarlar §15-dədir.

---

## 0. Naviqasiya xəritəsi

```
[1 Giriş/Qeydiyyat] ──► [2 Tədbirlərim] ──(karta toxun)──► Tədbir daxilində, alt naviqasiya:
        ▲                 │  │  │                         ┌──────────────┬─────────────┬──────────────┬──────────────┐
        │ çıxış           │  │  └► [11b Kodla qoşul]      │ 6 Qonaqlar   │ 8 Göndər    │ 9 Statistika │ 12a Daha çox │
        └── [12b Parametrlər]  └► [3 Tədbir yaratma] ──► uğur ──► [4 Şablonlar] ──► [5 Fərdiləşdirmə] ──► [7 Qonaq əlavə et]
                                                         6 ──► [7]          12a ──► [5] · [10 Masalar] · [11 Ortaq ailə] · [3 Redaktə] · [12 Alış] · ixrac · sil
             [12 Alış] — şablon/limit/göndərmə tələb edəndə istənilən ekrandan (tam ekran, "×" ilə bağlanır)
```

**Alt naviqasiya** (yalnız tədbir daxilində, DESIGN_PROMPT §3): **Qonaqlar · Göndər · Statistika · Daha çox**. Tədbirlər siyahısı və giriş bu naviqasiyadan kənardadır. Tədbir kartına toxunanda **Qonaqlar** açılır. Android: `NavigationBar`; iOS: tab bar.

**Klikləmə axını (prototip):** Giriş → Tədbirlərim → Tədbir yaratma (6 addım) → Şablonlar → Fərdiləşdirmə → Qonaq əlavə et (Excel) → Qonaqlar → Göndərmə → Statistika.

| Ekran | Prototip faylı | Hallar |
| --- | --- | --- |
| 1 Giriş | `01-giris.html` | 9 |
| 2 Tədbirlərim | `02-tedbirler.html` | 6 |
| 3 Tədbir yaratma | `03-tedbir-yarat.html` | 13 |
| 4 Şablonlar | `04-sablonlar.html` | 6 |
| 5 Fərdiləşdirmə | `05-ferdilesdir.html` | 10 |
| 6 Qonaqlar | `06-qonaqlar.html` | 12 |
| 7 Qonaq əlavə et | `07-qonaq-elave.html` | 9 |
| 8 Göndərmə | `08-gonderme.html` | 10 |
| 9 Statistika | `09-statistika.html` | 5 |
| 10 Masalar | `10-masalar.html` | 7 |
| 11 Ortaq ailə | `11-ortaq-aile.html` | 11 |
| 12 Alış | `12-alis.html` | 6 |
| 12a Daha çox | `13-daha-cox.html` | 2 |
| 12b Parametrlər | — (prototipdə yoxdur, §12b) | — |

Ümumi qaydalar:
- **Şəbəkə xətası** hər ekranda eyni: `common.error.network` + "Yenidən cəhd et". Yazma əməliyyatı uğursuzdursa, daxil edilmiş məlumat itmir.
- **Yüklənmə:** 300 ms-dən uzun çəkərsə skeleton/indikator.
- **Rol:** owner hər şeyi, cohost silmədən başqa hər şeyi edə bilər (PRODUCT §2). Server bunu RLS ilə təmin edir; tətbiq icazəsiz düymələri göstərmir.

---

## 1. Giriş və qeydiyyat

**Prototip:** [`design/prototype/01-giris.html`](../design/prototype/01-giris.html)

**Məzmun:** yuxarıda botanik xətt rəsmi, loqo və "Devet" (serif), "Xoş gəlmisiniz"; e-poçt, şifrə (göstər/gizlət); "Daxil ol"; "Şifrəni unutmusunuz?"; "Hesabınız yoxdur? Qeydiyyatdan keçin". Yalnız e-poçt + şifrə (Google/Apple/telefon yoxdur). Oflayn: yuxarıda zolaq, "Daxil ol" bağlı. Yüklənmə: spinner düymənin içində.

| Hal | Davranış |
| --- | --- |
| Qeydiyyat | ad (`profiles.display_name`), e-poçt, şifrə, şifrə təkrarı, "İstifadə şərtləri və məxfilik siyasəti ilə razıyam" (məcburi) → Supabase Auth `signUp` → "E-poçtunuzu təsdiqləyin" ekranı (e-poçt təsdiqi açıqdır — T14 təhlükəsizlik qeydi). |
| Giriş | `signInWithPassword` → [2 Tədbirlər]. Sessiya yadda qalır; tətbiq açılanda etibarlı sessiya varsa birbaşa [2]. |
| Şifrə bərpası | e-poçt → `resetPasswordForEmail` → "Link göndərildi" (e-poçt mövcud olmasa da eyni mesaj — hesab varlığı açılmır). Linkdən gələndə yeni şifrə ekranı. |
| Çıxış | Parametrlərdə; təsdiqsiz. |

**Validasiya:** e-poçt formatı (`a@b.c`); şifrə ≥ 6 simvol (§15.1); təkrar eyni olmalıdır; qeydiyyatda şərtlər işarələnməlidir. Düymə validasiya keçənə qədər aktiv deyil.

**Xətalar:** səhv e-poçt/şifrə → `auth.error.invalid_credentials` (sahənin altında; hansı sahənin səhv olduğu açıqlanmır); e-poçt artıq qeydiyyatdadır → "Bu e-poçtla hesab artıq var"; təsdiqlənməmiş e-poçt → təsdiq ekranı + "Yenidən göndər"; şəbəkə → ümumi.

## 2. Tədbirlərim

**Prototip:** [`design/prototype/02-tedbirler.html`](../design/prototype/02-tedbirler.html)

**Məzmun:** böyük serif başlıq "Tədbirlərim", sağ üstdə profil ikonu → [12b]. İstifadəçinin üzvü olduğu tədbirlər (RLS), tarixə görə — gələcəklər yuxarıda; tədbir tarixindən 7 gün keçənlər "Arxiv (N)" keçidinin altında (§15.2). **Kart:** üstdə şablon miniatürü, rol nişanı (Sahib / Ortaq) və "…" menyusu; növ çipi ("Toy"), tədbir adı (serif), "tarix · məkan", mini statistika ("121 gəlir · 59 cavab yoxdur").

**Düymələr:** karta toxun → [6]; aşağıda "Kodla qoşul" → [11b] və "Yeni tədbir" → [3]; "…" → Redaktə et ([3]), Arxivlə, Sil (yalnız sahib; tədbirin adı və qonaq sayı ilə təsdiq dialoqu — geri qaytarılmır).

**Boş hal:** illüstrasiya + "İlk tədbirinizi yaradın" + "Dəvətnamə hazırlamaq 10 dəqiqə çəkir" + "Tədbir yarat" + "Kodla qoşul". **Yüklənmə:** kart skeletonları. **Xəta:** zolaq + "Yenidən cəhd et", keşdəki kartlar görünür.

**Aşağı çəkib yeniləmə** var.

## 3. Tədbir yaratma (addımlar) və redaktə

**Prototip:** [`design/prototype/03-tedbir-yarat.html`](../design/prototype/03-tedbir-yarat.html)

Üstdə geri və "×", **addım göstəricisi "2/6"** nazik qızılı zolaqla; hər addımda bir sual (serif başlıq); aşağıda "İrəli" (addım düzgün olana qədər bağlı) və "Geri". Son addımda "Tədbiri yarat" → `events` insert (`created_by` = istifadəçi; trigger onu owner edir) → **uğur ekranı** "Tədbir yaradıldı" (bir dəfəlik parıltı) → "Şablon seç" → [4]. Redaktə eyni sahələrdən istifadə edir (bir səhifədə bölmələr, "Daha çox" → "Tədbiri redaktə et").

| Addım | Sahələr | Validasiya |
| --- | --- | --- |
| 1. Növ | 5 böyük kart ikonla: toy / nişan / xınayaxdı / ad günü / yubiley | biri seçilməlidir |
| 2. Adlar | `title_names` ("Aysel və Ramin"), `host_names` (məcburi deyil, "valideyn adları") | `title_names` 1–80 simvol; `host_names` ≤ 120 |
| 3. Tarix və saat | tarix + saat seçici | gələcəkdə olmalıdır; redaktədə də keçmiş tarix seçilə bilməz (§15.4) |
| 4. Məkan | `venue_name`, `venue_address` (məcburi deyil), xəritə linki (`maps_url`) + "Yapışdır" düyməsi; köməkçi mətn: "Google Maps → Paylaş → Linki kopyala"; nəticə zolağı: "Koordinat tapıldı" (yaşıl) və ya qısa link xəbərdarlığı (sarı) | ad 1–120; link varsa `http(s)`. Linkdən koordinat avtomatik çıxarılır (`test-vectors/maps.json`) və `venue_lat`/`venue_lng`-ə yazılır — Waze düyməsi bunlarla işləyir; qısa link (`maps.app.goo.gl`) koordinatsız qalır (§15.3) |
| 5. Əsas dil | 4 kart öz adları ilə: Azərbaycan, Русский, English, Türkçe (defolt: tətbiqin dili); "Hər qonaq üçün sonradan ayrıca dil seçə bilərsiniz" | — |
| 6. Masadakılar | "Masadakı digər qonaqları göstər" açar + qonaq səhifəsinin masa blokunun mini önizləməsi (açıq/bağlı) | defolt **bağlı** |

**Xətalar:** şəbəkə — forma məlumatı saxlanır, xəta zolağı + "Yenidən cəhd et"; "Tədbir yaradılır…" yüklənmə halı. Redaktədə başqa ailə eyni anda dəyişibsə son yazılan qalır (§15.8).

**Silmə** (yalnız owner) [2] və [12a]-dan: təsdiq dialoqu tədbirin adını göstərir; bütün qonaqlar və statistika silinir.

## 4. Şablon kataloqu

**Prototip:** [`design/prototype/04-sablonlar.html`](../design/prototype/04-sablonlar.html)

**Məzmun:** başlıq "Şablon seçin"; filtr çipləri **Hamısı · Pulsuz · Premium**; 2 sütunlu şəbəkə, telefon formalı hündür kartlar. `templates` (aktivlər, `sort_order`), kartda `thumbnail_url`, ad (cihaz dilində), nişan: "Pulsuz · 100 qonaq" və ya "Premium · 300 qonaq · {qiymət}" (qiymət mağazadan, koda yazılmır). Tədbir növünə uyğun olmayan şablonlar (template.json `event_types`) gizlədilir.

**Düymələr:** kart → tam ekran önizləmə (animasiyalı şablon, WebView `?preview=1`): pulsuzda "Bu şablonu seç" → [5]; premiumda qiymət + "Önizlə — almadan əvvəl fərdiləşdirə bilərsiniz" → [5]. Seçilmiş şablon kartında ✓.

**Boş hal:** yalnız şəbəkə xətasında mümkündür (xəta zolağı + təkrar). **Yüklənmə:** kart skeletonları.

## 5. Şablon fərdiləşdirmə

**Prototip:** [`design/prototype/05-ferdilesdir.html`](../design/prototype/05-ferdilesdir.html)

**Layout:** üst panel (geri, "Fərdiləşdir", "Yadda saxla"); **ekranın yuxarı ~55%-i canlı önizləmə** — WebView (`/templates/<id>/index.html?preview=1`, məlumat `postMessage({type:'invite:data'})` ilə — templates.md §6.2), altında "Qonaq kimi bax" (ilk qonağın adı və hitabı ilə) və AZ/RU/EN/TR seçicisi; **aşağıda sürüşdürülən sheet** (45% ↔ 85%) tablarla — Rəng · Şrift · Mətn · Şəkil · Musiqi:
- **Rəng** — 5–6 hazır palitra (ikirəngli dairələr) + öz rəngin (HEX); `template.json → css_vars` (`color`).
- **Şrift** — 3–4 cüt, "Aa" nümunəsi və `Əə Ğğ İı Жж` ilə; `css_vars` (`font`) + `fonts`. Şablon şriftləri `design/font-check.html` ilə yoxlanmış olmalıdır.
- **Mətn** — `texts` yerləri (başlıq, dəvət cümləsi, son söz), hər birinin `max_length` sayğacı.
- **Şəkil** — 3 sütunlu şəbəkə, nömrəli, "×" ilə silmə, yüklənmə zolağı, xəta halında "toxunun"; 0…`photos.max` (≤ 6): qalereyadan seçim → sıxma (uzun tərəf ≤ 1600 px, JPEG ≤ 2 MB) → `event-media/<event_id>/photos/<uuid>.jpg`; sürüşdürüb sıralama; silmə.
- **Musiqi** — kitabxanadan seçim (oynat/dayandır düyməsi, dalğa göstəricisi), "Öz musiqini yüklə", "Musiqi olmasın"; qeyd "Musiqi qonaq toxunanda başlayır"; fayl seçimi (mp3/m4a/aac/ogg ≤ 5 MB) → `event-media/<event_id>/music/<uuid>.<ext>`; "Musiqi yoxdur". Müəllif hüququ xəbərdarlığı (istifadə şərtləri §5).
- Önizləmə üçün qonaq: siyahıdan ilk qonaq və ya nümunə ad; dil seçici (4 dil).

**Davranış:** hər dəyişiklik önizləmədə dərhal görünür; "Yadda saxla" → `events.template_id`, `events.customization` → uğur zolağı + "Növbəti: qonaq əlavə et" → [7]. Saxlanmamış dəyişikliklə çıxanda dialoq. Önizləmə yüklənənə qədər skeleton.

**Pullu şablon alınmayıbsa** (`is_premium` və `!is_paid`): önizləmə və saxlama işləyir, sheet-in üstündə qızılı zolaq "Premium şablon — göndərmək üçün alın" + "Al" → [12]. Göndərmə [8]-də bloklanır.

**Xətalar:** şəkil > 2 MB sıxmadan sonra da → "Şəkil çox böyükdür"; musiqi > 5 MB → "Fayl 5 MB-dan böyük olmamalıdır"; yükləmə uğursuz → həmin şəkildə "Yenidən cəhd et".

## 6. Qonaqlar siyahısı

**Prototip:** [`design/prototype/06-qonaqlar.html`](../design/prototype/06-qonaqlar.html)

**Layout:** üst panel (geri → [2], tədbirin adı və tarixi, "…"); serif başlıq "Qonaqlar" + **sayğac halqası** "84/100" (≥ 95% — qızılı `goldStrong` halqa + "Limitə N qonaq qalıb" nişanı; 100% — qırmızı + "Limit doldu — artırın" → [12]); axtarış "Qonaq axtar"; üfüqi filtr çipləri saylarla; qonaq sətirləri; sağ altda **"Qonaq əlavə et"** (FAB) → [7]; alt naviqasiya.

**Sətir:** göstərilən ad (hitab + "ailəliklə", PRODUCT §8), ikinci sətir "4 nəfər · Masa 12 · Bəy tərəfi", sağda **status pill** — Gəlir N / Gəlmir / Baxdı / Cavab yoxdur / Göndərilməyib (hesablanma: design.md §2.2).

**Filtr çipləri:** Hamısı · Bəy tərəfi · Gəlin tərəfi · Gəlir · Gəlmir · Cavab yoxdur · Göndərilməyib · Masasız (hər birində say). **Axtarış:** ad və telefon üzrə; nəticə yoxdursa boş hal "«…» üzrə qonaq tapılmadı".

**Hərəkətlər:** sətrə toxunma → redaktə sheet-i (§6.1); sola sürüşdürmə → Redaktə / Sil (Sil yalnız owner); uzun basma → çoxlu seçim (dairəvi checkbox, "N seçildi") + alt panel **Masa təyin et · Tərəf · Sil** (Sil yalnız owner). İxrac: [9] və [12a].

**Boş hal:** "Hələ qonaq yoxdur" + üç düymə: "Əl ilə", "Kontaktlardan", "Excel-dən" → [7] uyğun tabda. **Yüklənmə:** skeleton sətirlər. **Xəta:** zolaq + "Yenidən cəhd et", keşdəki siyahı görünür.

### 6.1 Qonaq redaktəsi
Sahələr: hitab (müəllim / xanım / bəy / yox), ad, "ailəliklə" açarı, dəvət olunan nəfər, telefon, tərəf, masa, dil (boş = tədbirin dili). Hitab seqmentli seçicidir (Müəllim / Xanım / Bəy / Yox), nəfər stepper-dir. Altında önizləmə "Dəvətnamədə belə görünəcək": salamlama ilə tam ad seçilmiş dildə ("Hörmətli Elçin müəllim və ailəsi!"). Aşağıda "Yadda saxla" və "Qonağı sil" (yalnız owner).
**Validasiya** (`test-vectors/` ilə eyni): ad 1–80; nəfər 1–50; telefon `phones.json` qaydaları (boş ola bilər); masa ≤ 12 simvol.
Ad/hitab/dil dəyişəndə adlı önizləmə şəkli yenidən yaradılır (T47).

## 7. Qonaq əlavə etmə

**Prototip:** [`design/prototype/07-qonaq-elave.html`](../design/prototype/07-qonaq-elave.html)

Başlıq "Qonaq əlavə et"; üç yol seqmentli tablarla — **Əl ilə · Kontaktlar · Excel**:

**7a. Əl ilə** — §6.1 forması, telefon sahəsində `+994` prefiksi; əsas düymə "Yadda saxla və növbəti" (forma təmizlənir, tərəf/masa/dil saxlanır, bildiriş "… əlavə olundu"), ikinci "Yadda saxla" → [6].

**7b. Kontaktlardan** — sistem seçicisi (Android contact picker, iOS `CNContactPickerViewController`), çoxlu seçim; hər kontaktdan ad + mobil nömrə. Bir neçə mobil nömrə varsa seçim dialoqu; tək mobil nömrə avtomatik götürülür; mobil nömrə yoxdursa telefonsuz əlavə olunur (§15.7). Əvvəl izah ekranı + "Kontaktları seç"; sonra siyahı: hər sətirdə hitab çipləri və nəfər stepper-i, problemli nömrə sarı mətnlə ("2 nömrə — seçin"); düymə "N qonaq əlavə et".

**7c. Excel (.xlsx)** — yükləmə kartı "Excel faylı seçin (.xlsx)" + "Nümunə faylı yüklə" (nümunə `.xlsx` T45-də hazırlanır) → fayl seçimi → başlıqların avtomatik uyğunlaşdırılması (`excel.json → columns`) → **sütun uyğunlaşdırma ekranı** (solda "A: Ad Soyad", sağda sahə seçicisi və ya "Nəzərə alma"; altında ilk 5 sətrin önizləməsi) → **yoxlama xülasəsi**: "248 sətir hazırdır · 6 sətirdə xəta" (zolaqla), təkrar nömrə xəbərdarlığı, xətalı sətirlərin siyahısı ("Sətir 14: telefon nömrəsi yanlışdır") → "248 qonağı idxal et" → irəliləmə ("İdxal olunur… 140 / 248") → [6]. Fayl oxunmadısa: xəta zolağı (".xlsx olmalıdır"). 300 sətir < 5 san.

**Xəta mətnləri** (app.json-a T45-də):

| Kod | Harada |
| --- | --- |
| `empty` / `invalid` / `not_mobile` | telefon (`phones.json`); `not_mobile`: "WhatsApp üçün mobil nömrə lazımdır" |
| `name_column_missing` | Excel başlığı — "Ad sütunu tapılmadı" + uyğunlaşdırma ekranı |
| `name_missing`, `phone_invalid`, `phone_not_mobile`, `salutation_invalid`, `invited_count_invalid`, `with_family_invalid`, `side_invalid`, `table_no_invalid` | Excel sətirləri (`excel.json`) |
| `no_rows` | boş fayl |
| `duplicate_phone` | **xəbərdarlıq**: "Bu nömrə artıq {ad} üçün var" — əlavə etməyə mane olmur |

**Limit:** server `guest_limit_exceeded` (hint `purchase_required`) qaytararsa — toplu idxal **tam** rədd olunur (T13) — sheet: "Limit doldu: 100/100", izah (heç biri əlavə olunmadı) + "Premium şablona keç — 300 qonaq" → [4] Premium filtri / "Limiti artır: +200 qonaq" → [12] limit artırma. İdxal ekranı saxlanır ki, alışdan sonra təkrar edilsin.

## 8. Göndərmə axını

**Ön şərtlər** (biri pozulubsa ekran səbəbi və düyməni göstərir):
1. Şablon seçilib (yoxdursa → [4]).
2. Pullu şablon alınıb (deyilsə → [12]).
3. Ən azı bir telefonlu, göndərilməmiş qonaq var.

**Prototip:** [`design/prototype/08-gonderme.html`](../design/prototype/08-gonderme.html)

**8a. Adları yoxlayın — məcburi** (T47): başlıq "Adları yoxlayın"; xəbərdarlıq çipləri ("Telefon yoxdur: N", "Boş ad: N"); bütün göndəriləcək qonaqların siyahısı — hər sətirdə adlı önizləmə şəklinin miniatürü, salamlama ilə tam ad qonağın dilində ("Hörmətli Elçin müəllim və ailəsi!") və telefon; telefonsuz sətirlər sarı fonla. Sətrə toxunub düzəltmək olar. Hər qonaq üçün 1200×630 adlı önizləmə şəkli yaradılıb `previews/<kod>.jpg`-ə yüklənir — "Hamısı düzgündür — başla" → yüklənmə halı "Adlı önizləmə şəkilləri hazırlanır" + "140 / 212 şəkil" (300 şəkil < 30 san) → avtomatik 8b. Yükləmə xətası: zolaq + "Yenidən cəhd et" (hazır olanlar saxlanılır).

**8b. Qonaq-qonaq axın:**
- Üstdə irəliləmə "45 / 212 göndərildi" (qızılı zolaq). Mərkəzdə **böyük kart**: inisiallı avatar, göstərilən ad, telefon, dil nişanı, **WhatsApp önizləməsi** (og:image + og:title — qonağın görəcəyi kimi), mesajın mətni (`wa_message.<növ>` qonağın dilində, `{display_name}`, `{title_names}`, `{link}` = `{PUBLIC_BASE_URL}/i/<kod>`).
- Aşağıda əsas düymə **"WhatsApp-da göndər"** (WhatsApp işarəsi brend düyməsinin içində) və "Keç" → `https://wa.me/<nömrə, + olmadan>?text=<encoded>` açılır. **Göndər düyməsini istifadəçi WhatsApp-da özü basır.**
- Tətbiqə qayıdanda sheet **"Göndərildi?"** → **"Bəli, növbəti"** (`sent_at = now`, növbəti qonaq) / **"Xeyr, yenidən"** (göndərilməmiş qalır).
- Geri ilə istənilən vaxt dayandırmaq olar; növbəti dəfə göndərilməmişlərdən davam edir.
- **Gündəlik xəbərdarlıq:** bu gün göndərilənlərin sayı `app_config.daily_send_warning`-ə (120) çatanda kartın üstündə yumşaq zolaq: "Bu gün çox mesaj göndərdiniz. Nömrənizin məhdudlaşdırılmaması üçün qalanını sabah davam etdirin." — **bloklamır**, "Yenə də davam et" var.
- Telefonsuz qonaqlar `wa.me` axınında yoxdur; siyahının sonunda ayrıca bölmədə hər biri üçün **"Linki kopyala"** (qonağın adlı linki panoya; ailə onu istədiyi yolla özü göndərir, `sent_at` yalnız "Göndərildi?" təsdiqindən sonra yazılır) (§15.5).
- Göndərilmişə yenidən göndərmək: qonaq redaktəsində "Yenidən göndər".

**Tamamlandı:** "Bütün dəvətlər göndərildi" (bir dəfəlik parıltı) + "Statistikaya bax" → [9] + "Telefonu olmayan qonaqlar (N)".

**Digər hallar:** premium alınmayıb ("Premium şablonu alın" + "Al" → [12] / "Pulsuz şablon seç" → [4]); göndəriləcək qonaq yoxdur (boş hal + "Qonaq əlavə et"). "Göndərilməyib" filtri [6]-da da var.

## 9. Statistika

**Prototip:** [`design/prototype/09-statistika.html`](../design/prototype/09-statistika.html)

**Layout:** serif başlıq "Statistika" + tədbir/tarix; **5 kart** şəbəkədə (Göndərildi, Baxdı, Gəlir — geniş kart, "387 nəfər" vurğulanır —, Gəlmir, Cavab yoxdur), hər biri status rəngi + mətnli pill ilə; **huni** "Dəvətlərin yolu" (göndərildi → baxdı → cavab verdi, hər birində "N · göndərilənlərin %-i"); **tərəflər üzrə gələnlər** (bölünmüş zolaq + legend); **masalar üzrə** ("Masa 12 — 8/10 nəfər təsdiqləyib"); "Son yenilənmə: 2 dəq əvvəl"; "Excel / PDF ixrac et" → sheet (T4B).

| Göstərici | Mənbə |
| --- | --- |
| Göndərildi | `sent_at` dolu |
| Baxdı | `opened_at` dolu (qonaq səhifəni açıb; WhatsApp önizləməsi saymır — T24) |
| Gəlir / Gəlmir / Cavab yoxdur | `rsvp_status` = yes / no / pending |
| Gələcək ümumi nəfər | `rsvp_status = yes` olanların `rsvp_count` cəmi |

**Bölgü:** tərəf üzrə (bəy / gəlin / ümumi) və masa üzrə (hər masa: dəvətli / gəlir / nəfər). Göstəriciyə toxunma → [6] həmin filtrlə. **Aşağı çəkib yeniləmə.** Rəqəmlər seed ilə yoxlanır (T49).

**Boş hal:** "Hələ heç kimə göndərilməyib" + "Göndərməyə başla" → [8]. **Yüklənmə:** kart skeletonları. **Xəta:** zolaq + "Yenidən cəhd et", son rəqəmlər görünür.

## 10. Masalar

**Prototip:** [`design/prototype/10-masalar.html`](../design/prototype/10-masalar.html) (açılış [12a]-dan)

**Layout:** yuxarıda açar kartı "Masadakıları göstər" + izah + qonaq üçün mini önizləmə ("Masanız 12 · Masada: …"); masa kartları ("Masa 12 · 4 qonaq · 10 nəfər", toxunanda adlar açılır); "Masasız qonaqlar: N" sətri → [6] Masasız filtri; aşağıda əsas düymə **"Toplu təyin et"**.

**Məzmun:** masaların siyahısı (`table_no` qiymətləri, təbii sıralama: 1, 2, 10, VIP-1): hər masada qonaq və nəfər sayı; "Masasız" qrupu.

**Düymələr:** masaya toxunma → həmin masanın qonaqları (çıxarmaq, başqa masaya köçürmək); "Toplu təyin et" → (1) qonaq seçimi checkbox-larla, filtr çipləri (Masasız / Bəy tərəfi / Gəlin tərəfi) → (2) masa nömrəsi: böyük sahə + mövcud masaların çipləri → "N qonağı Masa X-ə təyin et" → siyahıya qayıdış və bildiriş; "Masadakıları qonaqlara göstər" açarı (`events.show_tablemates`, defolt bağlı, izahat: "Qonaq öz dəvətnaməsində eyni masadakıların adlarını görəcək").

**Validasiya:** masa nömrəsi 1–12 simvol, boşluqlar kəsilir.

**Boş hal:** "Qonaqlara masa təyin edin" (vizual zal planı bu versiyada yoxdur). **Yüklənmə / Xəta:** skeleton / zolaq + "Yenidən cəhd et".

## 11. Ortaq ailə

**Owner görünüşü:**
**Prototip:** [`design/prototype/11-ortaq-aile.html`](../design/prototype/11-ortaq-aile.html) (açılış [12a]-dan)

- Ortaq idarəçi yoxdursa: izah "Digər tərəf qonaqlarını özü əlavə edə və göndərə bilər…"; e-poçt + tərəf (**Bəy tərəfi / Gəlin tərəfi**) → "Dəvət yarat" → `create_cohost_invite` → kod kartı: kod **monospace, 4+4 qruplu** ("K7D2 M9QX"), "Kopyala", "Paylaş" (sistem menyusu: kod + tətbiq linki), "14 gün etibarlıdır · {e-poçt} üçün". "Yeni dəvət (köhnə kod etibarsız olur)" köhnəni əvəz edir.
- Üzvlər siyahısı: ad, rol (Sahib / Ortaq), tərəf.
- Ortaq varsa: onun sətrində "Çıxar" → dialoq ("Tədbirə çıxışı bağlanacaq. Əlavə etdiyi qonaqlar qalacaq.").

**Cohost görünüşü:** owner-in e-poçtu, öz tərəfi; dəvət yaratmaq yoxdur.

**Xətalar (`create_cohost_invite`):** `not_owner` (cohost üçün düymə görünmür), `invalid_email`, `cohost_exists` ("Tədbirin artıq ortaq idarəçisi var").

### 11b. Kodla qoşul
[2]-dən "Kodla qoşul": **8 ayrı xana** (4+4; böyük hərf avtomatik, boşluqlar silinir, yapışdırma dəstəklənir); 8 simvol olanda "Qoşul" aktivdir → `accept_cohost_invite` → uğur ekranı "{tədbir} tədbirinə qoşuldunuz" + "Tədbiri aç" → [6]. Xətada xanalar qırmızı və altda zolaq:

| Kod | Mesaj |
| --- | --- |
| `not_found` | Kod tapılmadı və ya artıq istifadə olunub |
| `expired` | Dəvətin müddəti bitib — owner-dən yenisini istəyin |
| `email_mismatch` | Dəvət başqa e-poçt üçündür ({hesabınızın e-poçtu} ilə daxil olmusunuz) |
| `already_member` | Siz artıq bu tədbirin üzvüsünüz |
| `cohost_exists` | Tədbirin artıq ortaq idarəçisi var |
| `not_authenticated` | (sessiya bitib) → [1] |

## 12. Alış ekranı

**Prototip:** [`design/prototype/12-alis.html`](../design/prototype/12-alis.html)

**Açılır** tam ekran ("×" sol üstdə, "Alışları bərpa et" sağ üstdə): pullu şablon seçilib, amma alınmayıb ([4], [5], [8]); limit dolub ([6], [7]); [12a] → Alışlar.

**Məzmun (premium şablon):** şablonun animasiyalı önizləməsi + qızılı "Premium" nişanı; siyahı ✓ "300 qonaq", "Animasiyalı premium dizayn", "Loqo yazısı olmadan", "Bu tədbir üçün birdəfəlik"; böyük qiymət (mağazadan, lokal valyuta) + "Birdəfəlik ödəniş, abunə deyil"; ikinci məhsul kartı "Limiti artır: +200 qonaq" öz qiyməti ilə; kiçik hüquqi mətn + İstifadə şərtləri / Məxfilik siyasəti linkləri; aşağıda "Al — {qiymət}". **Limit artırma** ayrıca görünüş: "+200 qonaq", "Limit 300-dən 500-ə qalxır".

**Hallar:** "Ödəniş yoxlanılır…" (tətbiqi bağlamayın) → uğur "Premium aktivdir" (parıltı) + "Davam et" → [8]; uğursuz "Ödəniş alınmadı, kartınızdan pul tutulmayıb" + təkrar; gözləmədə (aşağıda).

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

## 12a. Daha çox (alt naviqasiya)

**Prototip:** [`design/prototype/13-daha-cox.html`](../design/prototype/13-daha-cox.html)

Tədbirin ikinci dərəcəli bölmələri, qruplanmış siyahı:
- **Şablon və dizayn** → [5] (alt mətn: şablonun adı); **Masalar** → [10] ("4 masa · 37 qonaq masasız"); **Ortaq ailə** → [11] (ortağın adı və tərəfi).
- **Tədbiri redaktə et** → [3] redaktə rejimi; **Alışlar** → [12] ("Pulsuz plan · 84/100"); **Siyahını ixrac et** → [9] ixrac sheet-i.
- **Tədbiri sil** (qırmızı, **yalnız owner**) → təsdiq dialoqu ([2] ilə eyni). Cohost bu sətri görmür.

## 12b. Parametrlər

Prototipdə yoxdur (sadə siyahı ekranı; [2]-də profil ikonundan açılır):
- Profil: ad (`profiles.display_name`, redaktə), e-poçt (yalnız oxumaq üçün).
- **Tətbiqin dili:** Sistem / Azərbaycan / Русский / English / Türkçe → `profiles.ui_lang`.
- İstifadə şərtləri, Məxfilik siyasəti (`/legal/…`), tətbiq versiyası.
- **Çıxış** (təsdiqsiz) → [1].
- **Hesabı sil** (qırmızı, §15.9): dialoq — owner olduğu tədbirlər silinir, cohost olduğu tədbirlərdən çıxarılırsınız, geri qaytarılmır; təsdiq üçün e-poçtu yazmaq → `delete-account` Edge Function (T17) → çıxış → [1]. Xəta: `storage_unavailable` / `delete_failed` → "Hesab silinmədi, yenidən cəhd edin" (təkrar təhlükəsizdir).

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
| 12a | yuxarıdakı ekranların çağırışları; tədbiri silmək: `events` delete |
| 12b | `profiles` select/update (`display_name`, `ui_lang`); Auth `signOut`; `delete-account` Edge Function |

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
