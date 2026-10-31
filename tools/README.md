# tools

Helper scripts.

- `i18n/check-invite.mjs` — validates `/spec/i18n/invite.json`: schema (`invite.schema.json`), all four languages,
  same placeholders in every language, required keys, and salutation forms equal to `display_name_forms`
  in `backend/supabase/migrations/003_guest_rpc.sql`.

  ```bash
  node tools/i18n/check-invite.mjs
  node --test tools/i18n/check-invite.test.mjs
  ```

- `i18n/generate.mjs` — generates app strings from `/spec/i18n/app.json` (same format as invite.json):
  Android `values/strings.xml` (az = default), `values-ru|en|tr/strings.xml`, and iOS `Localizable.xcstrings`.
  Keys `a.b.c` become Android `a_b_c`; keys ending in `.one/.few/.many/.other` become one plural string;
  `{name}` becomes positional `%1$s` / `%1$@` (`{count}` in plurals: `%1$d` / `%1$lld`).
  Missing translations, placeholder mismatches or name clashes stop it with exit 1 and nothing is written.
  Generated files are never edited by hand.

  ```bash
  node tools/i18n/generate.mjs                       # default outputs (used from T41)
  node tools/i18n/generate.mjs --android <resDir> --ios <file.xcstrings>
  node --test tools/i18n/generate.test.mjs
  ```
  Defaults: `android/app/src/main/res`, `ios/Devet/Resources/Localizable.xcstrings`.

- `test-vectors/reference.mjs` — JavaScript reference for the rules in `/spec/test-vectors/README.md`
  (phone normalisation, Excel import). Its test runs every vector, so a contradictory vector fails before
  Android/iOS implement it.

  ```bash
  node --test tools/test-vectors/reference.test.mjs
  ```
