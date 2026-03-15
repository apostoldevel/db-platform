# db-platform — INDEX

> PostgreSQL Framework for Backend Development
> Version: 1.2.0 | License: MIT
> GitHub: https://github.com/apostoldevel/db-platform

---

## What is it

A PL/pgSQL framework that turns PostgreSQL into a full-featured application server: REST API, OAuth2, workflow engine (state machine), entity system (objects, references, documents), file storage, pub/sub, reports — all on the database side.

Used together with the [Apostol](https://github.com/apostoldevel/apostol) C++ framework (HTTP/WS server, epoll event loop, libpq).

---

## Two-layer architecture

```
sql/
  platform/        ← Framework (this repo). DO NOT edit.
  configuration/   ← Application code. Edit HERE.
     <dbname>/     ← Determined by \set dbname in sql/sets.psql
```

Execution order: **platform → configuration**.

```
install.psql  →  platform/create.psql  →  configuration/create.psql
update.psql   →  platform/update.psql  →  configuration/update.psql
patch.psql    →  platform/patch.psql   →  configuration/patch.psql
```

---

## PostgreSQL schemas

| Schema | Purpose | Prefix |
|--------|---------|--------|
| `db` | All tables | `db.table_name` — always |
| `kernel` | Core business logic (in `search_path`) | Not needed |
| `api` | API views + CRUD functions | `api.view_name` |
| `rest` | REST dispatchers | `rest.entity_name()` |
| `oauth2` | OAuth2 infrastructure | `oauth2.*` |
| `daemon` | C++ interface functions | `daemon.*` |

## Database users

| User | Purpose |
|------|---------|
| `kernel` | Owner of all objects, DDL, SECURITY DEFINER |
| `admin` | Administrator (role `administrator`) |
| `daemon` | C++ worker processes (via pgbouncer) |
| `apibot` | C++ helper/process (direct connection) |

---

## 26 modules

Loaded in dependency order (create.psql):

### Core

| # | Module | Tables | Description | INDEX |
|--:|--------|-------:|-------------|-------|
| 1 | **kernel** | — | Data types, UUID, JWT, utilities (JSON, AWS-sig, base64) | [kernel/INDEX.md](kernel/INDEX.md) |
| 2 | **oauth2** | 5 | OAuth2: providers, applications, issuers, audiences | [oauth2/INDEX.md](oauth2/INDEX.md) |
| 3 | **locale** | 1 | Multi-language support (ISO 639-1) | [locale/INDEX.md](locale/INDEX.md) |
| 4 | **admin** | 18 | Users, auth, sessions, scope, area, ACL, member_group | [admin/INDEX.md](admin/INDEX.md) |
| 7 | **exception** | — | Standardized errors (~84 functions) | [exception/INDEX.md](exception/INDEX.md) |
| 8 | **error** | 2 | Error catalog with locale-aware messages (ERR-GGG-CCC) | [error/INDEX.md](error/INDEX.md) |

### Infrastructure

| # | Module | Tables | Description | INDEX |
|--:|--------|-------:|-------------|-------|
| 5 | **http** | 3 | Outbound HTTP requests + callbacks (LISTEN/NOTIFY) | [http/INDEX.md](http/INDEX.md) |
| 6 | **resource** | 2 | Locale-aware content tree | [resource/INDEX.md](resource/INDEX.md) |
| 8 | **registry** | 2 | Key-value configuration (hierarchical, Windows Registry style) | [registry/INDEX.md](registry/INDEX.md) |
| 9 | **log** | 1 | Structured event log | [log/INDEX.md](log/INDEX.md) |
| 10 | **api** | 4 | REST routing, request log, `rest.api()` — main entry point | [api/INDEX.md](api/INDEX.md) |
| 11 | **replication** | 4 | Multi-instance sync | [replication/INDEX.md](replication/INDEX.md) |
| 12 | **daemon** | — | C++ ↔ PL/pgSQL interface | [daemon/INDEX.md](daemon/INDEX.md) |

### Session

| # | Module | Tables | Description | INDEX |
|--:|--------|-------:|-------------|-------|
| 13 | **session** | — | Session context setters (`SetSessionUserId`, `SetSessionScope`, ...) | [session/INDEX.md](session/INDEX.md) |
| 14 | **current** | — | Session context getters (`current_userid()`, `current_scope()`, ...) | [current/INDEX.md](current/INDEX.md) |

### Business logic

| # | Module | Tables | Description | INDEX |
|--:|--------|-------:|-------------|-------|
| 15 | **workflow** | 23 | State machine: entity → class → type, states, actions, methods, transitions, events, `acu`, `amu` | [workflow/INDEX.md](workflow/INDEX.md) |
| 16 | **kladr** | 3 | Russian address classifier (KLADR) | [kladr/INDEX.md](kladr/INDEX.md) |
| 17 | **file** | 1 | Virtual FS: files, directories, UNIX mask, S3 buckets | [file/INDEX.md](file/INDEX.md) |
| 18 | **entity** | 27 | Entity system: object, reference, document. AOU/AOM access control | [entity/INDEX.md](entity/INDEX.md) |

### Communication

| # | Module | Tables | Description | INDEX |
|--:|--------|-------:|-------------|-------|
| 19 | **notice** | 1 | User notifications | [notice/INDEX.md](notice/INDEX.md) |
| 20 | **comment** | 1 | Threaded comments on objects | [comment/INDEX.md](comment/INDEX.md) |
| 21 | **notification** | 1 | Event audit trail + dispatch | [notification/INDEX.md](notification/INDEX.md) |
| 22 | **verification** | 1 | Email/phone verification codes | [verification/INDEX.md](verification/INDEX.md) |
| 23 | **observer** | 2 | Pub/Sub: publishers, listeners, filter routing | [observer/INDEX.md](observer/INDEX.md) |

### Reporting

| # | Module | Tables | Description | INDEX |
|--:|--------|-------:|-------------|-------|
| 24 | **report** | 5 | Reports: tree, form, routine, ready | [report/INDEX.md](report/INDEX.md) |
| 25 | **reports** | — | Pre-built report definitions | [reports/INDEX.md](reports/INDEX.md) |

---

## Key subsystems

### Workflow Engine (module #15)

State machine for all entities:

```
Entity → Class → Type
                  ↓
          State Machine:
          State + Action → Method → Event → Transition → New State
```

- **Entity**: abstract type (object, reference, document)
- **Class**: concrete class (client, trader, subscription)
- **Type**: subtype (individual.client, docker.bot_instance)
- **State**: state (created, enabled, disabled, deleted)
- **Method**: action + logic (DoEnable, DoDisable, DoDrop)
- **Transition**: transition rule (state_from → state_to via method)
- **Event**: transition handler (EventClientEnable, EventTraderCreate)

Registration in `init.sql`: `AddState()`, `AddMethod()`, `AddTransition()`, `AddEvent()`.

Execution: `api.execute_object_action(pId, 'action_code')`.

### Entity System (module #18)

Object hierarchy:

```
object (abstract root)
├── reference (abstract) — catalogs (code + name)
│     ├── agent, form, program, scheduler, vendor, version
│     └── report_tree, report_form, report_routine, report
└── document (abstract) — business documents (lifecycle + area + priority)
      ├── job — scheduled/one-time tasks
      ├── message → inbox, outbox — messages
      └── report_ready — generated reports
```

Details: [entity/object/INDEX.md](entity/object/INDEX.md)

### Access Control

Object-level ACL via `acu` → `aou` + `aom` tables and Access views.

**Not PostgreSQL RLS** — for architectural reasons (SECURITY DEFINER + session identity).

Details: [RLS.md](RLS.md)

### REST API (module #10)

Main entry point: `rest.api(pPath, pPayload)`.

```
HTTP → C++ (AppServer) → SELECT rest.api('/trader/get', '{"id": "..."}')
```

Dispatching: first path segment → registered `rest.{entity}()`.

414+ endpoints. Auto-generation: `api.get_method_spec()` for OpenAPI/Swagger.

---

## Module structure (typical)

```
module-name/
├── table.sql      — CREATE TABLE, indexes, triggers         (create only)
├── view.sql       — CREATE OR REPLACE VIEW                  (create + update)
├── routine.sql    — CREATE FUNCTION (business logic)        (create + update)
├── api.sql        — api.* views + CRUD functions            (create + update)
├── rest.sql       — rest.* dispatcher                       (create + update)
├── do.sql         — Configuration hooks                     (create + update)
├── event.sql      — Event handlers                          (create only)
├── init.sql       — Seed data, workflow registration        (create only)
├── security.sql   — Access control functions                (create only)
├── INDEX.md       — Module reference
├── create.psql    — Includes all files
└── update.psql    — Includes view, routine, api, rest, do
```

---

## Management scripts

```bash
./runme.sh --init      # First run: create users + full install
./runme.sh --install   # DESTRUCTIVE: drop/recreate DB with seed data
./runme.sh --create    # DESTRUCTIVE: drop/recreate DB without data
./runme.sh --update    # Safe: routines + views only
./runme.sh --patch     # Tables + routines + views (migrations)
./runme.sh --api       # Drop/recreate api schema only
./runme.sh --test      # Run pgTAP tests
```

---

## Initialization (init.sql)

Called on `--install`. Main functions:

| Function | Purpose |
|----------|---------|
| `InitWorkFlow()` | Register workflow: entity types, states, actions, methods, transitions, events |
| `InitEntity()` | Register class tree: object → reference/document → all subclasses |
| `InitAPI()` | Register REST routes |
| `CreatePublisher()` | Pub/Sub publishers (notify, notice, message, replication, log, geo, file) |
| `CreateVendor()` | Vendors (system, mts, google, sberbank) |
| `CreateAgent()` | Delivery agents (system, notice, smtp, pop3, imap, fcm, m2m, sba) |
| `CreateScheduler()` | Job schedulers (1/5/10 minutes) |

---

## Configuration

### Runtime: Registry

```sql
SELECT RegSetValueString('CONFIG\Path', 'key', 'value');
SELECT RegGetValueString('CONFIG\Path', 'key');
```

### SQL: sets.psql

```sql
\set dbname 'projectname'   -- determines configuration/<dbname>/
\set dblang 'ru'             -- default locale
```

### SQL: .env.psql

Passwords, OAuth2 secrets, payment keys (not committed to VCS).

---

## Wiki (52+ pages)

| Section | Pages | Key pages |
|---------|-------|-----------|
| **Concepts** | 01-05 | [04-Workflow.md](wiki/04-Workflow.md) |
| **API Guide** | 10-13 | [13-Query-Parameters.md](wiki/13-Query-Parameters.md) |
| **Auth & Session** | 20-29 | [22-Authorization-OAuth2.md](wiki/22-Authorization-OAuth2.md) |
| **Core Services** | 30-39 | [34-Registry.md](wiki/34-Registry.md) |
| **Object & Workflow** | 40-48 | [48-Class-Endpoints.md](wiki/48-Class-Endpoints.md) |
| **Internals** | 60-65 | [63-Entity-System-Internals.md](wiki/63-Entity-System-Internals.md), [64-Access-Control.md](wiki/64-Access-Control.md) |
| **Developer Guide** | 70-80 | [71-Creating-Entity.md](wiki/71-Creating-Entity.md) (35KB), [74-Workflow-Customization.md](wiki/74-Workflow-Customization.md) |

---

## Projects built on the platform

- [Ship Safety ERP](https://ship-safety.ru) — ERP for shipping companies
- [CopyFrog](https://copyfrog.ai) — AI-powered marketing content generation
- [Talking to AI](https://t.me/TalkingToAIBot) — Telegram AI chatbot
- [OCPP CSS](http://ocpp-css.ru) — SaaS for EV charging stations
- [PlugMe](https://plugme.ru) — Charging Station Management System (CSMS)
- [DEBT-Master](https://debt-master.ru) — Consumer debt automation
- [BitDeals](https://testnet.bitdeals.org) — BTC arbitration platform

---

## Related documents

| Document | Description |
|----------|-------------|
| [README.md](README.md) | English overview |
| [README.ru-RU.md](README.ru-RU.md) | Russian overview |
| [RLS.md](RLS.md) | Access Control: AOU/ACU/AOM, Access views, bitmasks |
| [entity/INDEX.md](entity/INDEX.md) | Entity system overview |
| [entity/object/INDEX.md](entity/object/INDEX.md) | Object module: 14 tables, 130+ functions |
| [entity/object/reference/INDEX.md](entity/object/reference/INDEX.md) | Reference entities |
| [entity/object/document/INDEX.md](entity/object/document/INDEX.md) | Document entities |
| [workflow/INDEX.md](workflow/INDEX.md) | Workflow engine: 23 tables, 89 functions |
| [admin/INDEX.md](admin/INDEX.md) | Admin: 18 tables, 159 functions |
