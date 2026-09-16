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

### `api.*` wrappers for the pool role (`apibot`)

| Function | Returns | Purpose |
|----------|---------|---------|
| `api.authorize_local(pSession, pAgent, pHost)` | `record (authorized, userid, message)` | `Authorize` for a pooled connection: after authorising, moves every `current.*` context GUC from the session level to the transaction level, so after COMMIT/ROLLBACK the backend carries no identity. Same shape as `api.authorize`. Until `SessionIn` carries a `pLocal` parameter this is the guarantee |
| `api.log_request(pMethod, pPath, pPayload, pStatus, pRuntime, pRequestId)` | `bigint` | One `/api/v2` request into `db.api_log` the way `api.run` journals `/api/v1`: `AddApiLog` (a configuration may override it with its redaction list) + `runtime`; method, status and `X-Request-Id` travel in `json` under `_request` — `db.api_log` has no columns for them |
| `api.parse_message(pMessage)` | `record (code, message, error)` | `ParseMessage` reached through `api.*` — `apibot` has no USAGE on schema `kernel`, a direct grant would be dead. Feeds problem+json (К7) |

## Files

| File | create | update | Content |
|------|:------:|:------:|---------|
| `schema.sql` | yes | — | schema, USAGE grants, comment |
| `table.sql` | yes | — | `node`, `log`, indexes, trigger function + trigger, table grants |
| `view.sql` | yes | yes | `gateway.route` |
| `api.sql` | yes | yes | the three `api.*` wrappers |

## Patches

| Patch | Content |
|-------|---------|
| `patch/v1.2/P00000020.sql` | Self-contained, idempotent snapshot of schema + tables + trigger + view + grants. On a base that already has the schema from a project patch (csms `P00000044`) it adds the `administrator` grants and the comments; on any other base it creates the schema |

## Traps

- **`update.psql` never re-runs `table.sql`** — a change to the tables or the trigger needs a
  patch; the patch is a snapshot on purpose (`migrate.sh` may run it from a scratch directory
  where a relative `\ir` does not resolve).
- **A heartbeat must touch only `seen`** (or `address`, `capacity`): any UPDATE that changes
  `state` journals and notifies.
- **No `secret.gateway` anywhere.** The control socket takes `service-<domain>` tokens; a 401 there
  means the module was given the wrong client id or secret (`OAUTH2_SECRET_SERVICE`), not a
  missing audience.
