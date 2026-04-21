# Migration Guide: v1.2.0 → v1.2.1 — Configuration Layer Localization

> **Audience:** AI agents tasked with localizing `configuration/<dbname>/` init.sql files.
> This document teaches you how to apply the same 6-locale pattern (en, ru, de, fr, it, es)
> that platform v1.2.1 uses internally.

## What Changed in Platform v1.2.1

English is now the **base language** for all `Add*()` calls in platform init.sql files.
Previously Russian text was replicated to all locales by `Add*()` internals; now English
is the universal fallback. Russian and 4 other locales are set via `Edit*Text()` calls.

**No schema changes.** No table, view, or function signature changes. Only init.sql
seed data is affected. Safe to apply with `--install`.

### Breaking Change: AddDefaultMethods() Signature

```sql
-- OLD (v1.2.0): first positional array = Russian
PERFORM AddDefaultMethods(uClass, ARRAY['Создан', ...], ARRAY['Created', ...]);

-- NEW (v1.2.1): first positional array = English, second = Russian
PERFORM AddDefaultMethods(uClass, ARRAY['Created', ...], ARRAY['Создан', ...]);
```

If you pass only one array, it is now treated as **English** (was Russian).

---

## Configuration Layer: Current State

A typical configuration project (e.g., ChargeMeCar) uses these patterns:

1. **`AddEntity(code, 'Russian name')`** — Russian in all Add*() calls
2. **`AddClass(parent, entity, code, 'Russian name', bool)`** — Russian
3. **`AddType(class, code, 'Russian name', 'Russian description')`** — Russian,
   with optional `EditTypeText(uType, 'English', 'Desc', GetLocale('en'))` inline
4. **`AddState(class, type, code, 'Russian label')`** — Russian only
5. **`AddMethod(null, class, state, action, null, 'Russian label')`** — Russian only
6. **`AddEvent(class, type, action, 'Russian description')`** — Russian only
7. **`AddDefaultMethods(uClass, ARRAY[ru...], ARRAY[en...])`** — Russian + English
8. **Bulk UPDATE in FillDataBase()** — patches `db.*_text` tables with English via
   hardcoded locale UUID `'00000000-0000-4001-a000-000000000001'`

---

## Step-by-Step: How to Localize a Configuration Project

### Phase 1: Audit

1. Find all init.sql files: `find configuration/<dbname>/ -name init.sql`
2. For each file, identify:
   - `AddEntity()` calls — need EditEntityText for 5 locales
   - `AddClass()` calls — need EditClassText for 5 locales
   - `AddType()` calls — need EditTypeText for 5 locales
   - `AddState()` calls — need EditStateText for 5 locales
   - `AddMethod()` calls — need EditMethodText for 5 locales (only custom methods; AddDefaultMethods handles its own)
   - `AddEvent()` calls — switch label to English (events are internal metadata, no per-locale Edit needed)
   - `AddDefaultMethods()` calls — swap parameter order (English first)
3. Check main init.sql for bulk UPDATE translation patches — replace with Edit*Text pattern

### Phase 2: Transform Each Entity init.sql

#### Pattern A: AddEntity + EditEntityText

**Before:**
```sql
uEntity := AddEntity('account', 'Счёт');
```

**After:**
```sql
uEntity := AddEntity('account', 'Account');
PERFORM EditEntityText(uEntity, 'Счёт', null, GetLocale('ru'));
PERFORM EditEntityText(uEntity, 'Konto', null, GetLocale('de'));
PERFORM EditEntityText(uEntity, 'Compte', null, GetLocale('fr'));
PERFORM EditEntityText(uEntity, 'Conto', null, GetLocale('it'));
PERFORM EditEntityText(uEntity, 'Cuenta', null, GetLocale('es'));
```

#### Pattern B: AddClass + EditClassText

**Before:**
```sql
uClass := AddClass(pParent, pEntity, 'account', 'Лицевой счёт', false);
```

