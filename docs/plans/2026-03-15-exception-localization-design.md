# Exception Strategy & Localization Platform — Design

**Date:** 2026-03-15
**Status:** Approved
**Target version:** 1.2.0
**Scope:** Exception system overhaul + localization infrastructure + libapostol coordination

## Goal

Establish a unified, locale-aware exception system across the entire platform with
structured error codes, a searchable error catalog, and multi-language support
for European and American markets.

## Target Languages

| Code | Role |
|------|------|
| `en` | Primary (international, fallback for missing translations) |
| `ru` | Developer's native language |
| `de` | European market |
| `fr` | European market |
| `it` | European market |
| `es` | European + American market |

Replace existing `nl` (Dutch) with `de` (German). Remove `al` (Albanian) if present.

## Error Code Format

**New format:** `ERR-GGG-CC`

- `GGG` — HTTP status group (400, 401, 403, 404, 500)
- `CC` — unique code within group (01-99)
- Example: `ERR-400-01` (Access denied), `ERR-401-01` (Login failed)

**Migration from current:** `ERR-40001` → `ERR-400-01`

`ParseMessage()` supports both formats during transition period. Projects migrate
at their own pace.

## JSON Error Response

**Current:**
```json
{"error": {"code": 400, "message": "Access denied."}}
```

**New:**
```json
{"error": {"code": 400, "error": "ERR-400-01", "message": "Access denied."}}
```

- `code` (int) — HTTP status code. Unchanged. Backward compatible for all frontends.
- `error` (string) — structured error identifier for support/documentation lookup. New field.
- `message` (string) — human-readable, locale-aware message. As before, now guaranteed localized.

## Support Flow

```
User sees error → reads ERR-400-01 → looks up in docs or asks support
Support/AI-agent → GET /api/v1/error/ERR-400-01 → gets description + resolution
```

## Architecture

### New Tables

```sql
CREATE TABLE db.error_catalog (
  id          uuid PRIMARY KEY DEFAULT gen_kernel_uuid(),
  code        text NOT NULL UNIQUE,      -- 'ERR-400-01'
  http_code   integer NOT NULL,          -- 400
  severity    char(1) NOT NULL DEFAULT 'E',  -- E=error, W=warning
  category    text NOT NULL,             -- 'auth', 'access', 'entity', 'workflow', 'validation', 'system'
  created_at  timestamptz DEFAULT now()
);

CREATE TABLE db.error_catalog_text (
  error_id    uuid REFERENCES db.error_catalog(id),
  locale      uuid REFERENCES db.locale(id),
  message     text NOT NULL,             -- Short: 'Access denied.'
  description text,                      -- Detailed: 'The current user lacks permissions...'
  resolution  text,                      -- Steps: 'Verify user role. Contact admin.'
  PRIMARY KEY (error_id, locale)
);
```

### Error Catalog as Reference Entity

Full entity with standard platform patterns:

| File | Purpose |
|------|---------|
| `table.sql` | DDL + COMMENT ON + triggers |
| `routine.sql` | CreateErrorCatalog, EditErrorCatalog, GetErrorCatalog |
| `api.sql` | api.error_catalog view + CRUD wrappers |
| `rest.sql` | REST dispatcher |
| `view.sql` | api.error_catalog view joining text by locale |

Standard query capabilities:
- `GET /api/v1/error/{code}` — single error by code
- `POST /api/v1/error/list` — with search, filter, reclimit, orderby
- `POST /api/v1/error/count` — count by filter

### Categories

| Category | HTTP Groups | Examples |
|----------|-------------|---------|
| `auth` | 401 | LoginFailed, TokenExpired, NonceExpired, PasswordExpired |
| `access` | 403 | AccessDenied, UserNotMemberArea, UserNotMemberInterface |
| `validation` | 400 | IncorrectCode, JsonIsEmpty, InvalidPhone, ValueOutOfRange |
| `entity` | 400 | ObjectNotFound, AlreadyExists, IncorrectClassType |
| `workflow` | 400 | ActionAlreadyCompleted, MethodNotFound, StateByCodeNotFound |
| `system` | 500 | SomethingWentWrong |

### Updated Core Functions

**`ParseMessage(text)`** — dual parser:
```
Input: 'ERR-400-01: Access denied.'  → error_code='ERR-400-01', http_code=400, message='Access denied.'
Input: 'ERR-40001: Access denied.'   → error_code='ERR-400-01', http_code=400, message='Access denied.'
```

