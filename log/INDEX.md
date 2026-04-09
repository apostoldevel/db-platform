# log

> Platform module #9 | Loaded by `create.psql` line 9

Structured event logging system with three-axis filtering: **scope** (subsystem) × **code** (event type) × **category** (entity class).

Stores typed events (Message/Warning/Error/Debug) with user, session, scope, and optional object reference. Sends `pg_notify` on insert for real-time log monitoring.

## Dependencies

| Depends on | Depended by |
|------------|-------------|
| `kernel`, `admin` (for session/user context) | `api` (api_log references log), `admin` (event/log REST routes), all modules that call `WriteToEventLog` |

## Schemas Used

| Schema | Usage |
|--------|-------|
| `db` | `db.log` table |
| `kernel` | `EventLog` view, core functions |
| `api` | `api.event_log`, `api.user_log` views + API functions |
| `rest` | `rest.event` dispatcher (5 routes) |

## Table: db.log

| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `id` | `bigserial` | PK | Unique event identifier |
| `type` | `char` | `'M'` | Severity: M=Message, W=Warning, E=Error, D=Debug |
| `datetime` | `timestamptz` | `clock_timestamp()` | Wall-clock insertion time |
| `timestamp` | `timestamptz` | `Now()` | Transaction time |
| `username` | `text` | NOT NULL | User who triggered event (auto from context) |
| `session` | `char(40)` | NULL | Session token (auto from context) |
| `scope` | `text` | NULL | Event subsystem (e.g. `lifecycle`, `workflow`, `payment.stripe`) |
| `code` | `integer` | NOT NULL | Numeric event code from registry |
| `event` | `text` | NOT NULL | Event detail within scope (e.g. `create`, `enable`, `error`) |
| `text` | `text` | NOT NULL | Human-readable description |
| `category` | `text` | NULL | Entity class code (auto-resolved from object) |
| `object` | `uuid` | NULL | Related business object |

**Indexes:** `type`, `datetime`, `timestamp`, `username`, `code`, `event`, `category`, `scope`, `(scope, event)`, `(type, datetime)`, `(type, scope, datetime)`.

## Three-Axis Filtering

```
scope    → subsystem (exact match, B-tree)     e.g. WHERE scope = 'payment.stripe'
code     → specific event (range or exact)      e.g. WHERE code BETWEEN 2000 AND 2099
category → entity class (exact match)           e.g. WHERE category = 'charge_point'
```

Combined: `WHERE scope = 'ocpp.status' AND code = 4022 AND category = 'connector'`

## Code Registry

### 1xxx — Lifecycle (CRUD)

| Code | Event | Description |
|------|-------|-------------|
| 1001 | create | Object created |
| 1002 | open | Object opened for viewing |
| 1003 | edit | Object updated |
| 1004 | save | Object saved/committed |

### 2xxx — Workflow (state transitions)

| Code | Event | Description |
|------|-------|-------------|
| 2001 | enable | Activated |
| 2002 | disable | Deactivated |
| 2003 | delete | Soft-deleted |
| 2004 | restore | Restored from deletion |
| 2005 | drop | Permanently destroyed (type W) |
| 2010 | submit / execute | Submitted or execution started |
| 2011 | complete | Completed successfully |
| 2012 | confirm / done | Confirmed or finished |
| 2013 | reconfirm | Re-confirmed |
| 2020 | cancel | Cancelled |
| 2021 | fail | Failed (type W) |
| 2022 | close | Closed |
| 2023 | return | Returned |
| 2025 | abort | Aborted (type W) |
| 2030 | send | Sending (outbox) |
| 2031 | repeat | Resending (outbox) |

### 3xxx — Business Events

| Code | Event | Description |
|------|-------|-------------|
| 3001 | pay / preauth | Payment initiated or pre-authorized |
| 3002 | capture / done | Payment captured |
| 3003 | refund / cancel | Payment refunded or cancelled |
| 3004 | error | Payment error |
| 3010 | start | Charging started |
| 3011 | stop | Charging stopped |
| 3020 | create | Reservation created |
| 3021 | release | Reservation released |

### 4xxx — Integration

