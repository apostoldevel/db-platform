# reports

> Platform module #25 | Loaded by `create.psql` line 25

Pre-built report definitions layered on top of the `report` framework module. Provides shared form generators (`rfc_*`) and report routines (`rpc_*`) for common use cases: object info, file import, session lists, and user lists. No new tables — purely configuration/application code in the `report` schema.

## Dependencies

| Depends on | Depended by |
|------------|-------------|
| `report` (framework), `admin` (users/groups/sessions), `entity/object` (object info) | Configuration-specific reports |

## Schemas Used

| Schema | Usage |
|--------|-------|
| `report` | ~5 form functions (`rfc_*`) + ~1 routine function (`rpc_*`) |

## Tables

None. Uses tables from the `report` module.

## Views

None.

## Functions (report schema)

### Form Generators (`rfc_*`)

Form functions return JSON describing input fields (type, key, label, value, data, mutable, format).

| Function | Returns | Purpose |
|----------|---------|---------|
| `report.rfc_identifier_form(pForm, pParams)` | `json` | Single UUID identifier field |
| `report.rfc_import_file(pForm, pParams)` | `json` | Single file upload field (JSON format) |
| `report.rfc_import_files(pForm, pParams)` | `json` | Multiple file upload field (JSON, `multiple=true`) |
| `report.rfc_session_list(pForm, pParams)` | `json` | Session report form: group dropdown + user dropdown (cascading filter), status selector |
| `report.rfc_user_list(pForm, pParams)` | `json` | User report form: group dropdown + user dropdown (cascading filter), status selector |

All form functions support bilingual labels (ru/en) based on `current_locale()`.

### Report Routines (`rpc_*`)

| Function | Returns | Purpose |
|----------|---------|---------|
| `report.rpc_object_info(pReady, pForm)` | `void` | Generate HTML table of object metadata (iterates columns via `all_tab_columns`) |

The `rpc_object_info` routine:
- Extracts object UUID from `pForm->'identifier'`
- Queries the `Object` view
- Builds an HTML table with Field/Data columns
- Uses `ReportHeadHTML()`/`ReportStyleHTML()` from the `report` module
- Includes error handling with HTML error page

## REST Routes

None directly. Reports registered here are accessed through the `report` module's REST endpoints.

## Directory Structure

```
reports/
  routine.sql           — Shared rfc_*/rpc_* functions
  object/
    create.psql         — Object report initialization
    update.psql
  admin/
    routine.sql         — Admin-specific form functions
    user/
      create.psql       — User report registration
      update.psql
    session/
      create.psql       — Session report registration
      update.psql
    init.sql            — Admin report seed data
    create.psql
    update.psql
  create.psql           — Master loader
  update.psql           — Re-includes routines (no table DDL)
```

## File Manifest

| File | In create | In update | Purpose |
|------|:---------:|:---------:|---------|
| `routine.sql` | yes | yes | Shared form generators + routines |
| `object/create.psql` | yes | - | Object report init |
| `admin/routine.sql` | yes | yes | Admin form functions |
| `admin/user/create.psql` | yes | - | User report init |
| `admin/session/create.psql` | yes | - | Session report init |
| `admin/init.sql` | yes | no | Admin report seed data |
| `create.psql` | - | - | Includes all |
| `update.psql` | - | - | Excludes init.sql, table files |
