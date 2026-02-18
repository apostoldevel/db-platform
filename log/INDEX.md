# log

> Platform module #9 | Loaded by `create.psql` line 9

Event logging system. Stores typed events (Message/Warning/Error/Debug) with user, session, category, and optional object reference. Sends pg_notify on insert for real-time log monitoring.

## Dependencies

| Depends on | Depended by |
|------------|-------------|
| `kernel`, `admin` (for session/user context) | `api` (api_log references log), `admin` (event/log REST routes), all modules that call `WriteToEventLog` |

## Schemas Used

| Schema | Usage |
|--------|-------|
| `db` | `db.log` table |
| `kernel` | `EventLog` view, 6 core functions |
| `api` | `api.event_log`, `api.user_log` views + 7 API functions |
| `rest` | `rest.event` dispatcher (5 routes) |

## Tables

| Table | Description | Key Columns |
|-------|-------------|-------------|
| `db.log` | Event log | `id bigserial PK`, `type char` (M/W/E/D), `datetime timestamptz` (clock), `timestamp timestamptz` (txn), `username text`, `session char(40)`, `code int`, `event text`, `text text`, `category text`, `object uuid` |

## Type Codes

| Code | Meaning |
|------|---------|
| `M` | Message (info) |
| `W` | Warning |
| `E` | Error |
| `D` | Debug |

## Views

### kernel schema

| View | Description |
|------|-------------|
| `EventLog` | `db.log` with `TypeName` column translating M→"Информация", W→"Предупреждение", E→"Ошибка", D→"Отладка" |

### api schema

| View | Description |
|------|-------------|
| `api.event_log` | EventLog view |
| `api.user_log` | EventLog filtered by current user |

## Functions

### kernel schema — Core Logging

| Function | Returns | Purpose |
|----------|---------|---------|
| `AddEventLog(pType, pCode, pEvent, pText, pCategory, pObject)` | `bigint` | Create log entry, return ID |
| `NewEventLog(pType, pCode, pEvent, pText, pCategory, pObject)` | `void` | Create log entry (no return) |
| `WriteToEventLog(pType, pCode, pEvent, pText)` | `bigint` | Write event (shorthand) |
| `WriteToEventLog(pType, pCode, pEvent, pText, pCategory)` | `bigint` | Write event with category |
| `WriteToEventLog(pType, pCode, pEvent, pText, pCategory, pObject)` | `bigint` | Write event with category + object |
| `DeleteEventLog(pId)` | `void` | Delete log entry |
| `WriteDiagnostics(pMessage)` | `void` | Parse error message and write diagnostic entries |

### api schema

| Function | Returns | Purpose |
|----------|---------|---------|
| `api.event_log(pUserId, pType, pCode, pDateFrom, pDateTo)` | `SETOF api.event_log` | Query events (limit 500) |
| `api.user_log(pType, pCode, pDateFrom, pDateTo)` | `SETOF api.user_log` | Current user's events |
| `api.get_event_log(pId)` | `SETOF api.event_log` | Get single event |
| `api.get_user_log(pId)` | `SETOF api.user_log` | Get user's single event |
| `api.list_event_log(pSearch, pFilter, pLimit, pOffSet, pOrderBy)` | `SETOF api.event_log` | Dynamic list with search/filter/pagination |
| `api.list_user_log(pSearch, pFilter, pLimit, pOffSet, pOrderBy)` | `SETOF api.user_log` | User's dynamic list |
| `api.write_to_log(pType, pCode, pEvent, pText)` | `bigint` | API wrapper for logging |

## REST Routes — 5

Dispatcher: `rest.event(pPath text, pPayload jsonb)`.

| Path | Purpose |
|------|---------|
| `/event/log` | Query user's event log |
| `/event/log/set` | Write new event |
| `/event/log/get` | Get event by ID |
| `/event/log/count` | Count events with search/filter |
| `/event/log/list` | List events with pagination |

## Triggers

| Trigger | Table | Timing | Purpose |
|---------|-------|--------|---------|
| `t_log_insert` | `db.log` | BEFORE INSERT | Set datetime=clock_timestamp(), populate username/session from context |
| `t_log_after_insert` | `db.log` | AFTER INSERT | `pg_notify('log', ...)` with id, type, code, username, event, category |

## File Manifest

| File | In create | In update | Purpose |
|------|:---------:|:---------:|---------|
| `table.sql` | yes | no | `db.log` table + indexes + 2 triggers |
| `view.sql` | yes | yes | `EventLog` view |
| `routine.sql` | yes | yes | 7 core logging functions |
| `api.sql` | yes | yes | 2 api views + 7 API functions |
| `rest.sql` | yes | yes | `rest.event` dispatcher (5 routes) |
| `create.psql` | - | - | Includes all |
| `update.psql` | - | - | Includes view, routine, api, rest |
