# notify

> Platform module #29 | Loaded by `create.psql` line 12 (after `api`, before the first trigger that calls `notify.send`)

The delivery policy of every `pg_notify` channel. `pg_notify` is a broadcast: every instance listening on a channel does the same work once. This module turns the channels that carry **work** (an outbound HTTP call, a mail, a report, a job, a command to a station) into rows handed to exactly one live subscriber, taken under a token and confirmed with the same token in the same transaction as the result; a late confirmation under an old token is refused together with the result it carries. What a channel does is decided by `notify.channel`, not by the producer: the producer calls `notify.send` in place of `pg_notify` and does not know the mode. Nothing here is a result store — a row of `notify.queue` is the trace of the **delivery**.

Every channel is `legacy` after an install or the patch: `notify.send` of a `legacy` channel is exactly `pg_notify(channel, data)`, so a binary that knows nothing of the module and one that does can share a database (N−1, T953). A channel is switched to `single` per installation, by the owner's word, when every instance listening on it is new.

## Dependencies

| Depends on | Depended by |
|------------|-------------|
| `kernel`, `registry` and `api` (route registration in `init.sql`) | every module with a trigger or a routine that notifies: `http`, `log`, `file`, `gateway`, `mq`, `notice`, `notification`, `replication`, `entity`/`message`, and the configuration |

## Schemas Used

| Schema | Usage |
|--------|-------|
| `notify` | Own schema (AUTHORIZATION kernel). 3 tables, 1 sequence, 21 functions; the views `Notify*` are in the default (`kernel`) namespace, `api.notify_*` in `api`. `USAGE` for `administrator`, `daemon`, `apibot`; a configuration grants it to its own service roles (not done yet: T590 step 2). Functions: **no `PUBLIC` execute**; the interface is granted to `daemon` and `apibot` only, the internals to nobody |

There is **no application group** `notify` on purpose: no function asks about a group; who may call is the `USAGE` on the schema, and the `/notify/...` routes are the administrator's.

## Tables

| Table | Description | Key Columns |
|-------|-------------|-------------|
| `notify.channel` | Policy per channel | `code text PK`, `mode` (`broadcast`/`single`/`legacy`), `affinity` (`any`/`key`/`route`), `target_fn`, `grace`, `lease`, `expire`, `max_attempts`, `resend_enabled`, `on_abandon`, `on_expire`, `dedupe`, `retain_done`, `retain_closed`, `alive`, `sweep_every`, `classified` |
| `notify.queue` | A row per unit of work of a `single` channel | `id bigint PK`, `channel`, `payload`, `key`, `target` (addressee), `state` (0 waiting, 1 taken, 2 confirmed, 3 closed), `owner`, `token`, `lease_until`, `seen`, `attempts`, `error` |
| `notify.subscriber` | Live listeners | `id integer PK` (names the personal channel `<channel>:<id>`), `node`, `application`, `role`, `channel`, `state` (`active`/`draining`), `backend_pid`, `seen` |

`notify.token` is the sequence of take tokens. Trigger `t_channel_check` (`BEFORE INSERT OR UPDATE OF target_fn, on_abandon`) refuses a `target_fn` that is not a function `(text) RETURNS integer` and an `on_abandon` that is not `(bigint, text, text, text)` — a misspelt name would otherwise read as "no holder" for every row of the channel, silently. A function must exist **before** the channel row that names it.

## Views

