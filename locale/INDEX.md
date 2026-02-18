# locale

> Platform module #3 | Loaded by `create.psql` line 3

Manages application locales (languages) using ISO 639-1 codes. A minimal reference module: one table, one view, two lookup functions, and five seed records.

## Dependencies

| Depends on | Depended by |
|------------|-------------|
| `kernel` | `admin` (user profiles reference locale), `resource` (multilingual content), `current` (current_locale) |

## Schemas Used

| Schema | Usage |
|--------|-------|
| `db` | `db.locale` table |
| `kernel` | `Locale` view, `GetLocale`/`GetLocaleCode` functions |

## Tables

| Table | Description | Key Columns |
|-------|-------------|-------------|
| `db.locale` | Language locales | `id uuid PK`, `code text UNIQUE` (ISO 639-1), `name text`, `description text` |

## Views

### kernel schema

| View | Source | Grants |
|------|--------|--------|
| `Locale` | `db.locale` | `administrator` |

## Functions

| Function | Returns | Purpose |
|----------|---------|---------|
| `GetLocale(pCode text)` | `uuid` | Lookup locale ID by ISO 639-1 code (STABLE STRICT) |
| `GetLocaleCode(pId uuid)` | `text` | Lookup ISO 639-1 code by locale ID (STABLE STRICT) |

## Init / Seed Data

`init.sql` inserts 5 locales with deterministic UUIDs:

| Code | Name | UUID suffix |
|------|------|-------------|
| `en` | English | `...001` |
| `ru` | Русский | `...002` |
| `de` | Deutsch | `...003` |
| `fr` | Français | `...004` |
| `it` | Italiano | `...005` |

## File Manifest

| File | In create | In update | Purpose |
|------|:---------:|:---------:|---------|
| `table.sql` | yes | no | `db.locale` table + unique index |
| `view.sql` | yes | yes | `Locale` view |
| `routine.sql` | yes | yes | `GetLocale`, `GetLocaleCode` |
| `init.sql` | yes | no | Insert 5 locales (en, ru, de, fr, it) |
| `create.psql` | - | - | Includes all |
| `update.psql` | - | - | Includes view, routine |
