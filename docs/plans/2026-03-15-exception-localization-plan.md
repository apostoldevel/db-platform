# Exception Strategy & Localization Platform — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Unified locale-aware exception system with structured ERR-GGG-CCC codes, searchable error catalog entity, and 6-language support.

**Architecture:** Create `error_catalog` as a reference entity in a new `error/` module. Migrate exception infrastructure (ParseMessage, GetExceptionStr, api.run) to new format. Re-register all 84 exceptions into error_catalog with 6 locales. Translate ~210 hardcoded Russian strings. Coordinate libapostol changes.

**Tech Stack:** PL/pgSQL, PostgreSQL, db-platform entity system.

**Design doc:** `docs/plans/2026-03-15-exception-localization-design.md`

---

## Reference: Error Code Format

- **New:** `ERR-GGG-CCC` (e.g., `ERR-400-001`, `ERR-401-001`)
- **Old:** `ERR-GGGCC` (e.g., `ERR-40001`) — supported during transition
- JSON: `{"error": {"code": 400, "error": "ERR-400-001", "message": "Access denied."}}`

## Reference: Target Locales

| Code | UUID | Status |
|------|------|--------|
| `en` | `00000000-0000-4001-a000-000000000001` | Exists |
| `ru` | `00000000-0000-4001-a000-000000000002` | Exists |
| `de` | `00000000-0000-4001-a000-000000000003` | Exists (was nl, rename) |
| `fr` | `00000000-0000-4001-a000-000000000004` | Exists |
| `it` | `00000000-0000-4001-a000-000000000005` | Exists |
| `es` | `00000000-0000-4001-a000-000000000006` | New — add |

---

## Task 1: Update locale seed data

**Files:**
- Modify: `locale/init.sql`

**Step 1:** Update locale/init.sql:
- Rename `de` (was Deutsch, previously nl/Dutch UUID slot `...000003`) — verify current state, ensure code='de', name='Deutsch', description='Deutsche Sprache'
- Add `es` locale: UUID `00000000-0000-4001-a000-000000000006`, code='es', name='Español', description='Lengua española'
- Verify en, ru, fr, it are correct

**Step 2:** Commit.

```bash
git add locale/
git commit -m "feat(locale): add Spanish (es) locale, verify all 6 target locales"
```

---

## Task 2: Create error_catalog module — DDL

**Files:**
- Create: `error/table.sql`
- Create: `error/create.psql`
- Create: `error/update.psql`

**Step 1:** Create `error/table.sql` with:

```sql
--------------------------------------------------------------------------------
-- ERROR_CATALOG ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.error_catalog (
  id          uuid PRIMARY KEY DEFAULT gen_kernel_uuid(),
  code        text NOT NULL,
  http_code   integer NOT NULL,
  severity    char(1) NOT NULL DEFAULT 'E',
  category    text NOT NULL DEFAULT 'validation',
  created_at  timestamptz NOT NULL DEFAULT Now()
);

COMMENT ON TABLE db.error_catalog IS 'Master catalog of all application error codes (ERR-GGG-CCC format).';
COMMENT ON COLUMN db.error_catalog.id IS 'Primary key (UUID).';
COMMENT ON COLUMN db.error_catalog.code IS 'Structured error identifier (e.g., ERR-400-001). Unique across the system.';
COMMENT ON COLUMN db.error_catalog.http_code IS 'HTTP status code group (400, 401, 403, 404, 500).';
COMMENT ON COLUMN db.error_catalog.severity IS 'Severity level: E = error, W = warning.';
COMMENT ON COLUMN db.error_catalog.category IS 'Functional category: auth, access, validation, entity, workflow, system.';
COMMENT ON COLUMN db.error_catalog.created_at IS 'Timestamp when the error code was registered.';

CREATE UNIQUE INDEX ON db.error_catalog (code);
CREATE INDEX ON db.error_catalog (http_code);
CREATE INDEX ON db.error_catalog (category);

--------------------------------------------------------------------------------
-- ERROR_CATALOG_TEXT ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.error_catalog_text (
  error_id    uuid NOT NULL REFERENCES db.error_catalog(id) ON DELETE CASCADE,
  locale      uuid NOT NULL REFERENCES db.locale(id) ON DELETE RESTRICT,
  message     text NOT NULL,
  description text,
  resolution  text,
  PRIMARY KEY (error_id, locale)
);

COMMENT ON TABLE db.error_catalog_text IS 'Locale-specific error messages, descriptions, and resolution guidance.';
COMMENT ON COLUMN db.error_catalog_text.error_id IS 'Reference to the error catalog entry.';
COMMENT ON COLUMN db.error_catalog_text.locale IS 'Target locale for this translation.';
COMMENT ON COLUMN db.error_catalog_text.message IS 'Short user-facing error message (e.g., "Access denied."). May contain %s placeholders.';
COMMENT ON COLUMN db.error_catalog_text.description IS 'Detailed explanation for documentation and support agents.';
COMMENT ON COLUMN db.error_catalog_text.resolution IS 'Recommended steps to resolve the error.';
```

