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
| `http.write_to_log(pPath, pHeaders, ...)` | `bigint` | Log inbound HTTP request |

### Request/Response Management

| Function | Returns | Purpose |
|----------|---------|---------|
| `http.create_request(pResource, pMethod, ..., pExpire, pMaxAttempts)` | `uuid` | Create outbound request (state=1) |
| `http.request(pId)` | `SETOF http.request` | Get request by ID (read only; the sender reads through `http.take` since 1.2.32) |
| `http.take(pId)` | `SETOF http.request` | The row to send, or none (gone, state 2/3, lifetime elapsed — closed to 3 without callback) |
| `http.sweep(pAge, pLimit)` | `SETOF uuid` | Hand out rows under the resend contract older than `pAge` (attempts + 1, attempted = now()); close spent ones to 3 without callback |
| `http.create_response(pRequest, pStatus, ...)` | `uuid` | Store response, compute runtime, call done() |
| `http.done(pRequest)` | `void` | Set request state=2 (done) |
| `http.fail(pRequest, pError)` | `void` | Set request state=3 (failed) |

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
| `t_request_after_insert` | `http.request` | AFTER INSERT | `pg_notify('http', NEW.id)` — signals C++ to execute request |

## File Manifest

| File | In create | In update | Purpose |
|------|:---------:|:---------:|---------|
| `schema.sql` | yes* | no | CREATE SCHEMA http, GRANT to administrator/daemon/apibot |
| `table.sql` | yes | no | 3 tables + notify trigger |
| `view.sql` | yes | yes | `http.fetch` joined view |
| `routine.sql` | yes | yes | 13 functions (logging, CRUD, take/sweep, get/post, fetch) |
| `create.psql` | - | - | Includes all |
| `update.psql` | - | - | Includes view, routine |