**After:**
```sql
uClass := AddClass(pParent, pEntity, 'account', 'Account', false);
PERFORM EditClassText(uClass, 'Лицевой счёт', GetLocale('ru'));
PERFORM EditClassText(uClass, 'Konto', GetLocale('de'));
PERFORM EditClassText(uClass, 'Compte', GetLocale('fr'));
PERFORM EditClassText(uClass, 'Conto', GetLocale('it'));
PERFORM EditClassText(uClass, 'Cuenta', GetLocale('es'));
```

#### Pattern C: AddType + EditTypeText

**Before:**
```sql
uType := AddType(uClass, 'active.account', 'Активный', 'Активный счёт.');
PERFORM EditTypeText(uType, 'Active', 'Active account.', GetLocale('en'));
```

**After:**
```sql
uType := AddType(uClass, 'active.account', 'Active', 'Active account.');
PERFORM EditTypeText(uType, 'Активный', 'Активный счёт.', GetLocale('ru'));
PERFORM EditTypeText(uType, 'Aktiv', 'Aktives Konto.', GetLocale('de'));
PERFORM EditTypeText(uType, 'Actif', 'Compte actif.', GetLocale('fr'));
PERFORM EditTypeText(uType, 'Attivo', 'Conto attivo.', GetLocale('it'));
PERFORM EditTypeText(uType, 'Activo', 'Cuenta activa.', GetLocale('es'));
```

#### Pattern D: AddState + EditStateText (custom state machines)

**Before:**
```sql
nState := AddState(pClass, rec_type.id, rec_type.code, 'Создана');
```

**After:**
```sql
nState := AddState(pClass, rec_type.id, rec_type.code, 'Created');
PERFORM EditStateText(nState, 'Создана', GetLocale('ru'));
PERFORM EditStateText(nState, 'Erstellt', GetLocale('de'));
PERFORM EditStateText(nState, 'Creee', GetLocale('fr'));
PERFORM EditStateText(nState, 'Creata', GetLocale('it'));
PERFORM EditStateText(nState, 'Creada', GetLocale('es'));
```

#### Pattern E: AddMethod + EditMethodText (custom methods only)

**Before:**
```sql
PERFORM AddMethod(null, pClass, nState, GetAction('enable'), null, 'Включить');
```

**After:**
```sql
uMethod := AddMethod(null, pClass, nState, GetAction('enable'), null, 'Enable');
PERFORM EditMethodText(uMethod, 'Включить', GetLocale('ru'));
PERFORM EditMethodText(uMethod, 'Aktivieren', GetLocale('de'));
PERFORM EditMethodText(uMethod, 'Activer', GetLocale('fr'));
PERFORM EditMethodText(uMethod, 'Attivare', GetLocale('it'));
PERFORM EditMethodText(uMethod, 'Activar', GetLocale('es'));
```

Note: if the original code uses `PERFORM AddMethod(...)` (discards return value),
change to `uMethod := AddMethod(...)` to capture the UUID for Edit*Text calls.
Declare `uMethod uuid;` in the DECLARE block if not already present.

#### Pattern F: AddEvent — English label only

**Before:**
```sql
PERFORM AddEvent(pClass, uEvent, r.id, 'Счёт создан', 'EventAccountCreate();');
```

**After:**
```sql
PERFORM AddEvent(pClass, uEvent, r.id, 'Account created', 'EventAccountCreate();');
```

Events are internal metadata (handler labels), not end-user UI. Switch to English only.

#### Pattern G: AddDefaultMethods — swap parameter order

**Before (v1.2.0):**
```sql
PERFORM AddDefaultMethods(uClass,
  ARRAY['Создан', 'Открыт', 'Закрыт', 'Удалён', 'Открыть', 'Закрыть', 'Удалить'],
  ARRAY['Created', 'Opened', 'Closed', 'Deleted', 'Open', 'Close', 'Delete']);
```

**After (v1.2.1):**
```sql
PERFORM AddDefaultMethods(uClass,
  ARRAY['Created', 'Opened', 'Closed', 'Deleted', 'Open', 'Close', 'Delete'],
  ARRAY['Создан', 'Открыт', 'Закрыт', 'Удалён', 'Открыть', 'Закрыть', 'Удалить']);
```

If no custom arrays were passed (just `AddDefaultMethods(uClass)`), no change needed —
the function's defaults are already swapped in v1.2.1.

