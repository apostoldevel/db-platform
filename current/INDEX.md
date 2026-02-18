# current

> Platform module #14 | Loaded by `create.psql` line 14

Current context getters — REST API for reading the current session's user, area, interface, locale, and operational date. Read-only counterpart to the `session` module's setters.

## Dependencies

| Depends on | Depended by |
|------------|-------------|
| `kernel`, `admin` (session/user/area/interface context), `locale` | Client applications (read current context) |

## Schemas Used

| Schema | Usage |
|--------|-------|
| `api` | 8 getter functions |
| `rest` | `rest.current` dispatcher (8 routes) |

## Tables

None (reads from `db.session`, `users`, `Area`, `Interface`, `Locale` views).

## Views

None.

## Functions

### api schema

| Function | Returns | Purpose |
|----------|---------|---------|
| `api.current_session()` | `SETOF Session` | Get current session record |
| `api.current_user()` | `SETOF users` | Get current user (filtered by scope) |
| `api.current_userid()` | `uuid` | Get current user ID |
| `api.current_username()` | `text` | Get current username |
| `api.current_area()` | `SETOF Area` | Get current area with scope info |
| `api.current_interface()` | `SETOF Interface` | Get current interface |
| `api.current_locale()` | `SETOF Locale` | Get current locale |
| `api.oper_date()` | `timestamptz` | Get operational date |

## REST Routes — 8

Dispatcher: `rest.current(pPath text, pPayload jsonb)`. Requires authenticated session.

| Path | Purpose |
|------|---------|
| `/current/session` | Current session data |
| `/current/user` | Current user data |
| `/current/userid` | Current user ID |
| `/current/username` | Current username |
| `/current/area` | Current area/scope |
| `/current/interface` | Current interface |
| `/current/locale` | Current locale |
| `/current/oper_date` | Operational date |

## File Manifest

| File | In create | In update | Purpose |
|------|:---------:|:---------:|---------|
| `api.sql` | yes | yes | 8 API getter functions |
| `rest.sql` | yes | yes | `rest.current` dispatcher (8 routes) |
| `create.psql` | - | - | Includes api, rest |
| `update.psql` | - | - | Includes api, rest |
