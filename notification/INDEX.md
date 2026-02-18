# notification

> Platform module #21 | Loaded by `create.psql` line 21

Event audit trail and notification dispatch. Records every state transition (method execution) on objects, with specialized PostgreSQL NOTIFY routing for inbox/outbox messages and report execution. Provides access-controlled notification queries and object method history views.

## Dependencies

| Depends on | Depended by |
|------------|-------------|
| `kernel`, `workflow` (entity, class, action, method, state), `entity/object` (aou access control) | `observer` (pub/sub triggering), client applications (real-time updates), C++ MessageServer |

## Schemas Used

| Schema | Usage |
|--------|-------|
| `db` | 1 table (notification) + 1 trigger |
| `kernel` | 2 views, 4 functions |
| `api` | 2 views, 6 functions |
| `rest` | `rest.notification` dispatcher (5 routes) |

## Tables — 1

| Table | Description | Key Columns |
|-------|-------------|-------------|
| `db.notification` | Event audit entries | `id uuid PK`, `entity uuid FK`, `class uuid FK`, `action uuid FK`, `method uuid FK`, `state_old uuid FK`, `state_new uuid FK`, `object uuid FK`, `userid uuid FK`, `datetime timestamptz` |

All FK columns have `ON DELETE CASCADE`.

## Triggers — 1

| Trigger | Table | Timing | Purpose |
|---------|-------|--------|---------|
| `t_notification_after_insert` | `db.notification` | AFTER INSERT | Routes to pg_notify channels based on entity/class/action |

**Routing rules:**
- Always: `pg_notify('notify', row_to_json(NEW))`
- `entity=message, class=inbox, action=create` → `pg_notify('inbox', object::text)`
- `entity=message, class=outbox, action IN (submit,repeat)` → `pg_notify('outbox', object::text)`
- `entity=report_ready, action=execute` → `pg_notify('report', JSON {session, id})`

## Views — 2 kernel + 2 api

| View | Description |
|------|-------------|
| `Notification` | Full notification with entity/class/action/method names, old/new state details |
| `ObjectMethodHistory` | Detailed audit trail with user profile (name, phone, email, picture), method/action/state labels |
| `api.notification` | Passthrough from `Notification` |
| `api.object_method_history` | Passthrough from `ObjectMethodHistory` |

## Functions (kernel schema) — 4

| Function | Returns | Purpose |
|----------|---------|---------|
| `CreateNotification(pEntity, pClass, pAction, pMethod, pStateOld, pStateNew, pObject, pUserId, pDateTime)` | `uuid` | Direct insert |
| `EditNotification(pId, ...)` | `void` | Coalesce-based update |
| `AddNotification(pClass, pAction, pMethod, pStateOld, pStateNew, pObject, pUserId, pDateTime)` | `void` | Convenience: auto-looks up entity from class |
| `Notification(pDateFrom, pUserId)` | `SETOF Notification` | Access-controlled query: filters by aou mask `B'100'` with group membership expansion |

## Functions (api schema) — 6

| Function | Returns | Purpose |
|----------|---------|---------|
| `api.notification(pDateFrom, pUserId)` | `SETOF api.notification` | Wrapper for `Notification()` |
| `api.get_notification(pId)` | `SETOF api.notification` | Get by ID |
| `api.list_notification(pSearch, pFilter, pLimit, pOffSet, pOrderBy)` | `SETOF api.notification` | List with search/filter/pagination |
| `api.get_object_method_history(pId)` | `SETOF api.object_method_history` | Get history for object |
| `api.list_object_method_history(pSearch, pFilter, pLimit, pOffSet, pOrderBy)` | `SETOF api.object_method_history` | List history |

## REST Routes — 5

Dispatcher: `rest.notification(pPath text, pPayload jsonb)`.

| Path | Purpose |
|------|---------|
| `/notification` | Get notifications from timestamp point (`{point: unix_ts}`) |
| `/notification/get` | Get single by ID with field projection |
| `/notification/count` | Count with search/filter |
| `/notification/list` | List with search/filter/pagination + optional groupby |
| `/notification/changed/objects` | Get changed entity objects in date range (calls `api.get_{entitycode}()`) |

## File Manifest

| File | In create | In update | Purpose |
|------|:---------:|:---------:|---------|
| `table.sql` | yes | no | 1 table + 1 trigger |
| `view.sql` | yes | yes | Notification, ObjectMethodHistory views |
| `routine.sql` | yes | yes | 4 kernel functions |
| `api.sql` | yes | yes | 2 api views + 6 api functions |
| `rest.sql` | yes | yes | `rest.notification` dispatcher (5 routes) |
| `create.psql` | - | - | Includes all |
| `update.psql` | - | - | Excludes table.sql |
