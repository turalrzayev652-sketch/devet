# CLAUDE.md — Dəvətnamə platforması

Bu fayl Claude Code üçün layihə qaydalarıdır. Hər sessiyanın əvvəlində oxu.

## Layihə nədir

Toy, nişan, xınayaxdı, ad günü və yubiley üçün fərdi rəqəmsal dəvətnamə platforması.

- Ailə **native tətbiqdə** (Android: Kotlin + Jetpack Compose, iOS: Swift + SwiftUI) tədbir yaradır, HTML şablon seçir, qonaqları əlavə edir və hər qonağa adı ilə dəvəti WhatsApp-da (`wa.me` linki) göndərir.
- Qonaq tətbiq yükləmir: `https://<domen>/i/<kod>` linkini brauzerdə açır, cavab verir (RSVP), xəritəni, geri sayımı və masa nömrəsini görür.
- Backend: **Supabase** (Postgres + RLS, Auth, Storage, Edge Functions).
- Qonaq səhifəsi və şablonlar: **Cloudflare Pages + Pages Functions**.

## Qovluq quruluşu

```
/spec      — spesifikasiyalar (ekranlar, API, i18n, test vektorları). Kod yazmazdan əvvəl buranı oxu.
/backend   — supabase/ (migrations, functions, seed.sql, tests)
/web       — Cloudflare Pages: public/core, public/templates/<id>, functions/
/android   — Android tətbiqi
/ios       — iOS tətbiqi
/tools     — skriptlər (i18n generatoru və s.)
TASKS.md   — ardıcıl tapşırıqlar siyahısı
```

## İş qaydası

1. Hər sessiyada **yalnız bir tapşırıq** icra et: `TASKS.md`-də ilk işarələnməmiş (`- [ ]`) və `[SİZ]` olmayan tapşırığı götür.
2. Başlamazdan əvvəl tapşırığın "Asılılıq" sahəsindəki tapşırıqların bitdiyini yoxla. Bitməyibsə, dayan və de.
3. Həmişə `/spec/PRODUCT.md`-ni (məhsulun bütün qərarları, məlumat modeli, RPC müqavilələri) və tapşırıqla bağlı digər `/spec` fayllarını oxu. Spesifikasiya ilə tapşırıq ziddiyyət təşkil edirsə və ya nəsə aydın deyilsə, **təxmin etmə — sual ver**.
4. Yalnız tapşırığın aid olduğu qovluqlarda dəyişiklik et. Başqa modula toxunmaq lazım gəlsə, əvvəl soruş.
5. Testləri yaz və işə sal. "Hazırdır" meyarlarının hər birini yoxla.
6. Bitirəndə:
   - `TASKS.md`-də tapşırığı `- [x]` et;
   - qısa hesabat yaz: nə edildi, hansı fayllar dəyişdi, necə sınamaq olar, nə qaldı;
   - git commit et: `T<nömrə>: <qısa təsvir>`.
7. `[SİZ]` işarəli tapşırıqları icra etmə — onlar insan üçündür. Lazım olsa, istifadəçiyə nə etməli olduğunu xatırlat.

## Paritet qaydası (Android ↔ iOS)

- Hər modul əvvəl Android-də, sonra **eyni spesifikasiyadan** iOS-da yazılır. Modul hər iki platformada bitmədən növbəti modula keçmə.
- Davranış eyni olmalıdır: eyni ekran axını, eyni xəta mesajları, eyni validasiya.
- Ortaq məntiq üçün test vektorları `/spec/test-vectors/` qovluğundadır (məs. telefon nömrələrinin normallaşdırılması). Hər iki platformanın testləri eyni vektorlardan keçməlidir.

## Təhlükəsizlik (pozula bilməz)

- `service_role` açarı **yalnız** Supabase Edge Functions və Cloudflare Functions mühit dəyişənlərində olur. Heç vaxt tətbiqə, `web/public`-ə və ya git-ə düşmür.
- Tətbiqlər və qonaq səhifəsi yalnız `anon` açarından istifadə edir; giriş RLS ilə məhdudlaşır.
- Qonaq cədvəllərə birbaşa çıxış almır — yalnız `get_preview`, `get_invite`, `submit_rsvp` funksiyaları vasitəsilə.
- Linkdə qonağın adı və ya telefonu olmur — yalnız 8 simvolluq təsadüfi kod.
- Sirləri `.env` faylında saxla, `.env` `.gitignore`-dadır; `.env.example` faylını yenilə.
- **Ödəniş, RLS və Edge Function** dəyişikliklərindən sonra hesabatda ayrıca "İnsan yoxlaması lazımdır" bölməsi yaz: nəyi və niyə yoxlamaq lazımdır.

## Kod qaydaları

- Kod, dəyişən adları, commit mesajlarının texniki hissəsi — ingiliscə. İstifadəçiyə görünən bütün mətnlər — yalnız i18n faylları vasitəsilə (az, ru, en, tr). Koda birbaşa mətn yazma.
- i18n mənbəyi: `/spec/i18n/app.json` (tətbiq) və `/spec/i18n/invite.json` (qonaq səhifəsi). Android və iOS faylları `/tools/i18n` generatoru ilə yaradılır, əl ilə redaktə edilmir.
- Android: Kotlin, Jetpack Compose, minSdk 26, `supabase-kt`. iOS: Swift, SwiftUI, iOS 16+, `supabase-swift`.
- Qonaq səhifəsi: framework-süz vanilla JS, ES modules. Hər şablonun ilk yüklənməsi **1,5 MB-dan az**, mobil 4G-də 2 saniyədən tez açılmalıdır. `prefers-reduced-motion` dəstəklənməlidir. Musiqi avtomatik başlamır.
- Yeni asılılıq (kitabxana) əlavə etməzdən əvvəl səbəbini hesabatda yaz.

## Məhsul qaydaları (qısa)

- Tədbir növləri: toy, nişan, xınayaxdı, ad günü, yubiley.
- Pulsuz şablon: 100 qonağa qədər, dəvətnamənin altında kiçik "… ilə yaradılıb" yazısı.
- Pullu şablon: bir tədbir üçün birdəfəlik alış, 300 qonaq. Başlanğıc qiymət 19,99 AZN. 300-dən çox üçün "limit artırma" alışı.
- Ödəniş yalnız tətbiq daxilində: Google Play Billing və StoreKit 2; alış serverdə (Edge Function) yoxlanılır.
- Göndərmə yalnız `wa.me` ilə — "Göndər"i istifadəçi özü basır. WhatsApp API, SMS, push bildirişləri **yoxdur**.
- Giriş: yalnız e-poçt + şifrə.
- Bir tədbiri iki ailə (bəy və gəlin tərəfi) idarə edə bilər.
- Masa: hər qonağa masa nömrəsi; masadakı digər qonaqların göstərilməsini ailə açıb-bağlayır (defolt: bağlı).
- Qonaq səhifəsinin dili: tədbirin əsas dili, ailə istəsə qonaq üzrə fərqli dil.
- Hitab: müəllim, xanım, bəy və ya yox; "ailəliklə" seçimi. Hər dildə öz forması (`/spec/i18n/invite.json`).

## Bu versiyada OLMAYANLAR

Korporativ tədbirlər, qrup üçün ümumi link, qonaqların şəkil yükləməsi, vizual zal planı, Google/Apple/telefonla giriş, saytda kartla ödəniş, endirim/tərəfdaş kodları, admin veb panel (şablonlar Supabase panelindən idarə olunur), çap üçün adlı PDF dəvətnamə.
