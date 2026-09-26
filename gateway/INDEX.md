# gateway

> Platform module #28 | Loaded by `create.psql` line 28 (last — depends on `admin`, `exception`, `api`)

The database half of the **GatewayAPI** module — the `/api/v2` gateway of track A. Keeps the
registry of module instances the gateway workers route to, journals their state transitions,
tells every worker about a transition with `pg_notify('gateway', …)`, and carries the three
`api.*` wrappers a module behind a connection pool calls instead of the C++ worker's
`api.authorize` / `api.run`. Design and contract: apostol-csms `clean-architecture/track-a-gateway.md`
§5 and `gateway-contract.md` (the К-numbers below). Moved here from the csms configuration on
2026-09-16 (T301): the C++ module is public, so is its schema.

**No OAuth2 identity of its own:** the modules authenticate the control socket with a
`client_credentials` token of the project's existing `service-<domain>` audience (К3 ed. 5, owner's
decision 16.09.2026). A separate `gateway-<domain>` audience existed in the design from T268 to T316
and was dropped.

## Dependencies

| Depends on | Depended by |
|------------|-------------|
| `admin` (`Authorize`), `exception` (`ParseMessage`), `api` (`db.api_log`, `AddApiLog`) | the GatewayAPI C++ worker (writes `gateway.node`), the Go `/api/v2` modules (`api.authorize_local` → work → `api.log_request`) |

## Schemas Used

| Schema | Usage |
|--------|-------|
| `gateway` | Own schema. 2 tables, 1 view, 1 trigger function. USAGE: `kernel`, `administrator`, `daemon`, `apibot` |
| `api` | 3 wrapper functions, EXECUTE `apibot` |

## Tables

| Table | Description | Key Columns |
|-------|-------------|-------------|
| `gateway.node` | One row per registered `/api/v2` module instance; written only by the GatewayAPI worker holding the instance's control socket, only on a state transition (`seen` moves once per heartbeat interval). Rows are never deleted by the database | `module text`, `instance text` (PK together), `address text` (data plane host:port, К7), `prefixes text[]`, `state text` CHECK ready/draining/suspect/offline/overloaded (К8), `capacity int`, `worker int` (pid), `registered`, `seen`, `updated timestamptz` |
| `gateway.log` | Journal of transitions, one row per INSERT / state UPDATE / DELETE on `gateway.node`, written by the trigger | `id bigserial PK`, `datetime`, `module`, `instance`, `state_from`, `state_to`, `worker`, `reason text` (from the session GUC `gateway.reason`) |
| `gateway.request` (1.2.31, UNLOGGED) | One `/api/v2` request opened by `daemon.begin` and not yet closed by `daemon.end`: the verified identity `daemon.call` restores the context from. Only `kernel` reads or writes it; a rolled-back transaction takes its row with it | `pid int`, `xid bigint` (PK together: `pg_backend_pid()`, `txid_current()`), `session`, `context jsonb`, `method`, `path`, `agent`, `host inet`, `request_id uuid`, `started`, `log bigint` (`db.api_log`) |
| `gateway.function` (1.2.31) | Allow list of `daemon.call` — closed by default | `signature text PK` (`name(type, …)` without the schema), `name`, `level` CHECK session / administrator |

Grants: `daemon`, `apibot` — `SELECT, INSERT, UPDATE, DELETE` on `node`, `SELECT, INSERT` on `log`,
USAGE on `log_id_seq`; `administrator` — `SELECT` on both.

## Views

| View | Source | Grants |
|------|--------|--------|
| `gateway.route` | `gateway.node` × `unnest(prefixes)` → one row per (prefix, module) with `instances_ready` / `instances_total`; only `ready` is in rotation, zero ready with total > 0 is the 503 case of К7 | `daemon`, `apibot`, `administrator` |

## Functions

### Trigger

| Function | Returns | Purpose |
|----------|---------|---------|
| `gateway.ft_node_notify()` | `trigger` | AFTER INSERT/UPDATE/DELETE on `gateway.node`: journals into `gateway.log` and `pg_notify('gateway', json)`. Skips an UPDATE that does not change `state` (heartbeat), so a fleet cannot turn the channel into a metronome. DELETE is journaled as → `offline`. Payload: `op, module, instance, state, state_from, address, prefixes, worker`. `reason` is read from `current_setting('gateway.reason', true)` — the worker sets it with `set_config(…, true)` before the statement |

### Route guards and the allow list of `daemon.call` (1.2.31, `routine.sql`)

The entry points are `daemon.begin` / `daemon.call` / `daemon.end` (see `daemon/INDEX.md`).