### Phase 3: Remove Bulk UPDATE Patches

If the main `init.sql` (or `FillDataBase()`) contains bulk UPDATE statements like:

```sql
UPDATE db.entity_text SET name = 'Object' WHERE name = 'Объект'
  AND locale = '00000000-0000-4001-a000-000000000001'::uuid;
```

**Remove them.** These patches are no longer needed because:
- Platform entities now have English as base (v1.2.1)
- Configuration entities should use Edit*Text() inline (Phase 2)

Only keep UPDATEs for business data (e.g., reference names like vendor names,
service names) that are NOT part of the entity/workflow definition.

### Phase 4: Add Missing Locales (de, fr, it, es)

After Phase 2 handles ru (which was previously the base), add the remaining 4 locales.
Use the same Edit*Text pattern for de, fr, it, es.

For AddDefaultMethods entities where you only changed the parameter order (Pattern G),
the platform's `UpdateDefaultMethods()` already handles de/fr/it/es internally.
No additional calls needed for default states/methods.

For custom state machines (Pattern D, E), you must add EditStateText and EditMethodText
for all 5 non-English locales.

---

## Edit*Text Function Reference

| Function | Signature | For |
|----------|-----------|-----|
| `EditEntityText` | `(id, name, description, locale)` | Entity names |
| `EditClassText` | `(id, label, locale)` | Class labels |
| `EditTypeText` | `(id, name, description, locale)` | Type names + descriptions |
| `EditStateText` | `(id, label, locale)` | State labels |
| `EditMethodText` | `(id, label, locale)` | Method labels |
| `EditActionText` | `(id, name, description, locale)` | Action names (platform only) |
| `EditEventTypeText` | `(id, name, description, locale)` | Event type names (platform only) |
| `EditPriorityText` | `(id, name, description, locale)` | Priority names (platform only) |

Locale helper: `GetLocale('en')`, `GetLocale('ru')`, `GetLocale('de')`,
`GetLocale('fr')`, `GetLocale('it')`, `GetLocale('es')`.

---

---

## Phase 5: Force English Session Locale During Bootstrap

`AddMethod()` without an explicit `pLabel` resolves the label via
`GetActionName(pAction)` **for `current_locale()` at the moment of call**, and then
replicates that value to every row of `db.locale`:

```sql
-- platform/workflow/routine.sql: AddMethod() excerpt
pLabel := coalesce(pLabel, GetActionName(pAction));
FOR l IN SELECT id FROM db.locale
LOOP
  PERFORM NewMethodText(uId, pLabel, l.id);
END LOOP;
```

If `InitConfiguration()` runs with `SetSessionLocale(GetLocale('ru'))` — as happened
historically when `project.locale = 'ru'` — every locale's method label ends up stamped
with the Russian action name. The bug is silent: `en`/`de`/`fr`/… rows all contain the
Russian string.

**Fix in the project's `configuration/<dbname>/init.sql`:**

```sql
-- BEFORE: SetSessionLocale(GetLocale(current_setting('project.locale')))
-- followed by Init* and FillDataBase.

-- AFTER:
-- AddMethod() without explicit pLabel copies GetActionName(pAction) for current_locale()
-- into every db.locale row, so registration must run under 'en' to avoid poisoning all
-- locales. Project locale is restored after FillDataBase.
PERFORM SetSessionLocale(GetLocale('en'));

PERFORM InitConfigurationEntity();
PERFORM InitOCPP();
...
PERFORM FillDataBase();

PERFORM SetSessionLocale(GetLocale(current_setting('project.locale')));
```

This is a silent-failure fix: current code works when `project.locale='en'` (which
is the default for most brands), but breaks on any other locale. Apply proactively.

---

## Phase 6: Project-Specific Extra Locales

Platform seeds 6 locales: `en, ru, de, fr, it, es`. A configuration may add more in
`configuration/<dbname>/init.sql` before `SetSessionLocale()`:

```sql
-- Extra locales beyond the platform's 6 (en, ru, de, fr, it, es)
INSERT INTO db.locale (id, code, name, description) VALUES
  ('00000000-0000-4001-a000-000000000007', 'cs', 'Čeština',  'Český jazyk')
  ON CONFLICT (code) DO NOTHING;
INSERT INTO db.locale (id, code, name, description) VALUES
  ('00000000-0000-4001-a000-000000000008', 'sk', 'Slovenčina', 'Slovenský jazyk')
  ON CONFLICT (code) DO NOTHING;
```

