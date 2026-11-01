# Mac-də davam etmək üçün prompt

Bu faylın "Prompt" bölməsini Mac-də Claude Code-a olduğu kimi yapışdır.

---

## Prompt

Bu layihə Dəvətnamə/Devet platformasıdır (toy və ailə şənlikləri üçün rəqəmsal dəvətnamə). Əvvəlcə `CLAUDE.md`, `TASKS.md`, `spec/PRODUCT.md`, `spec/design.md`, `spec/screens.md` və `android/README.md` fayllarını tam oxu. Bütün qaydalar `CLAUDE.md`-dədir; mənimlə Azərbaycan dilində danış.

### Harada qalmışıq

- `main` budağı son vəziyyətdir (son commit: `Merge branch 't41a-android' … (T41A)`).
- Backend (Supabase: migrasiyalar 001–012, RLS, RPC-lər, Edge Functions), qonaq səhifəsi (`web/`, Cloudflare Pages), spesifikasiyalar (`spec/`), dizayn sistemi və HTML prototip (`design/`) hazırdır və main-dədir.
- **T41A (Android quruluşu) bitib:** `android/` — Kotlin + Compose, minSdk 26, Koin, supabase-kt, Navigation Compose, dizayn tokenləri `spec/design.md`-dən (`android/app/src/main/java/az/devet/app/ui/theme/`), 4 dildə generasiya olunmuş sətirlər, müvəqqəti Welcome ekranı, `DesignTokensTest` və `StringResourcesTest`, `.github/workflows/android.yml`. Lokal build və emulyatorda az/ru/en/tr yoxlanıb.
- **Növbəti tapşırıq: T41I (iOS quruluşu və dizayn sistemi).** Paritet qaydasına görə T42 (Giriş) T41I bitmədən başlamır.

### T41I — nə etməli

`TASKS.md`-dəki T41A/T41I tapşırığına bax. Hazırdır meyarı: boş tətbiq 4 dildə açılır, dil sistem dilinə görə seçilir, CI-də build keçir. Android-dəki T41A-nın iOS ekvivalentini **eyni spesifikasiyadan** yaz:

1. `ios/` qovluğunda Xcode layihəsi: SwiftUI, iOS 16+, bundle id `az.devet.app`, app adı "Devet". Asılılıqlar Swift Package Manager ilə, versiyalar sabitlənmiş (`supabase-swift`). Mümkünsə layihəni XcodeGen və ya Tuist kimi alət olmadan, ya da səbəbini hesabatda yazaraq yarat.
2. Dizayn tokenləri: `spec/design.md`-dəki bütün rənglər (açıq/tünd, status rəngləri), tipoqrafiya (10 token), boşluqlar, radiuslar, ölçülər — Android-dəki `Color.kt`, `Type.kt`, `Dimens.kt`, `Theme.kt` ilə eyni adlar və dəyərlər. Qızılı yalnız dekorasiya; mətn üçün `goldText`.
3. Şriftlər: Android-də istifadə olunan eyni variable TTF faylları — `android/app/src/main/res/font/inter_variable.ttf` və `noto_serif_display_variable.ttf` (lisenziyalar `android/licenses/`). iOS-a köçür, `Info.plist`-də qeyd et (UIAppFonts), çəkini variable axis ilə ver.
4. i18n: `node tools/i18n/generate.mjs` — iOS faylını `ios/Devet/Resources/Localizable.xcstrings`-ə yazır (defolt yol). Əl ilə redaktə etmə. Dillər: az (əsas/development language), ru, en, tr. Tətbiq sistem dilini izləməlidir, iOS-un tətbiq üzrə dil seçimi də işləməlidir.
5. Supabase müştərisi: yalnız `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `PUBLIC_BASE_URL` — gitignore olunan xcconfig faylından (məs. `ios/Config/Secrets.xcconfig`, nümunəsi `Secrets.example.xcconfig`). **service_role heç vaxt tətbiqə düşmür.** Dəyərlər yoxdursa tətbiq yenə açılmalıdır.
6. Android-dəki kimi müvəqqəti Welcome ekranı: loqo hərfi, app adı, `app_welcome`, `app_tagline`, `auth_login_title` düyməsi, `app_language`. Açıq/tünd preview.
7. Testlər (XCTest): tokenlər `spec/design.md` ilə eynidir (Android-dəki `DesignTokensTest` kimi md cədvəllərini parse et); `Localizable.xcstrings`-də 4 dil üçün eyni açarlar və `spec/i18n/app.json` ilə uyğunluq.
8. CI: `.github/workflows/ios.yml` — macOS runner, i18n generatorunun sinxron olduğunu yoxla (`git diff --exit-code ios/Devet/Resources`), `xcodebuild test` simulyatorda.
9. Simulyatorda 4 dildə aç, ekran şəkli ilə yoxla.
10. Bitirəndə: `TASKS.md`-də T41I-ni işarələ (T41A sətri artıq var), `ios/README.md`-yə build qaydası və asılılıqların səbəbi, hesabat (Azərbaycan dilində), commit `T41I: …` sonunda `Co-Authored-By` sətri ilə, `t41i-ios` budağında; sonra main-ə merge etməyi soruş.

### İş qaydası (qısa)

- Hər tapşırıq üçün ayrı budaq (`t41i-ios`), bitəndə hesabat + TASKS.md + commit, merge-dən əvvəl soruş.
- Spesifikasiya aydın deyilsə — təxmin etmə, soruş. Başqa modula (backend, web, android) toxunmaq lazımdırsa, əvvəl soruş.
- İstifadəçiyə görünən mətnlər yalnız `spec/i18n/app.json`-dan.

### T41I-dən sonra gözləyən işlər

- T42A/T42I Giriş (Android əvvəl, sonra iOS).
- T4C: real sandbox alış testləri; T50: məxfilik siyasəti (sahibin adı, VÖEN, e-poçt lazımdır; region AB Frankfurt).
- `[SİZ]` tapşırıqlar: T00 hesablar, T25 şablon dizaynları (T26–T29 bunu gözləyir).
- Docker olanda: `supabase db reset` və `supabase test db` (pgTAP testləri indiyə qədər PGlite-də yoxlanıb).
- `.github/workflows/android.yml` GitHub-da hələ işlədilməyib (repo push edilməyib).

---

## Layihəni Mac-ə necə köçürmək

Repo-nun remote-u yoxdur. İki yol:

- **GitHub (tövsiyə):** private repo yarat, Windows-da `git remote add origin <url>` və `git push -u origin --all`, Mac-də `git clone`. CI da işləməyə başlayar.
- **Qovluğu köçürmək:** `devetname` qovluğunu bütöv (gizli `.git` ilə) zip edib Mac-ə at. `android/build`, `android/.gradle` qovluqlarını silmək olar.

Mac-də lazım olanlar: Xcode (son versiya), Node 22 (`node tools/i18n/generate.mjs` üçün), Claude Code.
