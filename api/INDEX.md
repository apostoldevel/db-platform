# api

> Platform module #10 | Loaded by `create.psql` line 10

REST API infrastructure: path hierarchy, endpoint registration, route dispatching, request logging, and the main `rest.api` entry point. All incoming REST requests flow through `rest.api`, which resolves the first path segment to a registered dispatcher (e.g., `/admin/...` → `rest.admin`, `/user/...` → `rest.user`). Also provides `api.sql()` — the dynamic SQL query builder used by all `list_*` functions across the platform.

## Dependencies

| Depends on | Depended by |
|------------|-------------|
| `kernel`, `admin`, `log` | Every module with REST routes (routes registered via `RegisterRoute` in init.sql) |

## Schemas Used

| Schema | Usage |
|--------|-------|
| `db` | `db.path`, `db.endpoint`, `db.route`, `db.api_log` tables |
| `kernel` | `Routs`, `apiLog` views; path/endpoint/route functions |
| `api` | `api.log` view; `api.sql()`, `api.run()`, query functions |
| `rest` | `rest.api` main dispatcher (~43 routes including delegated) |

## Tables

| Table | Description | Key Columns |
|-------|-------------|-------------|
| `db.path` | API path hierarchy (tree) | `id uuid PK`, `root uuid FK(self)`, `parent uuid FK(self)`, `name text`, `level int`; UNIQUE(`root`,`parent`,`name`) |
| `db.endpoint` | Endpoint definitions | `id uuid PK`, `definition text` (PL/pgSQL function body) |
| `db.route` | Route→endpoint mapping | PK(`method text`, `path uuid FK`, `endpoint uuid FK`); method ∈ {GET,POST,PUT,DELETE} |
| `db.api_log` | API request/response log | `id bigserial PK`, `datetime timestamptz`, `session char(40)`, `username text`, `path text`, `nonce double`, `signature text`, `json jsonb` (sanitized), `eventId bigint FK(db.log)`, `runtime interval` |

## Views

### kernel schema

| View | Description |
|------|-------------|
| `Routs` | All registered routes: method, full path (assembled), endpoint definition |
| `apiLog` | API log with nonce→timestamp conversion, runtime rounded to 3 decimals |

### api schema

| View | Description |
|------|-------------|
| `api.log` | Formatted API log |

## Functions

### Path Management

| Function | Returns | Purpose |
|----------|---------|---------|
| `AddPath(pRoot, pParent, pName, pLevel)` | `uuid` | Create path node |
| `GetPath(pParent, pName)` | `uuid` | Find path by parent+name |
| `FindPath(pPath)` | `uuid` | Resolve full path string to ID |
| `CollectPath(pId)` | `text` | Assemble full path from ID |
| `RegisterPath(pPath)` | `uuid` | Create full path hierarchy from string |
| `UnregisterPath(pPath)` | `void` | Remove path |
| `QueryPath(pPath)` | `uuid` | Find path, raise RouteNotFound if missing |
| `DeletePath(pId)` / `DeletePaths(pId)` | `void` | Delete path / recursive delete |

### Endpoint & Route

| Function | Returns | Purpose |
|----------|---------|---------|
| `AddEndPoint(pDefinition)` | `uuid` | Create endpoint |
| `EditEndPoint(pId, pDefinition)` | `void` | Update endpoint |
| `GetEndpoint(pPath, pMethod)` | `uuid` | Lookup endpoint for path+method |
| `GetEndpointDefinition(pId)` | `text` | Get endpoint code |
| `DeleteEndpoint(pId)` | `void` | Remove endpoint |
| `RegisterRoute(pPath, pEndpoint, pMethod)` | `uuid` | Register route |
| `UnregisterRoute(pPath, pMethod)` | `void` | Unregister route |

### Dynamic Execution

| Function | Returns | Purpose |
|----------|---------|---------|
| `ExecuteDynamicMethod(pPath, pMethod, pPayload)` | `SETOF json` | Execute endpoint definition as dynamic PL/pgSQL |
| `api.run(pPath, pJson)` | `SETOF json` | Generic method execution |

### API Logging