| View | Source | Grants |
|------|--------|--------|
| `NotifyChannel`, `NotifySubscriber` | the tables | `administrator` |
| `NotifyQueue` | `notify.queue` **without `payload`** (a payload may carry a driver's data or a command) | `administrator` |
| `api.notify_channel`, `api.notify_subscriber`, `api.notify_queue` | the views above | `administrator`, `apibot` |

## Functions

All `SECURITY DEFINER`, `search_path = kernel, pg_temp`; they are **not** in `kernel` on purpose (the token check must not sit where a project redefines platform functions). Time is `clock_timestamp()`.

### The interface (frozen at G1, T1100)

| Function | Returns | Purpose |
|----------|---------|---------|
| `notify.send(pChannel, pPayload, pKey, pExpire, pMaxAttempts)` | `bigint` | The replacement of `pg_notify` at every producer. Raises nothing of its own (what `pg_notify` refuses — an empty or over-long channel, a payload over 8000 bytes — it refuses as before). `legacy`/`broadcast`/unknown channel: `pg_notify`, returns NULL (an unknown channel is recorded `classified = false`). `single`: a row, an addressee, a wake-up; the existing row for a duplicate of a `dedupe` channel |
| `notify.subscribe(pNode, pChannel, pApplication, pRole, pPid)` | `integer` | Register a listener; the number names its personal channel |
| `notify.heartbeat(pId, pPid)` | `text` | `active`/`draining`, or NULL when the number was purged: subscribe again |
| `notify.drain(pId)` / `notify.unsubscribe(pId)` | `void` | Stop being chosen / leave (a number rows still refer to stays `draining` until the sweep) |
| `notify.take(pId, pSubscriber)` | `(payload, key, token, attempts)` | The subscriber's reaction to a wake-up or a sweep; no row when the row is not its to work on. Takes a row in **any** mode |
| `notify.ack(pId, pToken)` / `notify.nack(pId, pToken, pError)` | `void` | Confirm / refuse under the current token; SQLSTATE `NT409` when it is not current. Call in the SAME transaction that writes the result |
| `notify.sweep(pSubscriber, pLimit)` | `integer` | The look-over a subscriber makes on a timer and after a reconnect: `sweep_channel` of its channel |
| `notify.sweep_channel(pChannel, pLimit)` | `integer` | The look-over itself, also for a channel nobody listens on (closes the expired / unrouted / orphaned and calls `on_abandon`) |
| `api.sweep_notify_channel(pCode, pLimit)` | `integer` | The same, for a job |
| `notify.retarget(pChannel, pKey)` | `integer` | Recompute the addressee of the waiting rows of a key and wake the new one (a configuration calls it when `target_fn(key)` changed) |
| `notify.channel_policy(pChannel)` | `(mode, classified, affinity, alive, sweep_every, lease)` | What a subscriber needs of its channel's policy; the worker pool has no right on the table |

Wake-up format: **only** the personal channel `"<channel>:<number>"`, payload = the row id. The common channel `"<channel>"` is never written by the module — it carries the producers' data (`legacy`, `broadcast`). Reasons of a closed row: `unsent:` (never handed out), `unrouted:` (no holder), `orphaned:` (outcome unknown), `nack:`; `on_abandon(id, key, payload, reason)`; for a never-sent row only when the channel says `on_expire`. **The mode decides `send` alone**: `take`, `ack`, `nack`, the sweep bring existing rows to their end whatever the mode is now, so a channel returned to `legacy` under load drains.

### Internal

`wake`, `is_alive`, `route_holder` (the raw answer of `target_fn`), `route_target` (the holder if it is alive), `pick_target`, `can_repeat`, `wake_next`, `close`. A route holder silent longer than the channel's `alive` is "no holder".

### REST (administrator)

`/notify/channel/list|get|set`, `/notify/subscriber/list|count`, `/notify/queue/list|count`. `target_fn` and `on_abandon` are not settable over REST (they run with the module's rights): they are written by the module's own scripts.

## Channels of the platform

`init.sql` registers 20 channels, all `legacy` (the description says what each is meant to become): `http`, `outbox`, `report`, `job`, `file`, `replication`, `mq` (work — candidates for `single`); `log`, `geo`, `notify`, `inbox`, `notice`, `message`, `gateway`, `gateway_cmd` (broadcast to WebSocket servers / workers); `mq_cmd`, `mq_stalled`, `mq_dead`, `mq_refused`, `mq_floor` (to be inventoried). A configuration registers its own in its `notify/init.sql` and patch.

## Delivery to existing bases

`patch/v1.2/P00000035.sql` creates the module (skipped when the schema is already there) and replaces the 12 trigger functions of `table.sql` that `update.psql` never re-runs (self-contained snapshot of their bodies). Rule for a new producer: `notify.send('<literal channel>', ...)` and a row in `notify.channel`; a direct `pg_notify` outside this module is red in `db/tests/notify/test-t1100-convention.sh`.

## Tests

`db/tests/notify/`: `test-t1100-notify-module.sql` (checks and mutants in one rolled-back transaction), `test-t1100-wake.sh` (a live `LISTEN`: nothing numeric on the common channel), `test-t1100-convention.sh` (the conventions, on the sources and on a base — run it on a base reached by the patch path too).
