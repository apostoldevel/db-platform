# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is this

**db-platform** is a PL/pgSQL framework (25 modules, 100+ tables, 800+ functions) that turns PostgreSQL into a full-featured application server: REST API, OAuth2, workflow engine, entity system, file storage, pub/sub, reports. Version: see `VERSION` file (currently 1.2.1).

This is the **framework layer** — it lives at `sql/platform/` inside consuming projects. Application code goes into `sql/configuration/<dbname>/`. Execution order is always platform first, then configuration.

## Database commands

All commands run from the **project's `db/` directory** (not from this repo directly). This repo is used as a git submodule at `sql/platform/`.

```bash
./runme.sh --update    # Safe: recreate routines + views only (day-to-day development)
./runme.sh --patch     # Tables + routines + views (migrations)
./runme.sh --install   # DESTRUCTIVE: drop/recreate DB with seed data
./runme.sh --create    # DESTRUCTIVE: drop/recreate DB without seed data
./runme.sh --init      # First run: create DB users + full install
./runme.sh --api       # Drop/recreate api schema only
./runme.sh --test      # Run pgTAP tests
```

**Automatic patch migration** (alternative to `--patch`):
```bash
sql/platform/migrate.sh             # Apply unapplied patches + update
sql/platform/migrate.sh --status    # Show applied/pending patches
sql/platform/migrate.sh --dry-run   # Preview what would be applied
sql/platform/migrate.sh --baseline  # Mark all patches as applied without executing
```

Connection: `PSQL` env var overrides the default `sudo -u postgres -H psql`.

## Architecture

### Schemas

| Schema | Purpose | Prefix required |
|--------|---------|-----------------|
| `db` | All tables | Always: `db.table_name` |
| `kernel` | Core business logic | No (in `search_path`) |
| `api` | API views + CRUD wrappers | Yes: `api.*` |
| `rest` | REST endpoint dispatchers | Yes: `rest.*` |
| `oauth2` | OAuth2 infrastructure | Yes: `oauth2.*` |
| `daemon` | C++ interface functions | Yes: `daemon.*` |

### DB users

- `kernel` — schema owner, all DDL, SECURITY DEFINER functions
- `admin` — application administrator
- `daemon` — C++ worker process connections
- `apibot` — C++ helper/background process connections

### Module load order

Defined in `create.psql` and `update.psql`. 25 modules in dependency order:
kernel → oauth2 → locale → admin → http → resource → exception → registry → log → api → replication → daemon → session → current → workflow → kladr → file → entity → notice → comment → notification → verification → observer → report → reports

### Execution pipeline (psql scripts)

| Script | Scope |
|--------|-------|
| `create.psql` | Full install: DDL + routines + views + init data |
| `update.psql` | Safe update: routines + views only (CREATE OR REPLACE) |
| `patch.psql` | Table migrations via `patch/patch.psql` |
| `make.psql` | Create DB users (`kernel/users.sql`) |
| `init.sql` | Seed data: workflow registration, entity tree, REST routes, publishers, vendors, agents, schedulers |

### REST API flow

```
HTTP → C++ AppServer → SELECT rest.api('/entity/method', '{"key":"value"}')
  → rest.<entity>(method, params) → api.<function>() → kernel.<function>() → db.<table>
```

### Workflow engine

Every entity has a state machine registered in `init.sql`:
- `AddState()` / `AddMethod()` / `AddTransition()` / `AddEvent()` define the machine
- `api.execute_object_action(id, 'action_code')` drives transitions
- Event handlers: `Event<Entity><Action>` functions (e.g., `EventJobCreate`, `EventJobExecute`)
- State changes can trigger NOTIFY channels for C++ processes

### Entity hierarchy

```
object (abstract root)
├── reference (catalogs: code + name)
│     ├── agent, form, program, scheduler, vendor, version
│     └── report_tree, report_form, report_routine, report
└── document (business records: lifecycle + area + priority)
      ├── job, message (→ inbox, outbox), report_ready
```

### Access control

Application-level ACL (not PostgreSQL RLS). Three layers:
- **ACU** (Access Control Unit) — defines permission types per entity class
- **AMU** (Access Method Unit) — maps methods to required permissions
- **AOU** (Access Object Unit) — grants permissions to users/groups per object

All functions run as `SECURITY DEFINER` (owner `kernel`). Session identity is set via `session.SetSessionUserId()` and read via `current_userid()`.

Details: `RLS.md`

## File conventions

### Entity module structure

```
entity-name/
├── table.sql      — CREATE TABLE, indexes, triggers         (create only)
├── view.sql       — CREATE OR REPLACE VIEW                  (create + update)
├── routine.sql    — Business logic functions                 (create + update)
├── api.sql        — api.* views + CRUD wrappers             (create + update)
├── rest.sql       — rest.* dispatcher                       (create + update)
├── event.sql      — Event handlers (EventXxxCreate, etc.)   (create + update)
├── init.sql       — Seed data, workflow registration         (create only)
├── exception.sql  — Error-raising functions                  (create + update)
├── security.sql   — Access control functions                 (create only)
├── do.sql         — Configuration hooks                      (create + update)
├── create.psql    — Includes all files for full install
└── update.psql    — Includes only replaceable files (view, routine, api, rest, do)
```

### Function naming

- `Create<Entity>(...)` — insert, returns uuid
- `Edit<Entity>(id, ...)` — update (NULL = keep current)
- `Get<Entity>(id)` / `Get<Entity>List(...)` — read
- `Delete<Entity>(id)` — soft delete via workflow
- `Event<Entity><Action>(id, ...)` — workflow event handler
- `api.add_<entity>(...)` / `api.update_<entity>(...)` / `api.get_<entity>(...)` / `api.delete_<entity>(...)` — API wrappers
- `rest.<entity>(pPath, pPayload)` — REST dispatcher

### Patch naming

Patches live in `patch/v<major>.<minor>/P<8-digit>.sql` (e.g., `patch/v1.0/P00000078.sql`). Active patches are uncommented in `patch/patch.psql`. The `migrate.sh` script tracks applied patches via `db.patch_log` table.

### All functions use

```sql
SECURITY DEFINER
SET search_path = kernel, pg_temp;
```

## Writing code in this repo

- Tables always in `db` schema: `CREATE TABLE db.new_table (...)`
- Functions always in `kernel` schema (default via `search_path`) or explicitly in `api`/`rest`/`oauth2`/`daemon`
- Use `uuid` for all primary keys (generated by `gen_kernel_uuid()`)
- NULL parameters in Edit functions mean "keep current value" — use `coalesce(pParam, existing_value)`
- Error handling via exception module: `PERFORM SomeException()` raises specific error
- All timestamps are `timestamptz`
- Reference INDEX.md files in each module for detailed function signatures and table schemas

## Key reference files

- `INDEX.md` — full module list with links to per-module INDEX files
- `RLS.md` — access control architecture (ACU/AMU/AOU, bitmasks, Access views)
- `wiki/` — 52-page documentation (API guide, entity creation, workflow customization)
- `wiki/71-Creating-Entity.md` — step-by-step guide for adding new entities
- `wiki/74-Workflow-Customization.md` — custom states, methods, transitions
- `wiki/75-REST-Endpoint-Guide.md` — writing REST dispatchers
