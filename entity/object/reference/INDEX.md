# entity/object/reference

> Part of entity module #18 | Loaded by `entity/object/reference/create.psql`

**Abstract reference (catalog) class** extending `object`. Adds scope-unique `code` and localized `name`/`description`. Concrete subclasses: **agent** (message channels), **form** (with fields), **program** (PL/pgSQL code), **scheduler** (periodic intervals), **vendor** (suppliers), **version** (API versions).

## Class Hierarchy

```
object (abstract)
  └── reference (abstract)
        ├── agent (concrete) — message delivery channels (4 types)
        ├── form (concrete) — dynamic forms
        │     └── form_field (child table, not an entity)
        ├── program (concrete) — stored PL/pgSQL programs
        ├── scheduler (concrete) — periodic job schedulers
        ├── vendor (concrete) — suppliers/manufacturers (3 types)
        └── version (concrete) — API versions
```

## Dependencies

| Depends on | Depended by |
|------------|-------------|
| `entity/object` (inherits), `workflow`, `admin` (scope) | Configuration reference entities (region, currency, category, etc.), `job` (uses scheduler + program) |

---

## REFERENCE (base)

### Tables — 2

| Table | Description | Key Columns |
|-------|-------------|-------------|
| `db.reference` | Base reference catalog | `id uuid PK`, `object uuid FK`, `scope uuid FK`, `entity uuid FK`, `class uuid FK`, `type uuid FK`, `code text`; UNIQUE(`scope`, `entity`, `code`) |
| `db.reference_text` | Localized name/description | PK(`reference`, `locale`), `name text`, `description text` |

### Views — 4

`Reference`, `CurrentReference` (current scope), `AccessReference` (aou filtered), `ObjectReference` (full metadata).

### Functions — 8

`NewReferenceText`, `EditReferenceText`, `CreateReference`, `EditReference`, `GetReference` (2 overloads: by code+entity), `GetReferenceCode`, `GetReferenceName`, `GetReferenceDescription`.

### API — 6 functions

`api.add_reference`, `api.update_reference`, `api.set_reference`, `api.get_reference`, `api.list_reference`.

### REST Routes — 6

`/reference/type`, `/reference/method`, `/reference/count`, `/reference/set`, `/reference/get`, `/reference/list`.

### Events — 9

Standard lifecycle: Create, Open, Edit, Save, Enable, Disable, Delete, Restore, Drop.

---

## Sub-Entity Pattern

All sub-entities follow the same structure:

| Layer | Pattern |
|-------|---------|
| **Table** | `db.{entity}` with `id uuid PK/FK(reference)`, `reference uuid FK`, specialized columns |
| **Trigger** | BEFORE INSERT: copy `reference` to `id` |
| **Views** | 3 per entity: `{Entity}`, `Access{Entity}`, `Object{Entity}` |
| **Functions** | `Create{Entity}` → calls `CreateReference` + insert specialized row + `ExecuteMethod('create')` |
| **Events** | 9 standard lifecycle + `Event{Entity}Drop` deletes specialized row |
| **Init** | `CreateClass{Entity}` (class + types + events + methods) |
| **REST** | 6-7 routes: type, method, count, set, get, list + entity-specific |

---

## AGENT

| Aspect | Details |
|--------|---------|
| **Extra columns** | `vendor uuid FK(vendor)` |
| **Types** | `system.agent`, `api.agent`, `email.agent`, `stream.agent` |
| **Special** | AFTER INSERT trigger sets mailbot AOU permissions |
| **Functions** | `CreateAgent`, `EditAgent`, `GetAgent`, `GetAgentCode`, `GetAgentVendor` |
| **API extra** | `api.get_agent_id(pCode)` — UUID/code resolution |
| **REST extra** | Dynamic methods via `ExecuteDynamicMethod()` |

## FORM

| Aspect | Details |
|--------|---------|
| **Extra columns** | (none, just id+reference) |
| **Types** | `none.form`, `journal.form`, `tracker.form` |
| **Special** | `BuildForm(pForm, pParams)` → JSON array of fields ordered by sequence |
| **API extra** | `api.build_form(pId, pParams)` |
| **REST extra** | `/form/build` + delegates to `rest.form_field()` for `/form/field*` |

### FORM FIELD (child table, not a workflow entity)

| Table | Description |
|-------|-------------|
| `db.form_field` | PK(`form`, `key`), `type`, `label`, `format`, `value`, `data jsonb`, `mutable bool`, `sequence int` |

Functions: `CreateFormField`, `EditFormField`, `SetFormField` (upsert), `DeleteFormField`, `SetFormFieldSequence`, `GetFormFieldJson`.

API: `api.set_form_field`, `api.get_form_field`, `api.delete_form_field`, `api.clear_form_field`, `api.set_form_field_json`/`jsonb`, `api.get_form_field_json`/`jsonb`, `api.list_form_field`.

REST: `/form/field`, `/form/field/count`, `/form/field/set`, `/form/field/get`, `/form/field/delete`, `/form/field/list`.

## PROGRAM

| Aspect | Details |
|--------|---------|
| **Extra columns** | `body text` (PL/pgSQL source code) |
| **Types** | `plpgsql.program` |
| **Functions** | `CreateProgram`, `EditProgram`, `GetProgram` |

## SCHEDULER

| Aspect | Details |
|--------|---------|
| **Extra columns** | `period interval`, `dateStart timestamptz` (default NOW()), `dateStop timestamptz` (default '4433-12-31') |
| **Types** | `job.scheduler` |
| **Functions** | `CreateScheduler`, `EditScheduler`, `GetScheduler` |

## VENDOR

| Aspect | Details |
|--------|---------|
| **Extra columns** | (none, just id+reference) |
| **Types** | `service.vendor`, `device.vendor`, `car.vendor` |
| **Functions** | `CreateVendor`, `EditVendor`, `GetVendor` |

## VERSION

| Aspect | Details |
|--------|---------|
| **Extra columns** | (none, just id+reference) |
| **Types** | `api.version` |
| **Functions** | `CreateVersion`, `EditVersion`, `GetVersion` |

---

## Loading Order (create.psql)

```
reference/
  table.sql → view.sql → routine.sql → api.sql → rest.sql → event.sql → init.sql
  → form/create.psql
      → form/field/create.psql
  → vendor/create.psql
  → agent/create.psql
  → program/create.psql
  → scheduler/create.psql
  → version/create.psql
```

## Summary

| Entity | Extra Table | Extra Columns | Types | REST Routes |
|--------|------------|---------------|-------|-------------|
| reference | db.reference + _text | code, scope | — | 6 |
| agent | db.agent | vendor | 4 | 7+ |
| form | db.form | — | 3 | 8+ |
| form_field | db.form_field | type, label, format, value, data, mutable, sequence | — | 6 |
| program | db.program | body | 1 | 6 |
| scheduler | db.scheduler | period, dateStart, dateStop | 1 | 6 |
| vendor | db.vendor | — | 3 | 6 |
| version | db.version | — | 1 | 6 |
