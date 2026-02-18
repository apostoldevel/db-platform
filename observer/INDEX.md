# observer

> Platform module #23 | Loaded by `create.psql` line 23

Pub/Sub event system. Publishers emit events; listeners subscribe with filters and params. Supports six predefined publisher types (`notify`, `notice`, `message`, `replication`, `log`, `geo`) with extensible filter/param validation. Listeners can receive events as notifications, objects, mixed payloads, or trigger webhook-style API calls.

## Dependencies

| Depends on | Depended by |
|------------|-------------|
| `kernel`, `admin` (sessions), `workflow` (entity/class/action), `entity/object` (access control), `api` (for hook execution via `api.run()`) | C++ Workers (event dispatch via `daemon.observer`), client WebSocket connections |

## Schemas Used

| Schema | Usage |
|--------|-------|
| `db` | 2 tables (publisher, listener) |
| `kernel` | 2 views, ~14 functions |
| `api` | 2 views, ~11 functions |
| `rest` | `rest.observer` dispatcher (11 routes) |

## Tables — 2

| Table | Description | Key Columns |
|-------|-------------|-------------|
| `db.publisher` | Publisher registry | `code text PK`, `name text`, `description text` |
| `db.listener` | Listener subscriptions | `publisher text FK`, `session varchar FK`, `identity text`, `filter jsonb`, `params jsonb` |

## Views — 2

| View | Description |
|------|-------------|
| `Publisher` | Direct projection of `db.publisher` |
| `Listener` | Direct projection of `db.listener` |

## Functions (kernel schema) — ~14

### Publisher CRUD

| Function | Returns | Purpose |
|----------|---------|---------|
| `CreatePublisher(pCode, pName, pDescription)` | `void` | Create publisher |
| `EditPublisher(pCode, pName, pDescription)` | `void` | Update publisher |
| `DeletePublisher(pCode)` | `void` | Delete publisher |

### Listener CRUD

| Function | Returns | Purpose |
|----------|---------|---------|
| `CreateListener(pPublisher, pSession, pIdentity, pFilter, pParams)` | `void` | Subscribe |
| `EditListener(pPublisher, pSession, pIdentity, pFilter, pParams)` | `boolean` | Update subscription |
| `DeleteListener(pPublisher, pSession, pIdentity)` | `boolean` | Unsubscribe |

### Validation

| Function | Returns | Purpose |
|----------|---------|---------|
| `CheckListenerFilter(pPublisher, pFilter)` | `void` | Validate filter JSON per publisher type (entity/class/action/method/object codes) |
| `DoCheckListenerFilter(pPublisher, pFilter)` | `void` | Extension point (configuration override) |
| `CheckListenerParams(pPublisher, pParams)` | `void` | Validate params: type (`notify`/`object`/`mixed`/`hook`), hook structure |
| `DoCheckListenerParams(pPublisher, pParams)` | `void` | Extension point |

### Event Processing

| Function | Returns | Purpose |
|----------|---------|---------|
| `FilterListener(pPublisher, pSession, pIdentity, pData)` | `boolean` | Test if listener matches event data (includes `CheckObjectAccess`) |
| `DoFilterListener(pPublisher, pSession, pIdentity, pData)` | `boolean` | Extension point (returns false) |
| `EventListener(pPublisher, pSession, pIdentity, pData)` | `SETOF json` | Dispatch: route event to matching listeners, support `notify`/`object`/`mixed`/`hook` return types |
| `DoEventListener(pPublisher, pSession, pIdentity, pData)` | `SETOF json` | Extension point (returns pData) |

### Initialization

| Function | Returns | Purpose |
|----------|---------|---------|
| `InitListen()` | `void` | Boot-time: execute PostgreSQL LISTEN for all publishers |

## Predefined Publishers

| Publisher | Filter Schema | Purpose |
|-----------|--------------|---------|
| `notify` | entity, class, action, method, object | State transition notifications |
| `notice` | userid, object, category | User alert notifications |
| `message` | class, type, agent, code, profile, address, subject | Message queue events |
| `replication` | source, class, action | Database replication events |
| `log` | type, code, category | Event log entries |
| `geo` | code | Geographic/coordinate updates |

## Listener Param Types

| Type | Behavior |
|------|----------|
| `notify` | Return raw notification JSON |
| `object` | Return full object via `api.get_{entitycode}()` |
| `mixed` | Return both notification and object |
| `hook` | Call `api.run(method, path, payload)` internally |

## Functions (api schema) — ~11

Standard publisher/listener CRUD plus:

| Function | Returns | Purpose |
|----------|---------|---------|
| `api.subscribe_observer(pPublisher, pSession, pIdentity, pFilter, pParams)` | `SETOF api.listener` | Subscribe (uses `current_session()` if NULL) |
| `api.unsubscribe_observer(pPublisher, pSession, pIdentity)` | `boolean` | Unsubscribe (uses `current_session()` if NULL) |

## REST Routes — 11

Dispatcher: `rest.observer(pPath text, pPayload jsonb)`.

| Path | Purpose |
|------|---------|
| `/observer/subscribe` | Subscribe to publisher |
| `/observer/unsubscribe` | Unsubscribe from publisher |
| `/observer/publisher` | Get publisher by code |
| `/observer/publisher/get` | Get publisher(s) with field projection |
| `/observer/publisher/count` | Count publishers |
| `/observer/publisher/list` | List publishers with search/filter |
| `/observer/listener` | Get listener by key |
| `/observer/listener/set` | Create/update listener |
| `/observer/listener/get` | Get listener(s) with field projection |
| `/observer/listener/count` | Count listeners |
| `/observer/listener/list` | List listeners with search/filter |

## File Manifest

| File | In create | In update | Purpose |
|------|:---------:|:---------:|---------|
| `table.sql` | yes | no | 2 tables |
| `view.sql` | yes | yes | Publisher, Listener views |
| `routine.sql` | yes | yes | ~14 kernel functions |
| `api.sql` | yes | yes | 2 api views + ~11 api functions |
| `rest.sql` | yes | yes | `rest.observer` dispatcher (11 routes) |
| `create.psql` | - | - | Includes all |
| `update.psql` | - | - | Excludes table.sql |
