# tools

Helper scripts.

- `i18n/check-invite.mjs` — validates `/spec/i18n/invite.json`: schema (`invite.schema.json`), all four languages,
  same placeholders in every language, required keys, and salutation forms equal to `display_name_forms`
  in `backend/supabase/migrations/003_guest_rpc.sql`.

  ```bash
  node tools/i18n/check-invite.mjs
  node --test tools/i18n/check-invite.test.mjs
  ```

- `i18n/` generator for Android `strings.xml` and iOS `Localizable.xcstrings` from `/spec/i18n/app.json` — T32.