| Function | Returns | Purpose |
|----------|---------|---------|
| `AddApiLog(pPath, pJson, pNonce, pSignature)` | `bigint` | Create API log entry |
| `NewApiLog(pPath, pJson, pNonce, pSignature)` | `void` | Create log (no return) |
| `WriteToApiLog(pPath, pJson, ...)` | `bigint` | Write log with optional nonce/signature |
| `DeleteApiLog(pId)` | `void` | Remove entry |
| `ClearApiLog(pDate)` | `void` | Remove logs before date |

### api.sql() — Dynamic Query Builder

`api.sql(pSchema, pTable, pFields, pSearch, pFilter, pLimit, pOffSet, pOrderBy)` → `text`

Generates dynamic SQL SELECT from JSONB search criteria. Used by every `api.list_*` function. Search format:
```json
[{"condition":"AND", "field":"name", "compare":"LKE", "value":"test%"}]
```

Compare operators: `EQL`, `NEQ`, `LSS`, `LEQ`, `GTR`, `GEQ`, `GIN`, `LKE`, `ISN`, `INN`.

### API Query Functions

| Function | Returns | Purpose |
|----------|---------|---------|
| `api.log(pUserId, pPath, pDateFrom, pDateTo)` | `SETOF api.log` | Query API logs |
| `api.get_log(pId)` | `SETOF api.log` | Get single log entry |
| `api.list_log(pSearch, pFilter, pLimit, pOffSet, pOrderBy)` | `SETOF api.log` | Dynamic list |

## REST Routes

Dispatcher: `rest.api(pPath text, pPayload jsonb)` — the **main entry point** for all REST requests.

### Direct Routes (~14)

| Path | Purpose |
|------|---------|
| `/ping` | Health check |
| `/time` | Server time |
| `/authenticate` | Authenticate session |
| `/authorize` | Authorize session |
| `/su` | Substitute user |
| `/search` | Full-text search |
| `/whoami` | Current user info |
| `/run` | Execute dynamic method |
| `/locale` | Get locale |
| `/locale/set` | Set locale |
| `/entity` | List entities |
| `/type` | List types |
| `/class` | List classes |
| `/priority` | List priorities |

### Delegated Routes (~18 module dispatchers)

| First Segment | Dispatcher |
|---------------|------------|
| `/sign/*` | `rest.sign` |
| `/user/*` | `rest.user` |
| `/state/*` | `rest.state` |
| `/action/*` | `rest.action` |
| `/method/*` | `rest.method` |
| `/member/*` | `rest.member` |
| `/admin/*` | `rest.admin` |
| `/current/*` | `rest.current` |
| `/event/*` | `rest.event` |
| `/kladr/*` | `rest.kladr` |
| `/notification/*` | `rest.notification` |
| `/observer/*` | `rest.observer` |
| `/registry/*` | `rest.registry` |
| `/resource/*` | `rest.resource` |
| `/session/*` | `rest.session` |
| `/verification/*` | `rest.verification` |
| `/workflow/*` | `rest.workflow` |

## Init / Seed Data

`InitAPI()` registers 18 route paths mapping first URL segments to dispatcher functions:
- `null` → `rest.api` (root)
- `'sign'` → `rest.sign`
- `'admin'` → `rest.admin`
- ... (see Delegated Routes above)

## File Manifest

| File | In create | In update | Purpose |
|------|:---------:|:---------:|---------|
| `table.sql` | yes | no | `db.path`, `db.endpoint`, `db.route` tables + trigger |
| `routine.sql` | yes | yes | Path/endpoint/route management functions |
| `view.sql` | yes | yes | `Routs`, `apiLog` views |
| `log.sql` | yes | yes | `db.api_log` table, logging functions, apiLog view |
| `api.sql` | yes | yes | `api.sql()`, `api.run()`, query functions, api views |
| `rest.sql` | yes | yes | `rest.api` main dispatcher |
| `init.sql` | yes | yes | `InitAPI()` route registration |
| `create.psql` | - | - | Includes all |
| `update.psql` | - | - | Includes routine, view, log, api, rest, init |
