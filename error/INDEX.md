# error

> Platform module #8 | Loaded by `create.psql` line 8

Centralized error catalog with locale-aware messages. Every application error code (ERR-GGG-CCC format) is registered here with translations for six locales, an HTTP status code group, severity level, and functional category. The exception module reads this catalog to produce localized error responses.

## Dependencies

| Depends on | Depended by |
|------------|-------------|
| `kernel` (base types, `gen_kernel_uuid`), `locale` (`db.locale` for translations) | `exception` (reads `error_catalog` to resolve error messages), `api` (error field in JSON response) |

## Schemas Used

| Schema | Usage |
|--------|-------|
| `db` | `db.error_catalog`, `db.error_catalog_text` tables |
| `kernel` | `ErrorCatalog` view, 7 business logic functions |
| `api` | `api.error_catalog` view, 6 API functions |
| `rest` | `rest.error` dispatcher |

## Tables

| Table | Description | Key Columns |
|-------|-------------|-------------|
| `db.error_catalog` | Master catalog of all application error codes | `id uuid PK`, `code text UNIQUE` (ERR-GGG-CCC), `http_code integer`, `severity char(1)` (E/W), `category text`, `created_at timestamptz` |
| `db.error_catalog_text` | Locale-specific error messages, descriptions, and resolution guidance | `error_id uuid FK`, `locale uuid FK`, `message text`, `description text`, `resolution text` — PK `(error_id, locale)` |

### Indexes

| Table | Index | Columns |
|-------|-------|---------|
| `db.error_catalog` | unique | `code` |
| `db.error_catalog` | btree | `http_code` |
| `db.error_catalog` | btree | `category` |

## Views

### kernel schema

| View | Source | Grants |
|------|--------|--------|
| `ErrorCatalog` | `db.error_catalog` LEFT JOIN `db.error_catalog_text` (filtered by `current_locale()`) | `administrator` |

### api schema

| View | Source | Grants |
|------|--------|--------|
| `api.error_catalog` | `ErrorCatalog` | `administrator` |

## Functions

### kernel schema

| Function | Returns | Purpose |
|----------|---------|---------|
| `CreateErrorCatalog(pCode, pHttpCode, pSeverity, pCategory)` | `uuid` | Register a new error code in the catalog |
| `EditErrorCatalog(pId, pCode, pHttpCode, pSeverity, pCategory)` | `void` | Update an existing entry (NULL = keep current) |
| `GetErrorCatalog(pCode text)` | `uuid` | Look up entry ID by code (STABLE STRICT) |
| `DeleteErrorCatalog(pId uuid)` | `void` | Remove an entry and its translations (CASCADE) |
| `SetErrorCatalogText(pErrorId, pLocale, pMessage, pDescription, pResolution)` | `void` | Upsert a locale-specific message for an entry |
| `GetErrorCatalogMessage(pCode, pLocale)` | `text` | Retrieve localized message with English fallback |
| `RegisterError(pCode, pHttpCode, pSeverity, pCategory, pLocaleCode, pMessage, pDescription, pResolution)` | `uuid` | Create-or-update an error code with its localized message in one call |

### api schema

| Function | Returns | Purpose |
|----------|---------|---------|
| `api.add_error(pCode, pHttpCode, pSeverity, pCategory, pMessage, pDescription, pResolution)` | `uuid` | Create a new entry with a message for the current locale |
| `api.update_error(pId, pCode, pHttpCode, pSeverity, pCategory)` | `void` | Update an existing entry |
| `api.set_error(pId, pCode, pHttpCode, pSeverity, pCategory, pMessage, pDescription, pResolution)` | `SETOF api.error_catalog` | Upsert: create when pId is NULL, otherwise update; returns the row |
| `api.get_error(pId uuid)` | `SETOF api.error_catalog` | Retrieve a single entry by ID |
| `api.get_error_by_code(pCode text)` | `SETOF api.error_catalog` | Retrieve a single entry by code string |
| `api.list_error(pSearch, pFilter, pLimit, pOffSet, pOrderBy)` | `SETOF api.error_catalog` | List entries with search, filter, and pagination |

### rest schema

| Function | Returns | Purpose |
|----------|---------|---------|
| `rest.error(pPath text, pPayload jsonb)` | `SETOF json` | Dispatch REST JSON API requests for the Error Catalog entity |

## REST Routes

| Route | Method | Description |
|-------|--------|-------------|
| `/error/count` | POST | Count entries matching search/filter criteria |
| `/error/set` | POST | Create or update an entry (delegates to `api.set_error`) |
| `/error/get` | POST | Retrieve a single entry by ID (supports `fields`) |
| `/error/code` | POST | Retrieve a single entry by code string (supports `fields`) |
| `/error/list` | POST | List entries with search, filter, pagination, ordering |

## Init / Seed Data

`init.sql` registers 80 error codes across 6 locales (en, ru, de, fr, it, es) = 480 `RegisterError()` calls.

### Error code groups

| HTTP Code | Category | Description | Count |
|-----------|----------|-------------|-------|
| 401 | auth | Authentication errors | 7 |
| 403 | auth | Token expiration | 1 |
| 400 | access | Access errors | 3 |
| 400 | auth | Auth errors | 4 |
| 400 | entity | Entity errors | 6 |
| 400 | validation | Validation errors | 18 |
| 400 | workflow | Workflow errors | 22 |
| 400 | validation | JSON validation errors | 8 |
| 400 | auth | OAuth 2.0 errors | 5 |
| 400 | validation | Registry errors | 2 |
| 400 | validation | Route errors | 3 |
| 400 | system | System errors | 1 |

Error code format: `ERR-<http_code>-<sequence>` (e.g., `ERR-401-001`, `ERR-400-042`).

## File Manifest

| File | In create | In update | Purpose |
|------|:---------:|:---------:|---------|
| `table.sql` | yes | no | `db.error_catalog` + `db.error_catalog_text` tables, indexes |
| `routine.sql` | yes | yes | 7 kernel functions (CRUD + RegisterError + message lookup) |
| `view.sql` | yes | yes | `ErrorCatalog` + `api.error_catalog` views |
| `api.sql` | yes | yes | 6 API functions (add, update, set, get, get_by_code, list) |
| `rest.sql` | yes | yes | `rest.error` dispatcher (5 routes) |
| `init.sql` | yes | no | 80 error codes x 6 locales = 480 RegisterError calls |
| `create.psql` | - | - | Includes all (table, routine, view, api, rest, init) |
| `update.psql` | - | - | Includes routine, view, api, rest |

## Since

Version 1.2.0