**`GetExceptionStr(pErrGroup, pErrCode)`** — reads from `error_catalog_text`:
```sql
SELECT message FROM db.error_catalog_text
 WHERE error_id = (SELECT id FROM db.error_catalog WHERE code = format('ERR-%s-%s', ...))
   AND locale = current_locale();
```
Falls back to `en` if current locale has no translation.

**`api.run()` exception handler** — adds `error` field:
```sql
RETURN NEXT json_build_object('error', json_build_object(
  'code',    HttpCode,
  'error',   ErrorIdentifier,  -- 'ERR-400-01'
  'message', ErrorMessage
));
```

### C++ Side (libapostol)

**`check_pg_error()`** — parses JSON, extracts:
- `code` (int) → `error_code_to_status()` → HTTP status (unchanged)
- `error` (string) → pass-through to HTTP response body
- `message` (string) → pass-through (unchanged)

**No external behavior change** — HTTP status codes derived from int `code` as before.
New `error` field simply appears in the response JSON body.

## Hardcoded String Strategy

### Exception-like strings (~200): Migrate to error_catalog

All `SetErrorMessage()`, `ObjectNotFound('русский текст')`, and direct
`RAISE EXCEPTION 'ERR-...: Russian text'` calls inside the platform become
proper exceptions through `error_catalog`.

### Event log messages (~200): Static English translation

Event log text in `WriteToEventLog()` calls is developer-facing audit data.
Translate to English statically, no runtime localization.

### KLADR data: Keep Russian

Russian geographic data (address abbreviations, region names) is business data.

### init.sql seed data: Keep Russian

State names, method names, entity labels in init.sql are business data.

## Backward Compatibility

### ParseMessage() dual format

Supports both `ERR-40001` and `ERR-400-01`. Old format converted internally
to new format. No breakage for projects using old format.

### JSON response

New `error` field is additive. Existing frontends parsing `code` and `message`
continue to work unchanged.

### Configuration layer projects

Projects (Campus CORS, ChargeMeCar, etc.) have their own exception.sql files.
Their migration is separate — happens when each project updates to platform 1.2.0.

**Known project state:**
- Campus CORS: 91% already use CreateExceptionResource (low risk)
- ChargeMeCar: 81% hardcoded Russian (high risk, needs dedicated migration)

**Platform provides:**
- `docs/migration-1.2.0.md` — migration guide for projects
- Mapping table: old codes → new codes
- Helper function to register project-specific exceptions in error_catalog

### Resource tree

Exception messages move from resource tree to error_catalog. Resource tree
continues to work for UI labels, content, and other multilingual resources.
`CreateExceptionResource()` deprecated but functional during transition.

## Migration Order

1. Create `db.error_catalog` + `db.error_catalog_text` tables
2. Implement as reference entity (routine, api, rest, view)
3. Update `ParseMessage()` for dual format
4. Update `GetExceptionStr()` to read from error_catalog (fallback to resource tree)
5. Update `api.run()` — add `error` field to JSON response
6. Migrate all 84 platform exception functions to new format + error_catalog
7. Migrate hardcoded Russian strings in platform (SetErrorMessage, ObjectNotFound)
8. Translate event log messages to English
9. Fill `description` + `resolution` for every error code (en)
10. Update libapostol — `check_pg_error()` passes `error` field through
11. Generate `docs/error-codes.md` from error_catalog
12. Write `docs/migration-1.2.0.md` for downstream projects
13. Translate all error_catalog_text to de, fr, it, es (subagent task)
14. Update VERSION to 1.2.0

## Out of Scope

- Configuration layer migration (each project's responsibility)
- Frontend changes (additive JSON field, no breaking changes)
- New exception functions (only restructure existing 84)
- KLADR or init.sql Russian text (business data)

## Deliverables

- `db.error_catalog` + `db.error_catalog_text` as reference entity
- Updated `ParseMessage()`, `GetExceptionStr()`, `api.run()`
- All 84 exceptions migrated to ERR-GGG-CC format
- All hardcoded Russian in platform → through exception system or English
- Error catalog API: `/api/v1/error/{get,list,count}`
- `docs/error-codes.md` — generated catalog
- `docs/migration-1.2.0.md` — project migration guide
- libapostol patch for `error` field pass-through
- 6-language translations (en, ru, de, fr, it, es)
- VERSION = 1.2.0