| Code | Event | Description |
|------|-------|-------------|
| 4001 | connect | External system connected |
| 4002 | disconnect | External system disconnected |
| 4010 | heartbeat | Heartbeat received |
| 4020–4027 | available–reserved | Status change (OCPP connector states) |
| 4030 | webhook | Webhook received |
| 4040 | offline | Device offline (type W) |

### 5xxx — Notifications

| Code | Event | Description |
|------|-------|-------------|
| 5001 | send / confirm | Email sent or confirmed |
| 5002 | send | Push notification sent |
| 5003 | send | SMS sent |
| 5010 | listen | Observer listener started |

### 6xxx — Admin & Security

| Code | Event | Description |
|------|-------|-------------|
| 6001 | phone_mismatch | Registration: different phone attempt |
| 6002 | phone_abuse | Registration: limit exceeded |
| 6010 | login | User logged in |
| 6011 | logout | User logged out |
| 6012 | password | Password changed (type W) |

### 9xxx — Errors & Diagnostics

| Code | Event | Description |
|------|-------|-------------|
| 9001 | error / context | Exception (type E) + debug context (type D) |
| 9003 | error | External API error |
| 9010 | sql | SQL debug statement |
| 9020 | diagnostic | Replication diagnostic |

## Scope Taxonomy

Two-level hierarchy via dot notation: `subsystem.detail`.

| Scope | Where used |
|-------|-----------|
| `lifecycle` | All entity CRUD events (create/open/edit/save) |
| `workflow` | All entity state transitions (enable/disable/delete/restore/drop) |
| `workflow.job` | Job entity (TaskScheduler): execute/complete/done/fail/abort |
| `workflow.outbox` | Outbox entity (MessageServer): submit/send/done/fail/repeat |
| `workflow.report` | ReportReady entity (ReportServer): execute/complete/fail/abort |
| `payment.stripe` | Stripe payment events |
| `payment.yookassa` | YooKassa payment events |
| `payment.cloudpayments` | CloudPayments payment events |
| `charging` | Charging session events |
| `charging.reservation` | Reservation events |
| `ocpp` | OCPP connectivity (connect/disconnect/heartbeat/offline) |
| `ocpp.status` | OCPP connector status changes |
| `notification.email` | Email notifications |
| `notification.push` | Push notifications |
| `notification.sms` | SMS notifications |
| `admin` | Admin/registration events |
| `auth` | Login/logout/password events |
| `observer` | Observer pub/sub events |
| `replication` | Replication diagnostics |
| `debug` | Debug SQL logging |
| `exception` | Exception handlers |
| `integration` | External integration (webhooks) |

## Functions

### Core Logging (kernel schema)

| Function | Returns | Description |
|----------|---------|-------------|
| `WriteToEventLog(pType, pCode, pScope, pEvent, pText, pObject)` | `void` | **Primary.** Write event with scope (6-arg). Checks `GetLogMode()`, resolves category from object |
| `WriteToEventLog(pType, pCode, pEvent, pText, pObject)` | `void` | Legacy 5-arg — delegates to 6-arg with scope=NULL |
| `WriteToEventLog(pType, pCode, pText, pObject)` | `void` | Legacy 4-arg — delegates with event='log' |
| `WriteDiagnostics(pMessage, pContext, pScope, pObject)` | `record` | **Primary.** Parse error, write E+D pair with scope |
| `WriteDiagnostics(pMessage, pContext, pObject)` | `record` | Legacy 3-arg — delegates with scope='exception' |
| `AddEventLog(pType, pCode, pScope, pEvent, pText, pCategory, pObject)` | `bigint` | Direct insert with scope, returns ID |
| `AddEventLog(pType, pCode, pEvent, pText, pCategory, pObject)` | `bigint` | Legacy — delegates with scope=NULL |
| `NewEventLog(...)` | `void` | Fire-and-forget wrappers (both signatures) |
| `DeleteEventLog(pId)` | `void` | Delete log entry |

### API Functions (api schema)

