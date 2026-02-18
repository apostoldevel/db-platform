# session

> Platform module #13 | Loaded by `create.psql` line 13

Session context setters — REST API for changing the current session's area, interface, locale, and operational date. Thin wrappers around admin module's `SetSessionArea`, `SetSessionInterface`, `SetSessionLocale`, `SetOperDate`.

## Dependencies

| Depends on | Depended by |
|------------|-------------|
| `kernel`, `admin` (session management, area/interface/locale lookup) | Client applications (switch context within session) |

## Schemas Used

| Schema | Usage |
|--------|-------|
| `api` | 8 setter functions (overloaded for uuid + text) |
| `rest` | `rest.session` dispatcher (4 routes) |

## Tables

None (uses `db.session`, `db.area`, `db.interface`, `db.locale` from admin/locale).

## Views

None.

## Functions

### api schema

| Function | Returns | Purpose |
|----------|---------|---------|
| `api.set_session_area(pArea uuid)` | `SETOF record` | Set session area by UUID |
| `api.set_session_area(pArea text)` | `SETOF record` | Set session area by code |
| `api.set_session_interface(pInterface uuid)` | `SETOF record` | Set session interface by UUID |
| `api.set_session_interface(pInterface text)` | `SETOF record` | Set session interface by code |
| `api.set_session_locale(pLocale uuid)` | `SETOF record` | Set session locale by UUID |
| `api.set_session_locale(pCode text)` | `SETOF record` | Set session locale by code (default 'ru') |
| `api.set_session_oper_date(pOperDate timestamp)` | `SETOF record` | Set operational date (timestamp) |
| `api.set_session_oper_date(pOperDate timestamptz)` | `SETOF record` | Set operational date (timestamptz) |

## REST Routes — 4

Dispatcher: `rest.session(pPath text, pPayload jsonb)`. Requires authenticated session.

| Path | Purpose |
|------|---------|
| `/session/set/area` | Set current session area (accepts id or code) |
| `/session/set/interface` | Set current session interface (accepts id or code) |
| `/session/set/locale` | Set current session language (accepts id or code) |
| `/session/set/oper_date` | Set operational date |

## File Manifest

| File | In create | In update | Purpose |
|------|:---------:|:---------:|---------|
| `api.sql` | yes | yes | 8 API setter functions |
| `rest.sql` | yes | yes | `rest.session` dispatcher (4 routes) |
| `create.psql` | - | - | Includes api, rest |
| `update.psql` | - | - | Includes api, rest |
