# http

> Platform module #5 | Loaded by `create.psql` line 5

HTTP request/response queue with logging and callback mechanism. Provides an outbound HTTP client (fetch) that queues requests for the C++ application layer to execute, and an inbound HTTP API (get/post) for simple endpoints. Uses pg_notify to signal new requests.

## Dependencies

| Depends on | Depended by |
|------------|-------------|
| `kernel` | `daemon` (HTTP callbacks), `notification` (push via HTTP), `verification` (email/SMS via HTTP) |

## Schemas Used

| Schema | Usage |
|--------|-------|
| `http` | Own schema (AUTHORIZATION kernel). 3 tables, 1 view, 12 functions |

## Tables

| Table | Description | Key Columns |
|-------|-------------|-------------|
| `http.log` | Inbound HTTP request log | `id bigserial PK`, `method text` (GET/POST/PUT/DELETE/...), `path text`, `headers jsonb`, `params jsonb`, `body jsonb`, `message text`, `runtime interval` |
| `http.request` | Outbound HTTP request queue | `id uuid PK`, `state int` (0=created,1=executing,2=done,3=failed), `type text` (native/curl), `method text`, `resource text` (URL), `done/fail/stream text` (callback function names), `agent text`, `content bytea`, `data jsonb`, resend contract: `expire interval`, `max_attempts int`, `attempts int`, `attempted timestamptz` |
| `http.response` | HTTP responses | `id uuid PK`, `request uuid FK`, `status int`, `status_text text`, `headers jsonb`, `content bytea`, `runtime interval` |

## Views

| View | Source | Grants |
|------|--------|--------|
| `http.fetch` | LEFT JOIN `http.request` + `http.response` | `public` |

## Functions

### Logging

| Function | Returns | Purpose |
|----------|---------|---------|
| `http.write_to_log(pPath, pHeaders, ...)` | `bigint` | Log inbound HTTP request; credential headers and credential keys of params/body are stored as `***` |
| `http.mask_headers(pHeaders)` | `jsonb` | Header object with the value of every credential header replaced by `***` |
| `http.mask_json(pJson)` | `jsonb` | JSON document with the value of every credential key (any depth up to 32 levels) replaced by `***`; a `number` key holding a card number too |
| `http.mask_json_level(pJson, pLevel)` | `jsonb` | One level of the `http.mask_json` walk (bounded recursion) |
| `http.is_credential_name(pName, pHeader)` | `boolean` | The name rule: does a header / key / field name carry a credential |
| `http.credential_pattern()` | `text` | The regular expression of credential names, used by the rule and by the cheap gate in `http.mask_json` |

### Request/Response Management

| Function | Returns | Purpose |
|----------|---------|---------|
| `http.create_request(pResource, pMethod, ..., pExpire, pMaxAttempts)` | `uuid` | Create outbound request (state=1) |
| `http.request(pId)` | `SETOF http.request` | Get request by ID (read only; the sender reads through `http.take` since 1.2.32) |
| `http.take(pId)` | `SETOF http.request` | The row to send, or none (gone, state 2/3, lifetime elapsed — closed to 3 without callback) |
| `http.sweep(pAge, pLimit)` | `SETOF uuid` | Hand out rows under the resend contract older than `pAge` (attempts + 1, attempted = now()); close spent ones to 3 without callback. A row that has a delivery row in `notify.queue` (channel `http`, key = the request id, any state) is neither handed out nor closed — its repeat is notify's (since 1.2.39) |
| `http.create_response(pRequest, pStatus, ...)` | `uuid` | Store response, compute runtime, call done() |
| `http.done(pRequest)` | `void` | Set request state=2 (done) |
| `http.fail(pRequest, pError)` | `void` | Set request state=3 (failed) |
| `http.try_done(pRequest)` | `boolean` | Close an open request (state ≤ 1) as done; `true` — this call closed it, `false` — an outcome was written already, or no such row. Unlike `http.done`, never overwrites an outcome |
| `http.try_fail(pRequest, pError)` | `boolean` | The same for state=3; the first error stays |
| `http.try_create_response(pRequest, pStatus, pStatusText, pHeaders, pContent)` | `boolean` | *notify.sql, 1.2.39.* Close an open request as done FIRST (its row lock), then store the response; `false` — the row is not open, nothing stored. The sender of a row `notify` leads calls it in one query with the producer's done callback and `notify.ack`; `http.create_response` stays for the previous sender. apibot, daemon |
| `http.retake(pId)` | `SETOF http.request` | *notify.sql.* The row of a REPEAT delivery (`notify.take` said `attempts` > 1). As `http.take`, but a lifetime that ended (counted from `datetime`) closes the row as `outcome unknown` and calls the producer's fail callback instead of closing it quietly. apibot, daemon |
| `http.fail_unknown(pRequest, pMessage)` | `boolean` | *notify.sql.* `http.try_fail` + the fail callback (its own sub-transaction: a throwing callback leaves the row closed, the reason is appended to `error`). Owner only |
| `http.abandon(pId, pKey, pPayload, pReason)` | `void` | *notify.sql.* `on_abandon` of the channel `http`. Reason `unsent:` / `unrouted:` / `nack: unsent:` / `nack: stopping:` → closed `not sent: …`, no callback; any other (`orphaned:`, `nack: …`) → `outcome unknown: …` and the fail callback. Owner only |

### Inbound HTTP API

