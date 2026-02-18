# report

> Platform module #24 | Loaded by `create.psql` line 24

Report definition and generation framework. Provides a four-part report structure: **tree** (section hierarchy), **form** (user input), **routine** (generation code), and **ready** (output document). Reports bind to workflow classes and inherit the standard entity lifecycle (create → enable ↔ disable → delete). Includes HTML generation utilities for printable A4 output.

## Dependencies

| Depends on | Depended by |
|------------|-------------|
| `kernel`, `workflow` (entity/class/state/method), `entity/object` (reference, document for report_ready), `admin` (user/scope) | `reports` module (pre-built report definitions), configuration entities |

## Schemas Used

| Schema | Usage |
|--------|-------|
| `db` | 5 tables (report, report_tree, report_form, report_routine, report_ready) + triggers |
| `report` | Custom schema for report functions |
| `kernel` | 3 views, ~12 functions |
| `api` | 1 view, ~10 functions |
| `rest` | `rest.report` dispatcher (8 routes) |

## Tables — 5

| Table | Description | Key Columns |
|-------|-------------|-------------|
| `db.report` | Report definitions | `id uuid PK`, `reference uuid FK`, `tree uuid FK`, `form uuid FK`, `binding uuid FK(class_tree)`, `info jsonb` |
| `db.report_tree` | Section hierarchy | `id uuid PK`, `reference uuid FK`, `root uuid FK(self)`, `node uuid FK(self)`, `level int`, `sequence int` |
| `db.report_form` | Input form definitions | `id uuid PK`, `reference uuid FK`, `definition text` (function name for form generation) |
| `db.report_routine` | Generation routines | `id uuid PK`, `reference uuid FK`, `report uuid FK`, `definition text`, `sequence int`; UNIQUE(`report`, `definition`) |
| `db.report_ready` | Generated outputs | `id uuid PK`, `document uuid FK`, `report uuid FK`, `form jsonb` |

Each table has a BEFORE INSERT trigger that sets `id = reference` (or `id = document` for report_ready) if NULL.

## Report Structure

```
Report
  ├── Tree (section hierarchy)
  ├── Form (user input definition → rfc_* function)
  ├── Routine(s) (generation code → rpc_* functions, ordered by sequence)
  └── Ready (output document, inherits from Document class)
```

**Binding:** A report binds to a workflow `class_tree` entry. `api.report_object(pClass)` recursively searches the class and its ancestors for bound reports.

## Views — 3

| View | Description |
|------|-------------|
| `Report` | Full metadata: tree/form/binding code+name, report code/name/description, scope info |
| `AccessReport` | Object IDs accessible via aou mask `B'100'` |
| `ObjectReport` | Full object+report join with entity/class/type/state/owner/scope metadata |

## Functions (kernel/report schema) — ~12

### CRUD

| Function | Returns | Purpose |
|----------|---------|---------|
| `CreateReport(pParent, pType, pTree, pForm, pBinding, pCode, pName, pDescription, pInfo)` | `uuid` | Create report reference + db.report row |
| `EditReport(pId, ...)` | `void` | Update report |
| `GetReport(pCode)` | `uuid` | Lookup by code |

### Initialization Helpers

| Function | Returns | Purpose |
|----------|---------|---------|
| `InitReport(pParent, pType, pTree, pCode, pName, pDescription)` | `uuid` | Create form + report + routine in one call |
| `InitObjectReport(pParent, pTree, pForm, pBinding, pCode, pName, pDescription)` | `uuid` | Convenience for object-bound reports |
| `BuildReport(pReport, pType, pForm)` | `uuid` | Create ReportReady output document |

### Data Retrieval (for form dropdowns)

| Function | Returns | Purpose |
|----------|---------|---------|
| `GetForReportDocumentJson(pEntity, pClasses, pLimit)` | `json` | Documents as `[{value, label}]` |
| `GetForReportReferenceJson(pEntity, pClasses, pLimit)` | `json` | References as `[{value, label}]` |
| `GetForReportTypeJson(pEntity, pLimit)` | `json` | Types as `[{value, label}]` |
| `GetForReportStateJson(pClass, pLimit)` | `json` | States as `[{value, label}]` |

### HTML Utilities

| Function | Returns | Purpose |
|----------|---------|---------|
| `ReportStyleHTML()` | `text` | CSS for @media print, A4 page layout |
| `ReportHeadHTML(pTitle)` | `text` | `<head>` with charset, title, styles |
| `ReportErrorHTML(pCode, pMessage, pContext, pLocale)` | `text` | Error page HTML |

## Events — 9

All log to event log (code 1000):

| Event | Handler | Purpose |
|-------|---------|---------|
| create | `EventReportCreate` | Report created |
| open | `EventReportOpen` | Report opened |
| edit | `EventReportEdit` | Report edited |
| save | `EventReportSave` | Report saved |
| enable | `EventReportEnable` | Report enabled |
| disable | `EventReportDisable` | Report disabled |
| delete | `EventReportDelete` | Report deleted |
| restore | `EventReportRestore` | Report restored |
| drop | `EventReportDrop` | Cascade delete: report_ready, report_routine, disabled objects |

## Functions (api schema) — ~10

| Function | Returns | Purpose |
|----------|---------|---------|
| `api.report_object(pClass)` | `SETOF api.report` | Reports bound to class or ancestors (recursive) |
| `api.add_report(...)` | `uuid` | Create (type defaults to `'report.report'`) |
| `api.update_report(...)` | `void` | Update |
| `api.get_report(pId)` | `SETOF api.report` | Get by ID |
| `api.list_report(pSearch, pFilter, pLimit, pOffSet, pOrderBy)` | `SETOF api.report` | List with search/filter |
| `api.delete_report(pId)` | `void` | Soft delete via state |
| `api.add_report_tree(...)` | `uuid` | Create tree node |
| `api.add_report_form(...)` | `uuid` | Create form |
| `api.add_report_routine(...)` | `uuid` | Create routine |

## REST Routes — 8

Dispatcher: `rest.report(pPath text, pPayload jsonb)`.

| Path | Purpose |
|------|---------|
| `/report/type` | Report types |
| `/report/method` | Methods for report object |
| `/report/count` | Count with search/filter |
| `/report/list` | List with search/filter/pagination |
| `/report/get` | Get single with field projection |
| `/report/set` | Insert or update |
| `/report/add` | Create new |
| `/report/delete` | Soft delete |

## File Manifest

| File | In create | In update | Purpose |
|------|:---------:|:---------:|---------|
| `schema.sql` | yes | no | `CREATE SCHEMA report` |
| `tree/create.psql` | yes | - | Report tree sub-entity |
| `form/create.psql` | yes | - | Report form sub-entity |
| `table.sql` | yes | no | db.report table + trigger |
| `view.sql` | yes | yes | Report, AccessReport, ObjectReport views |
| `exception.sql` | yes | yes | Error/exception functions |
| `routine.sql` | yes | yes | Core functions |
| `api.sql` | yes | yes | api view + functions |
| `rest.sql` | yes | yes | `rest.report` dispatcher (8 routes) |
| `event.sql` | yes | yes | 9 event handlers |
| `init.sql` | yes | no | Entity/class registration, events |
| `routine/create.psql` | yes | - | Report routine sub-entity |
| `ready/create.psql` | yes | - | Report ready (output) sub-entity |
| `create.psql` | - | - | Includes all |
| `update.psql` | - | - | Excludes table.sql, init.sql, schema.sql |