**Step 2:** Create `error/create.psql` and `error/update.psql` (include table.sql in create only, routine/api/rest/view in both).

**Step 3:** Wire into platform `create.psql` and `update.psql` — add `\ir error/create.psql` / `\ir error/update.psql` after `exception` module (position 7.5 — between exception and registry).

**Step 4:** Commit.

```bash
git add error/ create.psql update.psql
git commit -m "feat(error): create error_catalog and error_catalog_text tables"
```

---

## Task 3: Create error_catalog module — routines

**Files:**
- Create: `error/routine.sql`

**Step 1:** Implement core functions following vendor pattern:

- `CreateErrorCatalog(pCode, pHttpCode, pSeverity, pCategory)` → returns uuid
- `EditErrorCatalog(pId, pCode, pHttpCode, pSeverity, pCategory)` → void
- `GetErrorCatalog(pCode)` → returns uuid (lookup by code string)
- `DeleteErrorCatalog(pId)` → void
- `SetErrorCatalogText(pErrorId, pLocale, pMessage, pDescription, pResolution)` → void (upsert)
- `GetErrorCatalogMessage(pCode, pLocale)` → returns text (message for given locale, fallback to 'en')
- `RegisterError(pCode, pHttpCode, pSeverity, pCategory, pLocaleCode, pMessage, pDescription, pResolution)` → uuid (convenience: create or get + set text)

Key: `GetErrorCatalogMessage()` must fallback to 'en' if current locale has no translation:
```sql
SELECT coalesce(
  (SELECT message FROM db.error_catalog_text WHERE error_id = uId AND locale = current_locale()),
  (SELECT message FROM db.error_catalog_text WHERE error_id = uId AND locale = GetLocale('en'))
);
```

**Step 2:** Commit.

```bash
git add error/routine.sql
git commit -m "feat(error): add error_catalog CRUD and RegisterError functions"
```

---

## Task 4: Create error_catalog module — views + API + REST

**Files:**
- Create: `error/view.sql`
- Create: `error/api.sql`
- Create: `error/rest.sql`

**Step 1:** Create `error/view.sql` — view joining error_catalog with error_catalog_text for current locale:

```sql
CREATE OR REPLACE VIEW ErrorCatalog
AS
  SELECT ec.id, ec.code, ec.http_code, ec.severity, ec.category,
         ect.message, ect.description, ect.resolution,
         ec.created_at
    FROM db.error_catalog ec
    LEFT JOIN db.error_catalog_text ect ON ect.error_id = ec.id AND ect.locale = current_locale();

CREATE OR REPLACE VIEW api.error_catalog
AS
  SELECT * FROM ErrorCatalog;

GRANT SELECT ON api.error_catalog TO administrator;
```

**Step 2:** Create `error/api.sql` — standard API wrappers:
- `api.add_error(pCode, pHttpCode, pSeverity, pCategory, pMessage, pDescription, pResolution)` — create + text for current locale
- `api.update_error(pId, ...)` — edit
- `api.get_error(pCode)` — get by code
- `api.delete_error(pId)` — delete
- `api.error_catalog` view is queryable via standard list/count pattern

**Step 3:** Create `error/rest.sql` — REST dispatcher `rest.error()`:
- `GET /error/{code}` → api.get_error
- `POST /error/list` → standard list from api.error_catalog view
- `POST /error/count` → standard count

