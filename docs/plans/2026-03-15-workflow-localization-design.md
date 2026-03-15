# Workflow & Entity Localization — Design Document

**Goal:** Make all workflow and entity UI-facing strings multilingual (en, ru, de, fr, it, es) by adding translations to init.sql files using the existing `_text` table + `Edit*Text()` infrastructure.

**Version:** 1.2.1

**Date:** 2026-03-15

---

## Context

Platform v1.2.0 introduced the error_catalog with full 6-locale support. The `_text` table pattern and `Edit*Text()` functions already exist for all workflow and entity tables (10 `_text` tables in workflow, 3 in entity). However, only 2 of 6 supported locales are seeded:

- **workflow/init.sql** and **report/tree/init.sql**: Russian (primary in `Add*()`) + English (via `Edit*Text()`)
- **17 entity init.sql files**: Russian only (replicated to all locales by `Add*()`)

Users with de/fr/it/es locales see Russian text for all workflow labels, entity names, class names, type names, states, methods, actions, priorities.

## Decision: English as Base Language

Switch the primary language in all `Add*()` calls from Russian to English. This means:
- Any new locale added in the future gets English as fallback (not Russian)
- English is the universal fallback for missing translations
- Russian moves to `Edit*Text(..., GetLocale('ru'))` like all other non-English locales

## Scope

### Category A — Already use Edit*Text (2 files, 61 strings)

| File | Strings | Current | Change |
|------|---------|---------|--------|
| `workflow/init.sql` | 57 | ru + en | Switch base to en, add de/fr/it/es |
| `report/tree/init.sql` | 4 | ru + en | Switch base to en, add de/fr/it/es |

### Category B — Only Russian in Add*() (17 files, 108 strings)

| File | Strings | Change |
|------|---------|--------|
| `entity/object/init.sql` | 2 | Switch to en, add ru/de/fr/it/es |
| `entity/object/reference/init.sql` | 2 | Switch to en, add ru/de/fr/it/es |
| `entity/object/document/init.sql` | 2 | Switch to en, add ru/de/fr/it/es |
| `entity/object/reference/agent/init.sql` | 10 | Switch to en, add ru/de/fr/it/es |
| `entity/object/reference/form/init.sql` | 8 | Switch to en, add ru/de/fr/it/es |
| `entity/object/reference/program/init.sql` | 4 | Switch to en, add ru/de/fr/it/es |
| `entity/object/reference/scheduler/init.sql` | 4 | Switch to en, add ru/de/fr/it/es |
| `entity/object/reference/vendor/init.sql` | 8 | Switch to en, add ru/de/fr/it/es |
| `entity/object/reference/version/init.sql` | 4 | Switch to en, add ru/de/fr/it/es |
| `entity/object/document/job/init.sql` | 15 | Switch to en, add ru/de/fr/it/es |
| `entity/object/document/message/init.sql` | 2 | Switch to en, add ru/de/fr/it/es |
| `entity/object/document/message/inbox/init.sql` | 7 | Switch to en, add ru/de/fr/it/es |
| `entity/object/document/message/outbox/init.sql` | 9 | Switch to en, add ru/de/fr/it/es |
| `report/init.sql` | 10 | Switch to en, add ru/de/fr/it/es |
| `report/form/init.sql` | 4 | Switch to en, add ru/de/fr/it/es |
| `report/routine/init.sql` | 4 | Switch to en, add ru/de/fr/it/es |
| `report/ready/init.sql` | 13 | Switch to en, add ru/de/fr/it/es |

### Out of Scope

- `admin/init.sql` — business configuration data (areas, users, groups)
- `error/init.sql` — already fully localized in v1.2.0
- `locale/init.sql` — locale metadata, already complete
- API registration init.sql files — no translatable text
- Table DDL, routines, views — no changes needed

## Pattern

**Before (current):**
```sql
uAction := AddAction(uId, 'create', 'Создать');
PERFORM EditActionText(uAction, 'Create', null, GetLocale('en'));
```

**After:**
```sql
uAction := AddAction(uId, 'create', 'Create');
PERFORM EditActionText(uAction, 'Создать', null, GetLocale('ru'));
PERFORM EditActionText(uAction, 'Erstellen', null, GetLocale('de'));
PERFORM EditActionText(uAction, 'Créer', null, GetLocale('fr'));
PERFORM EditActionText(uAction, 'Creare', null, GetLocale('it'));
PERFORM EditActionText(uAction, 'Crear', null, GetLocale('es'));
```

## Totals

- **169 unique strings** across 19 init.sql files
- **784 Edit*Text calls** to add
- **0 DDL/routine/view changes**
- Version bump: 1.2.0 → 1.2.1
- Migration doc: `docs/migration-1.2.1.md`

## Edit*Text Functions Used

All already exist in workflow/routine.sql and entity routines:

| Function | For |
|----------|-----|
| `EditEntityText(id, name, description, locale)` | Entity names |
| `EditClassText(id, label, locale)` | Class labels |
| `EditTypeText(id, name, description, locale)` | Type names |
| `EditStateTypeText(id, name, description, locale)` | State type names |
| `EditStateText(id, label, locale)` | State labels |
| `EditActionText(id, name, description, locale)` | Action names |
| `EditMethodText(id, label, locale)` | Method labels |
| `EditEventTypeText(id, name, description, locale)` | Event type names |
| `EditEventText(id, label, locale)` | Event labels |
| `EditPriorityText(id, name, description, locale)` | Priority names |