| Function | Returns | Purpose |
|----------|---------|---------|
| `GuardSession(pPath, pPayload, pMethod)` | `boolean` | Route guard: an open session that is **not** a member of `system` (the service audience is obtainable without a secret — ship-safety T289; a route `system` needs gets a guard of its own) |
| `GuardAdministrator(…)` | `boolean` | Route guard: `IsAdmin()` — the `/api/v2` twin of the check at the top of `rest.admin` / `rest.workflow` / `rest.registry` |
| `GuardRead(…)` | `boolean` | Route guard for a platform reference: `GET` → `GuardSession`, anything else → `GuardAdministrator` |
| `RegisterRouteGuard(pPrefix, pGuard, pMethods[], pVersion = 'v2')` | `void` | Declares the guard of `/api/<version>/<prefix>` for exactly the methods given. The prefix is plain segments (`a-z0-9_-`): a guard decides for its **whole subtree** — `QueryPath` stops at the first segment it does not know, so `vessels/{id}/x` is judged by the guard of `vessels`. Re-runnable and declarative: one endpoint per (path, method), a repeat replaces its definition, a method left out loses its route. `RegisterRoute` is not re-runnable (a repeat adds a second row for the pair) |
| `RegisterGatewayFunction(pSignature, pLevel = 'session')` | `void` | Opens `api.<fn>` to `daemon.call`. Refuses: outside schema `api`; by name — session openers, `run`/`sql`, the journal wrappers, `send_mail/sms/push*`, recovery and registration by code, `replication_apply*`; by body — any function calling `SubstituteUser`, `SignIn`, `Login`, `SessionIn`, `SetCurrentUserId`, `SetSessionUserId`; a second form of a name with the same key set |
| `UnregisterGatewayFunction(pSignature)` | `void` | Closes it again |
| `GatewayFunctionArgs(oid)` / `GatewayFunctionKeys(oid)` | `SETOF record` / `text[]` | IN parameters of a function: position, name, key (name without the leading `p`), type |
| `GatewayContext()` / `SetGatewayContext(jsonb)` | `jsonb` / `void` | The nine `current.*` context GUCs as an object; put back at the **transaction** level only (session level cleared) |
| `ResetGatewayVars()` | `void` | Clears every GUC the platform takes identity or intent from — the nine `current.*`, `current.key`, `object.id`, `context.*` — at both levels. First line of `daemon.begin` (a value set before the request is never taken as verified), and before the context is put back in `call`/`end` |
| `InitGatewayRoutes()` / `InitGatewayFunctions()` / `InitGateway()` | `void` | The platform's own `/api/v2` routes (31 prefixes of the go-platform modules) and allow list (levels as the Go code needs them). Re-runnable: `init.sql` and the end of `update.psql`. A configuration registers its own prefixes and functions the same way |

### `api.*` wrappers for the pool role (`apibot`)

| Function | Returns | Purpose |
|----------|---------|---------|
| `api.authorize_local(pSession, pAgent, pHost)` | `record (authorized, userid, message)` | `Authorize` for a pooled connection: after authorising, moves every `current.*` context GUC from the session level to the transaction level, so after COMMIT/ROLLBACK the backend carries no identity. Same shape as `api.authorize`. Until `SessionIn` carries a `pLocal` parameter this is the guarantee |
| `api.log_request(pMethod, pPath, pPayload, pStatus, pRuntime, pRequestId, pError)` | `bigint` | One `/api/v2` request into `db.api_log` the way `api.run` journals `/api/v1`: `AddApiLog` (a configuration may override it with its redaction list) + `runtime`; method, status, `X-Request-Id` and — since 1.2.24 (P00000024) — the catalogue code of a refusal (`pError`) travel in `json` under `_request` — `db.api_log` has no columns for them. Needs no session: a refusal is written after `ROLLBACK TO SAVEPOINT` or in a fresh transaction |
| `api.parse_message(pMessage)` | `record (code, message, error)` | `ParseMessage` reached through `api.*` — `apibot` has no USAGE on schema `kernel`, a direct grant would be dead. Feeds problem+json (К7) |

## Files

| File | create | update | Content |
|------|:------:|:------:|---------|
| `schema.sql` | yes | — | schema, USAGE grants, comment |
| `table.sql` | yes | — | `node`, `log`, indexes, trigger function + trigger, table grants |
| `view.sql` | yes | yes | `gateway.route` |
| `routine.sql` (1.2.31) | yes | yes | route guards, the registrars, the context helpers, `InitGateway*` |
| `api.sql` | yes | yes | the three `api.*` wrappers |

`update.psql` ends with `InitGateway()` — gateway is the last module, so every function of schema
`api` exists by then.

## Patches

| Patch | Content |
|-------|---------|
| `patch/v1.2/P00000020.sql` | Self-contained, idempotent snapshot of schema + tables + trigger + view + grants. On a base that already has the schema from a project patch (csms `P00000044`) it adds the `administrator` grants and the comments; on any other base it creates the schema |
| `patch/v1.2/P00000026.sql` | 1.2.31: `gateway.request`, `gateway.function`, `PATCH` in `db.route.method`, `db.protected_group`, error group 403. Routes and the allow list are written by `update.psql` after it |

## Traps

- **`update.psql` never re-runs `table.sql`** — a change to the tables or the trigger needs a
  patch; the patch is a snapshot on purpose (`migrate.sh` may run it from a scratch directory
  where a relative `\ir` does not resolve).
- **A heartbeat must touch only `seen`** (or `address`, `capacity`): any UPDATE that changes
  `state` journals and notifies.
- **Never trust `current.*` on the daemon road.** The `daemon` connection can `set_config` any of
  them; `daemon.call` puts the context back from `gateway.request` before every call. A new
  function that reads identity from elsewhere (a GUC of its own) is outside that guarantee.
- **A route guard is not tied to the functions.** Every function of level `session` is reachable
  under any route whose guard lets the session in; a finer guard of a configuration protects the
  route, not the functions. What a non-administrator must not reach is `administrator` in the list.
- **`InitGatewayFunctions` only adds and updates levels.** A function taken out of the list stays open on a
  database that had it: closing one takes an explicit `UnregisterGatewayFunction` (in `update.psql` or a patch).
- **The allow list is by signature, the call by name.** Two forms of a name with the same key set
  cannot both be open; open one and give the other a name of its own (`set_session_area_by_code`).
- **No `secret.gateway` anywhere.** The control socket takes `service-<domain>` tokens; a 401 there
  means the module was given the wrong client id or secret (`OAUTH2_SECRET_SERVICE`), not a
  missing audience.