**Step 4:** Register route in `api/init.sql` or `init.sql` — add path and endpoint for `/error`.

**Step 5:** Commit.

```bash
git add error/
git commit -m "feat(error): add error_catalog views, API wrappers, and REST dispatcher"
```

---

## Task 5: Update ParseMessage() for dual format

**Files:**
- Modify: `exception/routine.sql` (lines 11-26)

**Step 1:** Rewrite `ParseMessage()` to support both formats:

```sql
CREATE OR REPLACE FUNCTION ParseMessage (
  pMessage    text,
  OUT code    int,
  OUT message text,
  OUT error   text     -- NEW: structured error identifier
) RETURNS     record
AS $$
BEGIN
  IF SubStr(pMessage, 1, 4) = 'ERR-' THEN
    -- Try new format: ERR-GGG-CCC: message
    IF SubStr(pMessage, 8, 1) = '-' AND SubStr(pMessage, 12, 2) = ': ' THEN
      code := SubStr(pMessage, 5, 3)::int;
      error := SubStr(pMessage, 1, 11);           -- 'ERR-400-001'
      message := SubStr(pMessage, 14);
    -- Old format: ERR-GGGCC: message
    ELSIF SubStr(pMessage, 10, 2) = ': ' THEN
      code := SubStr(pMessage, 5, 3)::int;
      error := format('ERR-%s-%s', SubStr(pMessage, 5, 3),
                       lpad(SubStr(pMessage, 8, 2), 3, '0'));  -- Convert to new format
      message := SubStr(pMessage, 12);
    ELSE
      code := -1;
      error := null;
      message := pMessage;
    END IF;
  ELSE
    code := -1;
    error := null;
    message := pMessage;
  END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
```

**Step 2:** Update all callers of ParseMessage that use `SELECT * INTO ErrorCode, ErrorMessage FROM ParseMessage(...)` — they now have a third OUT field `error`. Check:
- `api/api.sql` — api.run() exception handler
- `log/routine.sql` — WriteDiagnostics()

**Step 3:** Commit.

```bash
git add exception/routine.sql api/api.sql log/routine.sql
git commit -m "feat(exception): update ParseMessage for dual ERR-GGG-CCC/ERR-GGGCC format"
```

---

## Task 6: Update GetExceptionStr() and api.run()

**Files:**
- Modify: `exception/routine.sql` (lines 56-64) — GetExceptionStr
- Modify: `api/api.sql` (lines 411-426) — api.run() exception handler

**Step 1:** Update `GetExceptionStr()` to read from error_catalog first, fallback to resource tree:

```sql
CREATE OR REPLACE FUNCTION GetExceptionStr (
  pErrGroup   integer,
  pErrCode    integer
) RETURNS     text
AS $$
DECLARE
  vCode       text;
  vMessage    text;
BEGIN
  vCode := format('ERR-%s-%s',
    NULLIF(IntToStr(pErrGroup, 'FM000'), '###'),
    NULLIF(IntToStr(pErrCode, 'FM000'), '###'));

  -- Try error_catalog first
  SELECT ect.message INTO vMessage
    FROM db.error_catalog ec
    JOIN db.error_catalog_text ect ON ect.error_id = ec.id
   WHERE ec.code = vCode
     AND ect.locale = coalesce(current_locale(), GetLocale('en'));

  -- Fallback to en locale
  IF vMessage IS NULL THEN
    SELECT ect.message INTO vMessage
      FROM db.error_catalog ec
      JOIN db.error_catalog_text ect ON ect.error_id = ec.id
     WHERE ec.code = vCode
       AND ect.locale = GetLocale('en');
  END IF;

  -- Fallback to resource tree (backward compat)
  IF vMessage IS NULL THEN
    vMessage := GetResource(GetExceptionUUID(pErrGroup, pErrCode));
  END IF;

  RETURN format('%s: %s.', vCode, coalesce(vMessage, 'Unknown error'));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
```

**Step 2:** Update `api.run()` exception handler to include `error` field:

