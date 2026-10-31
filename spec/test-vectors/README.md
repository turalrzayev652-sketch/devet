# test-vectors

Shared inputs and expected outputs for logic that exists on both Android and iOS (CLAUDE.md parity rule).
Each platform's unit tests load these JSON files and must reproduce every case exactly.
A JavaScript reference implementation in `/tools/test-vectors/` runs the same files, so a vector that
contradicts these rules fails there first:

```bash
node --test tools/test-vectors/reference.test.mjs
```

## phones

`phones.json` — normalise what the family typed (or what came from contacts/Excel) to E.164, or return an error code.

1. **Clean:** NFKC-normalise (full-width digits and `＋` become ASCII), trim, then remove spaces (incl. no-break),
   `-`, `.`, `(`, `)`. If anything other than digits and one leading `+` remains → `invalid`.
   Nothing left → `empty`.
2. **International prefix:** a leading `00` becomes `+`.
3. **Azerbaijani forms** (no `+`):
   - `994` + 9 digits → `+994…`
   - `0` + 9 digits → `+994` + the 9 digits
   - exactly 9 digits not starting with `0` → `+994` + the 9 digits
     (a leading `0` is the trunk prefix, so 9 digits starting with `0` are one digit short → `invalid`)
   - anything else → `invalid`
4. **With `+`:** `+` followed by 8–15 digits, first digit not `0` → keep; otherwise `invalid`.
5. **Azerbaijani numbers (`+994`)** must have exactly 9 national digits (else `invalid`), and the first two must be a
   mobile operator prefix from `az_mobile_prefixes` (10, 50, 51, 55, 60, 70, 77, 99). Other prefixes (landlines,
   unknown) → `not_mobile`: invitations are sent through WhatsApp, which needs a mobile number.
6. **Foreign numbers** are only length-checked (rule 4); no per-country validation.

Error codes: `empty`, `invalid`, `not_mobile`. The app shows a message per code (strings go into `app.json` in T45).

## excel

`excel.json` — `.xlsx` import: the first row is the header, every following non-empty row is a guest.

**fold(text)**: NFKC → lower-case → `ı`→`i`, `ə`→`e` → strip diacritics (NFD, drop combining marks) →
collapse whitespace to one space → trim.

- **normalizeHeader(text)** = fold, then every run of characters that are not letters or digits becomes one space, trim.
  So `"  AD SOYAD "`, `"Ad soyad:"` and `"ad soyad"` match; `"Adı"`/`"Adi"` and `"Nömrə"`/`"Nomre"` match.
- **normalizeValue(text)** = fold only (punctuation kept, so `"+"`, `"-"`, `"✓"`, `"mr."` stay distinct from empty).

Aliases and values in `excel.json` are compared after the same normalisation.

**Headers** (`header_cases`): a column maps to the field whose `aliases` contain its `normalizeHeader` value. Unknown
columns are ignored. If two columns map to the same field, the first wins. Without a `name` column the file is rejected
(`name_column_missing`).

**Rows** (`row_cases`): a row whose cells are all empty is skipped. Cells may arrive as strings or numbers.

| Field | Rule | Error |
| --- | --- | --- |
| `name` | trimmed text, required | `name_missing` |
| `phone` | optional; empty → `null`; a number cell is turned into its integer digits first (Excel drops the leading `0`, which rule 3 handles); then the phone rules | `phone_invalid` (`invalid`), `phone_not_mobile` (`not_mobile`) |
| `salutation` | optional; `normalizeValue` in `values.salutation`; empty → `none` | `salutation_invalid` |
| `invited_count` | optional; empty → 1; integer 1–50 (`"2.0"` and `2` are fine, `"2.5"` is not) | `invited_count_invalid` |
| `with_family` | optional; `values.boolean`; empty → `false` | `with_family_invalid` |
| `side` | optional; `values.side`; empty → `none` | `side_invalid` |
| `table_no` | optional; trimmed text (numbers become text: `5` → `"5"`), max 12 characters; empty → `null` | `table_no_invalid` |

A row may have several errors; they are listed in the order of `columns` in the file. Rows with errors are shown in
the "error rows" list and not imported; the rest are imported.

**File** (`file_cases`): no data rows → `no_rows`. The same normalised phone in two rows → warning
`duplicate_phone` on the later row (1-based data row number), not an error. Empty phones never count as duplicates.

## maps

`maps.json` — the venue map link the family pastes (screens.md §3, step 4). The link itself is stored in
`events.maps_url`; coordinates, when they can be read, go to `venue_lat` / `venue_lng` (the Waze button needs them).

1. Trim. Empty → `empty` (no link; the field is optional).
2. Must parse as an absolute `http:` / `https:` URL, else `invalid_url` (the guest page refuses other schemes too).
3. Coordinates are read only from known map hosts: `google.<tld>` / `www.google.<tld>` / `maps.google.<tld>`
   (path or host containing maps), `waze.com`, `maps.apple.com`. Any other host → link kept, no coordinates.
4. Order of sources: `!3d<lat>!4d<lng>` in the URL (Google's place pin) → `@<lat>,<lng>` in the path (map view) →
   query parameter `q`, `query` or `ll` whose whole value is `<lat>,<lng>` (spaces allowed after the comma).
5. Numbers are decimal (optional `-`); latitude must be within ±90 and longitude within ±180, else no coordinates.
6. Short links (`maps.app.goo.gl`, `goo.gl/maps`) are kept without coordinates: resolving them needs a network
   request, which the app does not make.