Use UUIDs `…00000007`, `…00000008`, … — do not collide with platform's `…00000001..6`.
`ON CONFLICT DO NOTHING` keeps `--update` safe.

Once added, every `Edit*Text` pattern in the project may pass `GetLocale('cs')` /
`GetLocale('sk')` in addition to the platform's 6. The checklist items below apply
to the base 6 as the minimum — the project may extend on top.

---

## Phase 7: Replace Hardcoded Locale UUIDs

The platform's `db.locale` UUIDs look like `00000000-0000-4001-a000-00000000000X`.
Inlining them into application code breaks when:

- An environment re-seeds with different UUIDs (rare but possible).
- A project reshuffles its extra locales between brands.
- Readability of queries (what does `…000000000002` mean?).

**Audit:**

```bash
grep -rnE "00000000-0000-4001-a000-00000000000[0-9]" configuration/<dbname>/ \
  --include="*.sql" \
  | grep -v "INSERT INTO db.locale"
```

**Fix:** replace each hit with `GetLocale('ru')` / `GetLocale('en')` / etc.

**Exception — hot-path performance:**

`current_locale()` override in `configuration/<dbname>/admin/routine.sql` uses the
raw UUID as a fallback because it runs on every request:

```sql
CREATE OR REPLACE FUNCTION current_locale (
  pSession varchar DEFAULT current_session()
) RETURNS uuid
AS $$
BEGIN
  RETURN coalesce(GetSessionLocale(pSession), '00000000-0000-4001-a000-000000000001');
END;
$$ LANGUAGE plpgsql STABLE ...
```

Calling `GetLocale('en')` here would add a `SELECT` to a function the planner treats
as `STABLE` but that runs at every call. Leave the UUID here — add a comment so the
next auditor doesn't grep-and-replace it blindly.

---

## Checklist for AI Agent

- [ ] All `AddEntity()` calls use English as primary, with 5 `EditEntityText()` calls
- [ ] All `AddClass()` calls use English as primary, with 5 `EditClassText()` calls
- [ ] All `AddType()` calls use English as primary, with 5 `EditTypeText()` calls
- [ ] All `AddState()` calls use English as primary, with 5 `EditStateText()` calls
- [ ] Custom `AddMethod()` calls use English as primary, with 5 `EditMethodText()` calls
- [ ] All `AddEvent()` labels switched to English
- [ ] `AddDefaultMethods()` calls have swapped parameter order (English first, Russian second)
- [ ] Bulk UPDATE translation patches in FillDataBase() removed or replaced
- [ ] `PERFORM AddMethod(...)` changed to `uMethod := AddMethod(...)` where Edit*Text needed
- [ ] All `uMethod uuid` variables declared in DECLARE blocks
- [ ] No hardcoded locale UUIDs — use `GetLocale('xx')` everywhere (except `current_locale()` hot-path)
- [ ] `InitConfiguration()` forces `SetSessionLocale(GetLocale('en'))` before Init*/FillDataBase, restores `project.locale` after
- [ ] Project-added extra locales (cs/sk/etc.) live in `configuration/<dbname>/init.sql` with `ON CONFLICT DO NOTHING`
- [ ] Tested with `--install` (full reinstall with seed data)

---

## See Also

- [Platform 1.2.0 Migration Guide](migration-1.2.0.md) -- error catalog, inline `RAISE EXCEPTION` wrapping, runtime string localization patterns (+ `i18n/` resource module as the final shape)
- `platform/resource/` -- platform module that backs the configuration-level `i18n/` module (see `configuration/csms/i18n/` for a reference implementation)
- `platform/workflow/routine.sql` -- `AddMethod`, `GetActionName`, `EditMethodText`
- `platform/locale/routine.sql` -- `GetLocale`, `GetLocaleCode`
- `platform/admin/routine.sql` -- `GetDefaultLocale`, `SetSessionLocale`, `current_locale`