```sql
-- In the EXCEPTION WHEN block, change the JSON builder:
SELECT * INTO ErrorCode, ErrorMessage, vErrorId FROM ParseMessage(vMessage);

RETURN NEXT json_build_object('error', json_build_object(
  'code',    coalesce(nullif(ErrorCode, -1), 500),
  'error',   vErrorId,           -- 'ERR-400-001' or null
  'message', ErrorMessage
));
```

Note: variable name `vErrorId` holds the string identifier like 'ERR-400-001'.

**Step 3:** Commit.

```bash
git add exception/routine.sql api/api.sql
git commit -m "feat(exception): GetExceptionStr reads error_catalog, api.run adds error field"
```

---

## Task 7: Register all 84 platform exceptions into error_catalog

**Files:**
- Create: `error/init.sql` — seed data for all exceptions

**Step 1:** Create `error/init.sql`. For each of the 84 exceptions currently in `exception/routine.sql`, register:
- Error catalog entry (code, http_code, severity, category)
- Text in 6 locales (en, ru + de, fr, it, es)

Use the `RegisterError()` convenience function. Map current group:code pairs to new `ERR-GGG-CCC` codes.

**Error code assignment strategy:**
- Group 401 (auth): ERR-401-001 through ERR-401-0XX — LoginFailed, AuthenticateError, TokenError, etc.
- Group 400 (validation/entity/workflow): ERR-400-001 through ERR-400-0XX
- Group 403 (access): ERR-403-001 through ERR-403-0XX
- Group 500 (system): ERR-500-001 through ERR-500-0XX

Source for en and ru messages: current `CreateExceptionResource()` calls in `exception/routine.sql`.
Translations for de, fr, it, es: translate from en.

**Step 2:** Update `exception/routine.sql` — change all 84 functions to use new format string:
- `GetExceptionStr(401, 1)` stays the same (GetExceptionStr now reads from error_catalog)
- But the format output changes from `ERR-40101:` to `ERR-401-001:` (handled inside GetExceptionStr)

**Step 3:** Remove old `CreateExceptionResource()` calls from `exception/routine.sql` (replaced by `error/init.sql`). Keep `CreateExceptionResource()` function itself for backward compat with configuration layers.

**Step 4:** Commit.

```bash
git add error/init.sql exception/routine.sql
git commit -m "feat(error): register all 84 platform exceptions in error_catalog with 6 locales"
```

---

## Task 8: Migrate hardcoded Russian strings — ObjectNotFound

**Files:**
- Modify: 10+ `api.sql` files across entity modules

**Step 1:** Replace all `ObjectNotFound('русский текст', ...)` calls with English entity names:

| Current | New |
|---------|-----|
| `ObjectNotFound('область видимости', 'id', pArea)` | `ObjectNotFound('scope', 'id', pArea)` |
| `ObjectNotFound('интерфейс', 'id', pInterface)` | `ObjectNotFound('interface', 'id', pInterface)` |
| `ObjectNotFound('язык', 'id', pLocale)` | `ObjectNotFound('locale', 'id', pLocale)` |
| `ObjectNotFound('объект', 'id', pId)` | `ObjectNotFound('object', 'id', pId)` |
| `ObjectNotFound('документ', 'id', pId)` | `ObjectNotFound('document', 'id', pId)` |
| `ObjectNotFound('справочник', 'id', pId)` | `ObjectNotFound('reference', 'id', pId)` |
| `ObjectNotFound('производитель', 'id', pId)` | `ObjectNotFound('vendor', 'id', pId)` |
| `ObjectNotFound('агент', 'id', pId)` | `ObjectNotFound('agent', 'id', pId)` |
| `ObjectNotFound('планировщик', 'id', pId)` | `ObjectNotFound('scheduler', 'id', pId)` |
| `ObjectNotFound('форма', 'id', pId)` | `ObjectNotFound('form', 'id', pId)` |
| `ObjectNotFound('форма журнала', 'id', pId)` | `ObjectNotFound('form field', 'id', pId)` |
| `ObjectNotFound('функция отчёта', 'id', pId)` | `ObjectNotFound('report routine', 'id', pId)` |

Files: `session/api.sql`, `entity/object/api.sql`, `entity/object/reference/api.sql`, `entity/object/reference/*/api.sql`, `entity/object/document/api.sql`, `report/routine/api.sql`

