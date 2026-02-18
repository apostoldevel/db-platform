# entity

> Platform module #18 | Loaded by `create.psql` line 18

**The entity system — largest platform module.** Encompasses the entire business object hierarchy: `object` (core), `reference` (catalogs), and `document` (business documents). All entities share a common object lifecycle (create → enable ↔ disable → delete) managed by the workflow engine. This module also contains the `InitEntity()` function that registers the complete class tree.

## Dependencies

| Depends on | Depended by |
|------------|-------------|
| All modules 1-17 (especially `workflow` for state machine, `admin` for users/scope) | All configuration entities |

## Class Tree (registered by `InitEntity()`)

```
object (abstract root)
├── reference (abstract)
│     ├── agent          — message delivery channels
│     ├── form           — dynamic forms (with field sub-table)
│     ├── program        — PL/pgSQL stored programs
│     ├── scheduler      — periodic job schedulers
│     ├── vendor         — suppliers/manufacturers
│     ├── version        — API versions
│     ├── report_tree    — report section hierarchy
│     ├── report_form    — report input forms
│     ├── report_routine — report generation routines
│     └── report         — report definitions
└── document (abstract)
      ├── job            — scheduled/one-time tasks
      ├── message (abstract)
      │     ├── inbox    — incoming messages
      │     └── outbox   — outgoing messages
      └── report_ready   — generated report outputs
```

## Loading Order (entity/create.psql)

```
entity/
  object/create.psql          ← Core object module (14 tables, ~130 functions, ~65 REST routes)
    ├── table.sql, security.sql, view.sql, routine.sql, api.sql, rest.sql, event.sql, init.sql
    ├── reference/create.psql  ← Reference hierarchy (2 tables + 7 sub-entities)
    │     ├── form/create.psql → form/field/create.psql
    │     ├── vendor, agent, program, scheduler, version
    │     └── init.sql
    ├── document/create.psql   ← Document hierarchy (2 tables + job + message)
    │     ├── job/create.psql
    │     ├── message/create.psql → inbox, outbox
    │     └── init.sql
    └── search.sql             ← Full-text search (EN/RU)
  init.sql                     ← InitEntity() — registers full class tree
  do.sql                       ← DoConfirmEmail, DoConfirmPhone, DoFCMTokens
```

## InitEntity()

Registers the complete class tree by calling `CreateEntity*` functions:

```sql
-- Object
uEntity := CreateEntityObject(null);

-- References
uEntity := CreateEntityReference(GetClass('object'));
-- ... (agent, form, program, scheduler, vendor, version)

-- Documents
uEntity := CreateEntityDocument(GetClass('object'));
-- ... (job, message → inbox + outbox)

-- Reports
-- (report_tree, report_form, report_routine, report, report_ready)
```

## do.sql (Configuration Hooks)

| Function | Purpose |
|----------|---------|
| `DoConfirmEmail(pUserId)` | Called after email verification (no-op in platform, overridden in config) |
| `DoConfirmPhone(pUserId)` | Called after phone verification |
| `DoFCMTokens(pUserId)` | Return Firebase Cloud Messaging tokens for user |

## Module Statistics

| Sub-module | Tables | Views | Kernel Functions | API Functions | REST Routes |
|------------|--------|-------|-----------------|---------------|-------------|
| **object** (core) | 14 | 13 | ~130 | ~70 | ~65 |
| **reference** (base + 7 sub-entities) | 2 + 8 | 4 + 21 | 8 + ~25 | 6 + ~45 | 6 + ~45 |
| **document** (base + job + message/inbox/outbox) | 2 + 2 | 6 + 12 | 14 + 36 | 7 + 37 | 7 + 21+ |
| **search** | 0 | 0 | 3 | 0 | 0 |
| **Total** | ~28 | ~56 | ~216 | ~165 | ~144+ |

## Detailed INDEX.md Files

- [`entity/object/INDEX.md`](object/INDEX.md) — Core object module
- [`entity/object/reference/INDEX.md`](object/reference/INDEX.md) — Reference hierarchy
- [`entity/object/document/INDEX.md`](object/document/INDEX.md) — Document hierarchy

## File Manifest

| File | In create | In update | Purpose |
|------|:---------:|:---------:|---------|
| `object/create.psql` | yes | - | Core object + reference/ + document/ + search |
| `init.sql` | yes | no | `InitEntity()` — registers full class tree |
| `do.sql` | yes | yes | Configuration hooks (DoConfirmEmail, etc.) |
| `create.psql` | - | - | Includes object/create.psql, init.sql, do.sql |
| `update.psql` | - | - | Includes object/update.psql, do.sql |