| Function | Returns | Description |
|----------|---------|-------------|
| `api.event_log(pUserName, pType, pCode, pScope, pDateFrom, pDateTo)` | `SETOF api.event_log` | Filter events (limit 500) |
| `api.user_log(pType, pCode, pScope, pDateFrom, pDateTo)` | `SETOF api.user_log` | Current user's events |
| `api.write_to_log(pType, pCode, pScope, pText)` | `SETOF api.event_log` | Write event via API |
| `api.get_event_log(pId)` | `SETOF api.event_log` | Get single event |
| `api.get_user_log(pId)` | `SETOF api.user_log` | Get user's single event |
| `api.count_event_log(pSearch, pFilter)` | `SETOF bigint` | Count with search/filter |
| `api.list_event_log(pSearch, pFilter, pLimit, pOffSet, pOrderBy)` | `SETOF api.event_log` | List with pagination |
| `api.count_user_log(pSearch, pFilter)` | `SETOF bigint` | Count user's entries |
| `api.list_user_log(pSearch, pFilter, pLimit, pOffSet, pOrderBy)` | `SETOF api.user_log` | List user's entries |

## Views

| View | Schema | Description |
|------|--------|-------------|
| `EventLog` | kernel | `db.log` + `TypeName` (Message/Warning/Error/Debug) + `Scope` |
| `api.event_log` | api | All events |
| `api.user_log` | api | Current user's events |

## REST Routes — 5

Dispatcher: `rest.event(pPath text, pPayload jsonb)`.

| Path | Method | Description |
|------|--------|-------------|
| `/event/log` | POST | Query user's event log (with type/code/scope/date filters) |
| `/event/log/set` | POST | Write new event (type, code, scope, text) |
| `/event/log/get` | POST | Get event by ID |
| `/event/log/count` | POST | Count events with search/filter |
| `/event/log/list` | POST | List events with pagination |

## Triggers

| Trigger | Table | Timing | Description |
|---------|-------|--------|-------------|
| `t_log_insert` | `db.log` | BEFORE INSERT | Auto-populate: datetime, username, session from context |
| `t_log_after_insert` | `db.log` | AFTER INSERT | `pg_notify('log', json)` with id, type, code, username, scope, event, category |

## Query Examples

```sql
-- All payment errors in the last week
SELECT * FROM EventLog WHERE type = 'E' AND scope LIKE 'payment%' AND datetime > now() - '7 days'::interval;

-- Workflow transitions for charge_point
SELECT * FROM EventLog WHERE scope = 'workflow' AND category = 'charge_point';

-- Full history of a specific object
SELECT * FROM EventLog WHERE object = '<uuid>' ORDER BY datetime;

-- OCPP status changes
SELECT * FROM EventLog WHERE scope = 'ocpp.status' ORDER BY datetime DESC LIMIT 100;

-- Auth events (login/logout/password)
SELECT * FROM EventLog WHERE scope = 'auth' ORDER BY datetime DESC;

-- All exceptions with context
SELECT * FROM EventLog WHERE scope = 'exception' ORDER BY datetime DESC;
```

## Log Rotation

Managed by `api.garbage_collector` in the configuration layer with differential retention:

| Type | Scope | Retention |
|------|-------|-----------|
| D (debug) | any | 7 days |
| M (message) | `payment.*` | 365 days |
| M (message) | `workflow` | 180 days |
| M (message) | all other | 90 days |
| W (warning) | any | 180 days |
| E (error) | any | 365 days |

## File Manifest

| File | In create | In update | Purpose |
|------|:---------:|:---------:|---------|
| `table.sql` | yes | no | `db.log` table + 11 indexes + 2 triggers |
| `view.sql` | yes | yes | `EventLog` view |
| `routine.sql` | yes | yes | Core logging functions (5 primary + 5 legacy) |
| `api.sql` | yes | yes | 2 api views + 9 API functions |
| `rest.sql` | yes | yes | `rest.event` dispatcher (5 routes) |
| `create.psql` | — | — | Includes all |
| `update.psql` | — | — | Includes view, routine, api, rest |

## Migration History

| Patch | Date | Change |
|-------|------|--------|
| `v1.2/P00000007.sql` | 2026-04-09 | Add `scope` column + composite indexes |