**Step 2:** Commit.

```bash
git add session/ entity/ report/
git commit -m "fix(i18n): replace Russian entity names in ObjectNotFound with English"
```

---

## Task 9: Migrate hardcoded Russian strings — SetErrorMessage

**Files:**
- Modify: `admin/routine.sql` (~11 instances)
- Modify: `verification/routine.sql` (~5 instances)
- Modify: `admin/api.sql` (~1 instance)

**Step 1:** For each `SetErrorMessage('русский текст')` call, either:
- **A)** Register as a new error in `error/init.sql` and use `SetErrorMessage(GetErrorCatalogMessage('ERR-...'))`, OR
- **B)** Replace with English text directly if message is simple validation feedback (not user-facing exception)

Strategy: Use option B for simple status messages (e.g., "Email confirmed", "Phone confirmed") since these are set via SetErrorMessage for internal use, not raised as exceptions. Use option A for actual error conditions.

**Step 2:** Commit.

```bash
git add admin/ verification/ error/
git commit -m "fix(i18n): migrate SetErrorMessage Russian strings to English/error_catalog"
```

---

## Task 10: Translate event log messages to English

**Files:**
- Modify: ~20 `event.sql` files across entity modules

**Step 1:** Replace all Russian event log messages with English equivalents. Pattern:

| Current | New |
|---------|-----|
| `'Программа создана.'` | `'Program created.'` |
| `'Программа открыта на просмотр.'` | `'Program opened.'` |
| `'Программа изменена.'` | `'Program modified.'` |
| `'Программа сохранена.'` | `'Program saved.'` |
| `'Программа включена.'` | `'Program enabled.'` |
| `'Программа отключена.'` | `'Program disabled.'` |
| `'Программа удалена.'` | `'Program deleted.'` |
| `'Программа восстановлена.'` | `'Program restored.'` |
| `'Программа уничтожена.'` | `'Program dropped.'` |

Apply same pattern for: form, scheduler, vendor, agent, version, reference, document, job, message, inbox, outbox, notice, comment, report, report_tree, report_form, report_routine, report_ready, object.

~166 messages total across ~20 event.sql files.

**Step 2:** Commit.

```bash
git add entity/ notice/ comment/ notification/ verification/ observer/ report/
git commit -m "fix(i18n): translate all event log messages to English"
```

---

## Task 11: Fill description and resolution for all error codes

**Files:**
- Modify: `error/init.sql`

**Step 1:** For each of the 84 error codes, add meaningful `description` and `resolution` in English:

Example for ERR-401-001 (LoginFailed):
- **message:** `'Login failed.'`
- **description:** `'Authentication was rejected. The user has not signed in or the session has expired.'`
- **resolution:** `'Sign in with valid credentials. If the problem persists, reset your password or contact support.'`

Example for ERR-400-001 (AccessDenied):
- **message:** `'Access denied.'`
- **description:** `'The current user does not have sufficient permissions to perform the requested operation.'`
- **resolution:** `'Verify that your account has the required role or group membership. Contact your administrator to request access.'`

Process all 84 errors. Focus on en locale first — other locales get description/resolution in Task 13.

**Step 2:** Commit.

```bash
git add error/init.sql
git commit -m "docs(error): add description and resolution for all 84 error codes"
```

---

## Task 12: Generate error-codes.md and migration guide

**Files:**
- Create: `docs/error-codes.md`
- Create: `docs/migration-1.2.0.md`

**Step 1:** Create `docs/error-codes.md` — structured reference of all error codes:

```markdown
# Error Code Reference

## Format

`ERR-GGG-CCC` where GGG = HTTP status group, CCC = unique code.

## Authentication (ERR-401-xxx)

| Code | Function | Message | Resolution |
|------|----------|---------|------------|
| ERR-401-001 | LoginFailed | Login failed. | Sign in with valid credentials. |
| ... | ... | ... | ... |

## Validation (ERR-400-xxx)
...
```

**Step 2:** Create `docs/migration-1.2.0.md` — guide for downstream projects:

Cover:
- New error format ERR-GGG-CCC
- How to register project-specific exceptions using RegisterError()
- JSON response format change (new `error` field)
- ParseMessage() backward compatibility
- Replacing hardcoded Russian strings
- Replacing CreateExceptionResource() with RegisterError()