| Function | Returns | Purpose |
|----------|---------|---------|
| `http.get(path, headers, params)` | `SETOF json` | Handle GET: /v1/ping, /v1/time, /v1/headers, /v1/params, /v1/log |
| `http.post(path, headers, params, body)` | `SETOF json` | Handle POST: same routes + /v1/body |

### Outbound Fetch (3 overloads)

| Function | Content Type | Purpose |
|----------|-------------|---------|
| `http.fetch(..., content bytea, ...)` | raw bytes | Queue HTTP request with bytea body |
| `http.fetch(..., content text, ...)` | text→bytea | Queue HTTP request with text body (UTF8 encoded) |
| `http.fetch(..., content jsonb, ...)` | JSON→bytea | Queue HTTP request with JSON body (auto Content-Type header) |

Callback names (`done`, `fail`, `stream`) are checked in `http.create_request`, so on every fetch overload and on a direct call: exactly `schema.function` in lower case (`^[a-z_][a-z0-9_]*\.[a-z_][a-z0-9_]*$`) — the sender calls the function by that name — and an existing function of that name in `pg_catalog.pg_proc`; otherwise the request is refused (`Invalid callback function name` / `Not found function`). All fetch overloads take the trailing `expire interval`, `max_attempts integer` (both default NULL).

### Resend contract (1.2.32)

The sender (C++ PGFetch) learns of a request only by `NOTIFY`; a row created while its `LISTEN` is down would stay in state 1 forever. The producer opts a request into resend with `expire` (lifetime from `datetime`) and `max_attempts`; NULL `expire` or 0 attempts — never resent, and `http.sweep` never touches a row without `expire`. After its `LISTEN` is up the sender waits `pAge` (longer than its own timeout — a younger row may still be in flight), calls `http.sweep`, and sends each id it gets through `http.take`, the same way as a notified one. `attempts` counts resends only. Rows whose lifetime or attempts ran out are closed on the way (state 3, `error` `expired:` / `abandoned:`), with no callback: their appearance is a signal to administrators.

Resend is **at-least-once**: a row sent whose response was not stored (the connection dropped mid-flight) goes again with the same headers — a request that must not repeat carries its idempotency key there, or sets no `expire`. Ages count from `datetime` (the INSERT, not the COMMIT): `expire` and `pAge` must exceed the producer's longest transaction. No `expire` on a stream (SSE).

## Triggers

| Trigger | Table | Timing | Purpose |
|---------|-------|--------|---------|
| `t_request_after_insert` | `http.request` | AFTER INSERT | `notify.send('http', id, id, expire, max_attempts)` — `max_attempts` only with `expire`. While the channel is `legacy` that is `pg_notify('http', id)`, as before notify; since 1.2.39 it lives in `P00000038` too (`update.psql` never re-runs `table.sql`) |

## File Manifest

| File | In create | In update | Purpose |
|------|:---------:|:---------:|---------|
| `schema.sql` | yes* | no | CREATE SCHEMA http, GRANT to administrator/daemon/apibot |
| `table.sql` | yes | no | 3 tables + notify trigger |
| `view.sql` | yes | yes | `http.fetch` joined view |
| `routine.sql` | yes | yes | 20 functions (logging, CRUD, take/sweep, try_done/try_fail, get/post, fetch, masking) |
| `notify.sql` | yes | yes | the channel `http` on notify: `try_create_response`, `retake`, `fail_unknown`, `abandon` and their privileges. Its own file so that patch `P00000038` can include it alone (`routine.sql` holds `http.get`/`http.post`, which a configuration overrides) |
| `create.psql` | - | - | Includes all |
| `update.psql` | - | - | Includes view, routine, notify |

### The channel on notify (1.2.39, T1102)

While the channel `http` of `notify.channel` is `legacy` a sender sees what it saw before: `notify.send` is `pg_notify`, it reads through `http.take` and resends through `http.sweep` (which hands out at most `pLimit` rows now — its batch is chosen once; the exclusion of rows with a delivery row changes nothing while there are none). The new functions are granted to the pools only. Once it is `single`, a request has a delivery row (`notify.queue`, key = the request id, `expire` and `max_attempts` of the request — `max_attempts` only with `expire`: a request outside the resend contract is never sent twice) and the sender works like this:

1. `notify.take(row, subscriber)` → `payload` (the request id), `token`, `attempts`.
2. `http.take(id)` when `attempts` = 1, `http.retake(id)` when it is more: no row means "do not send" (the row is closed, or its lifetime from `datetime` ended — see above), and the sender still `notify.ack`s its row.
3. Settle in ONE query: `notify.ack(row, token)` FIRST, then `http.try_create_response` (or `http.try_fail`), then the producer's callback only for a `true`. A stale token raises `NT409` and takes everything with it. The order matters: `notify.close` locks the delivery row and then the request (`http.abandon`), so a settle that locks the request first and the delivery row last can deadlock with the sweep (SQLSTATE 40P01; both ends stay consistent, but the response is lost).
4. A row nobody confirms ends in `notify.close` → `http.abandon` (the `on_abandon` of the channel): see its row in the table. `lease` is 2 minutes — more than the flight (the sender's timeout + 10 s + 20 s).

`http.sweep` is for the rows of the legacy era only (no delivery row, any state of it); a request that a v1.23.3 sender left in flight at the switch is resent by it as before. A request that is still open while its delivery row is closed (`on_abandon` died after `notify.close` — a cancel, a deadlock) is not reconciled by anything: find it with `SELECT r.id FROM http.request r JOIN notify.queue q ON q.channel = 'http' AND q.key = r.id::text WHERE r.state <= 1 AND q.state = 3`.