**Step 3:** Commit.

```bash
git add docs/
git commit -m "docs: add error-codes.md reference and migration-1.2.0.md guide"
```

---

## Task 13: Translate error_catalog_text to de, fr, it, es

**Files:**
- Modify: `error/init.sql`

**Step 1:** For all 84 error codes, add translations for de, fr, it, es locales:
- `message` — translate from en
- `description` — translate from en
- `resolution` — translate from en

Total: 84 errors × 4 new locales × 3 fields = 1008 translations.

Use RegisterError() calls grouped by locale for readability:

```sql
-- German (de)
SELECT RegisterError('ERR-401-001', 401, 'E', 'auth', 'de', 'Anmeldung fehlgeschlagen.', 'Die Authentifizierung wurde abgelehnt...', 'Melden Sie sich mit gültigen Anmeldedaten an...');
-- French (fr)
SELECT RegisterError('ERR-401-001', 401, 'E', 'auth', 'fr', 'Échec de la connexion.', 'L''authentification a été rejetée...', 'Connectez-vous avec des identifiants valides...');
-- Italian (it)
SELECT RegisterError('ERR-401-001', 401, 'E', 'auth', 'it', 'Accesso non riuscito.', 'L''autenticazione è stata rifiutata...', 'Accedere con credenziali valide...');
-- Spanish (es)
SELECT RegisterError('ERR-401-001', 401, 'E', 'auth', 'es', 'Error de inicio de sesión.', 'La autenticación fue rechazada...', 'Inicie sesión con credenciales válidas...');
```

**Step 2:** Commit.

```bash
git add error/init.sql
git commit -m "feat(i18n): add de, fr, it, es translations for all 84 error codes"
```

---

## Task 14: Update VERSION to 1.2.0

**Files:**
- Modify: `VERSION`
- Modify: `CLAUDE.md` (update version reference)

**Step 1:** Set VERSION content to `1.2.0`.

**Step 2:** Update CLAUDE.md version reference.

**Step 3:** Commit.

```bash
git add VERSION CLAUDE.md
git commit -m "chore: bump version to 1.2.0"
```

---

## Task 15: libapostol — pass error field through (separate repo)

**Repo:** `~/DevSrc/Projects/libapostol/framework/`

**Files:**
- Modify: `src/app/pg_utils.cpp` (or equivalent) — `check_pg_error()` function
- Modify: HTTP response builder — include `error` string field from JSON

**Step 1:** In `check_pg_error()`:
- Parse `"error"` string field from PG JSON response alongside `"code"` and `"message"`
- Store in error structure for pass-through

**Step 2:** In response builder:
- If `error` field present in PG response, include it in HTTP response body as-is
- If absent, omit (backward compatible)

**Step 3:** Commit to libapostol repo.

```bash
git commit -m "feat: pass error identifier field through in JSON error responses"
```

**Note:** This task is in a SEPARATE repository. Coordinate with db-platform release.

---

## Summary

| Task | Module | What | Complexity |
|-----:|--------|------|-----------|
| 1 | locale | Add es locale, verify all 6 | Tiny |
| 2 | error | Create tables (DDL) | Small |
| 3 | error | Create routines (CRUD + RegisterError) | Medium |
| 4 | error | Create views, API, REST | Medium |
| 5 | exception | Update ParseMessage() dual format | Small |
| 6 | exception + api | Update GetExceptionStr() + api.run() | Medium |
| 7 | error + exception | Register 84 exceptions × 6 locales (en+ru) | Large |
| 8 | entity modules | Migrate ObjectNotFound Russian → English | Small |
| 9 | admin + verification | Migrate SetErrorMessage Russian | Small |
| 10 | entity modules | Translate 166 event log messages | Medium |
| 11 | error | Fill description + resolution (en) | Large |
| 12 | docs | error-codes.md + migration-1.2.0.md | Medium |
| 13 | error | Translate to de, fr, it, es | Large |
| 14 | root | Bump VERSION to 1.2.0 | Tiny |
| 15 | libapostol | Pass error field in C++ | Small (separate repo) |
