# mq

> Platform module #20 | Loaded by `create.psql` line 20

Store-and-forward message transport between instances of the same platform: a hub and the edge
nodes that reach it over a link that is expensive, narrow, and interrupted for hours or weeks.

The model is Kafka's — a message is a **fact** in an append-only log, not a task that disappears
when it is read, so a receiver that lost its database can ask for everything again and a sender can
show what it handed over. Routing is RabbitMQ's, because a metered link makes classes of data
unequal and Kafka knows no priorities. The three policy axes (priority, delivery, lifetime) are
MQTT's QoS lesson: they belong to the class of message, not to the system.

**Not a replacement for `replication`.** That module carries *rows* and applies them by dynamic DML
with `DISABLE TRIGGER USER`; this one carries *messages* and applies them through a handler
registered per message type. Both live in the platform; a project picks one.

## Dependencies

| Depends on | Depended by |
|------------|-------------|
| `kernel`, `admin`, `workflow`, `entity`, `api`, `registry` | Deployments that exchange data between instances |

## Schemas Used

| Schema | Usage |
|--------|-------|
| `mq` | Own schema (AUTHORIZATION kernel). 8 tables |
| `kernel` | `MQChannel`, `MQPeer`, `MQBinding`, `MQMessage`, `MQWatermark`, `MQDead`, `MQSession`, `MQIngest` views |
| `api` | API views and wrappers, all speaking **codes** rather than identifiers |
| `rest` | `rest.mq` dispatcher (20 routes) |

## Tables

| Table | Description | Key Columns |
|-------|-------------|-------------|
| `mq.channel` | A lane with an enumerated policy | `id serial PK`, `code text UNIQUE`, `direction` (edge-to-hub/hub-to-edge/both), `priority 1..3`, `delivery` (at-most-once/at-least-once), `lifetime interval`, `compaction bool`, `retention interval`, `serial bigint` (this node's counter) |
| `mq.peer` | Nodes, including this one | `id serial PK`, `code text UNIQUE`, `role` (hub/edge), `local bool` (unique where true), `area uuid`, `key text`, `seen timestamptz` |
| `mq.binding` | Which class publishes where | `id serial PK`, `channel`, `class uuid`, `action uuid`, `type text`, `route text`, `projection jsonb` |
| `mq.message` | The log, both directions | PK(`source`, `channel`, `serial`), `type text`, `route`, `key`, `payload jsonb`, `signature`, `created`, `received`, `expires` |
| `mq.watermark` | Cursor on the pair (node, channel) | PK(`peer`, `channel`), `sent bigint`, `received bigint`, `floor bigint`, `skipped bigint`, `stalled int`, `refused int` |
| `mq.ingest` | Reception registry, one handler per type | `type text PK`, `handler text`, `channel`, `enabled` |
| `mq.dead` | Refused, with the reason | PK(`source`, `channel`, `serial`) → `mq.message`, `reason text`, `attempt int`, `state` (parked/resolved) |
| `mq.session` | What an exchange carried | `id bigserial PK`, `peer`, `channel`, `direction` (send/receive), `messages`, `bytes`, `result` (ok/partial/failed) |

## Views

### kernel schema

| View | Description |
|------|-------------|
| `MQChannel` | `mq.channel` |
| `MQPeer` | `mq.peer` |
| `MQBinding` | Bindings with the channel code |
| `MQMessage` | Messages with node and channel codes, and the dead-letter reason if any |
| `MQWatermark` | Cursors with **queue depth**, the floor, and how many serials were skipped over it |
| `MQDead` | Dead letters joined to the message they refer to |
| `MQSession` | Exchange sessions with codes |
| `MQIngest` | The reception registry |

## Functions

### Configuration

| Function | Returns | Purpose |
|----------|---------|---------|
| `mq.create_channel(pCode, pName, pDirection, pPriority, pDelivery, pLifetime, pCompaction, pRetention, pDescription)` | `integer` | Create a lane; the three axes are stated explicitly |
| `mq.edit_channel(pId, ...)` | `void` | Change one; NULL leaves a value alone |
| `mq.get_channel(pCode)` | `integer` | Resolve a code (NULL when unknown) |
| `mq.create_peer(pCode, pName, pRole, pLocal, pArea, pKey)` | `integer` | Register a node |
| `mq.edit_peer(pId, ...)` | `void` | Change one |
| `mq.get_peer(pCode)` | `integer` | Resolve a code (NULL when unknown) |
| `mq.local_peer()` | `integer` | Which node this database is; **raises** when none is registered |
| `mq.create_binding(pChannel, pClass, pAction, pType, pRoute, pProjection)` | `integer` | Bind a class to a channel |

### Publishing

| Function | Returns | Purpose |
|----------|---------|---------|
| `mq.publish(pChannel, pType, pPayload, pKey, pRoute, pSignature)` | `bigint` | Issue the next serial on the channel and write the message |
| `mq.publish_object(pObject, pAction, pPayload)` | `integer` | Publish through whatever bindings the object's class has |
| `mq.object_payload(pObject, pProjection)` | `jsonb` | Body built from `db.object` by a projection |

### Exchange

| Function | Returns | Purpose |
|----------|---------|---------|
| `mq.queue(pPeer, pChannel, pLimit)` | `SETOF mq.message` | What that node has not confirmed, oldest first, unexpired |
| `mq.floor(pPeer, pChannel, pUpto)` | `(floor, kind)` | Serial below which that node will never be sent anything again, **and the grounds** — `batch` (checkable) or `channel` (not) |
| `mq.confirm(pPeer, pChannel, pSerial, pFloor)` | `void` | Record its confirmation; the cursor never walks backwards. **Refuses a second report in a row from a peer stuck at a gap it cannot cross** — unless the peer says it refused our floor, which means a broken batch rather than a missing step |
| `mq.accept(pSource, pChannel, pSerial, pType, pPayload, pKey, pRoute, pSignature, pCreated)` | `boolean` | Write an incoming message, then apply it. FALSE means parked, not lost |
| `mq.apply(pSource, pChannel, pSerial)` | `text` | Call the registered handler; NULL on success, the reason otherwise |
| `mq.retry(pSource, pChannel, pSerial)` | `boolean` | Try a parked message again, counting the attempt |
| `mq.advance(pSource, pChannel, pFloor, pKind)` | `(received, floor)` | Move the reception cursor over the unbroken run, and over a floor **the receiver could verify** — returning what became of that floor |
| `mq.park(pSource, pChannel, pSerial, pReason)` | `void` | Record a refusal with its reason, and `NOTIFY mq_dead` |

### Reception registry

| Function | Returns | Purpose |
|----------|---------|---------|
| `mq.register_ingest(pType, pHandler, pChannel)` | `void` | Register a handler; **the function must already exist** with signature `(jsonb)` |
| `mq.unregister_ingest(pType)` | `void` | Remove one |

### Sessions and housekeeping

| Function | Returns | Purpose |
|----------|---------|---------|
| `mq.session_open(pPeer, pChannel, pDirection)` | `bigint` | Open a session |
| `mq.session_close(pId, pResult, pMessages, pBytes, pMessage)` | `void` | Close it with its outcome |
| `mq.compact(pChannel)` | `integer` | Keep the last message per key on a compacted channel |
| `mq.purge(pChannel)` | `integer` | Drop what retention no longer requires — never a message a live node has not confirmed |

## API

`api.mq_channel`, `api.mq_peer`, `api.mq_message`, `api.mq_watermark`, `api.mq_dead`,
`api.mq_session` (views); `api.mq_publish`, `api.mq_queue`, `api.mq_accept`, `api.mq_confirm`,
`api.mq_retry`, `api.mq_floor`, `api.mq_advance`, `api.mq_session_open`, `api.mq_session_close`,
`api.mq_compact`, `api.mq_purge`;
`api.list_*` / `api.count_*` for message, dead, session and watermark.

**The API speaks codes.** Identifiers are local to each database — the same channel is 3 here and 7
there — so anything crossing the boundary as a number would silently mean a different lane on the
far side. `api.mq_channel_id` / `api.mq_peer_id` resolve a code and refuse an unknown one rather
than registering it.

## REST

`POST /api/v1/mq/...`: `publish`, `queue`, `floor`, `accept`, `advance`, `confirm`, `retry`, `compact`, `purge`,
`channel/list`, `session/open`, `session/close`, `session/list`, `session/count`, `message/list`,
`message/count`, `dead/list`, `dead/count`, `watermark/list`, `watermark/count`.

Access is the `mq` group, looked up **by code**: the platform's system identifiers and the ones
projects assign share one range with nothing dividing it, and `...-000000000006` is already a group
of a project's own in more than one installation.

## The shape of one session — and why the floor is not optional

```
sender                                               receiver
------                                               --------
mq.queue(peer, channel, limit)   ── messages ───▶    mq.accept(...) for each
mq.floor(peer, channel, upto)    ── floor, kind ─▶   mq.advance(source, channel, floor, kind)
mq.confirm(peer, channel, N, F)  ◀── received, F ────┘
```

**Skip the floor and the exchange deadlocks — silently, and only in the field.** The receiving
cursor moves over an unbroken run, so it stops at the first serial that never arrives. To the
receiver a missing serial looks identical whether it was compacted away, expired while the node
was out of touch, or is still queued for the next window; only the sender can tell. Without the
floor the cursor stops forever, `sent` therefore never moves, and `mq.queue` hands over the whole
tail again **every session** — on a per-megabyte link that is a bill, not an inefficiency. Both
halves of this were found on review of T078, before the module was committed.

`pUpto` is what makes the answer honest: `mq.queue` hands over every deliverable serial in order,
so once a batch ending there has gone, everything at or below it either travelled with the batch
or never will. Called without a batch, `mq.floor` answers about the channel instead.

**A floor is a claim, and the receiver checks it — locally, with nothing added to the wire.** This
is what keeps the mechanism from becoming worse than the problem it solves, because the link this
is built for breaks *in the middle of a batch*, and that is its defining property rather than a
rare case:

| kind | The claim | Honoured when |
|---|---|---|
| `batch` | Everything at or below this serial either travelled in the batch just handed over, or never will | The receiver **holds** that serial. `pUpto` is by construction the last *deliverable* message of the batch, so a session that ran to the end leaves it here — and one that broke halfway does not |
| `channel` | The channel holds nothing at all below this serial any more | There is **nothing above the cursor** to jump over. The receiver owns nothing down there — that is the whole claim — so it can only be honoured where it skips nothing |

Drop the check and a batch of `[1,3,4,6…100]` that lost everything after 4 to a dropped link moves
the cursor to 100: records 6…100 are never asked for again, `confirm` moves `sent` past them, and
they are gone. On this channel "records" means the ship's log. Found on the second review pass of
T078, before the module was committed.

**A session that never declares a floor fails, rather than merely showing up in a table.** It
cannot be caught inside `mq.advance` — that call is the one being skipped — but `mq.confirm` cannot
be skipped by any session, because without it the sender never learns the peer's cursor. The
signature is exact: the peer reports a cursor sitting right below a serial *it cannot cross by
itself* while deliverable messages wait above. Once is a dropped link (`NOTIFY mq_stalled` and a
count); twice in a row on the same pair is refused outright.

**Which is why the fate of the floor travels back** (`mq.advance` returns it, `POST /mq/advance`
carries it, `mq.confirm` takes it as its fourth argument). A refused floor produces the same
symptom as a missing step — a cursor that will not move — but means the opposite thing: the batch
behind the floor did not arrive in full, which on this link is weather rather than a fault. The
decision belongs to the sender and the refusal happens in the receiver's database, so without it
travelling back the guard above would fire on a healthy session and blame the process for skipping
a step it had just performed. Refusals are counted separately in `mq.watermark.refused` and
announced as `NOTIFY mq_refused` **with the serial that was claimed** — "we are at 4, they claimed
10" is a batch that broke, "we are at 4, they claimed 10000" is a sender that is broken, and only
the second one stops being a question about the weather. A refusal also clears `stalled`: it is
proof that the session does declare a floor, since the peer had one to refuse.

**A floor is refused on a channel where nothing may disappear** (no compaction, no lifetime, no
retention). There a declared floor would punch a hole in somebody else's record and leave no trace:
a hash chain breaks on a record removed from what was accepted, not on one that was never accepted.
What a floor does skip is counted in `mq.watermark.skipped`, so a legitimate compaction and a jump
over a hundred records never look alike.

## Invariants worth knowing before touching this

- **The serial is a counter in `mq.channel`, not a sequence.** A sequence leaves gaps when a
  transaction rolls back, and a gap is exactly how the receiving side detects a truncated tail.
- **`received` is moved by the receiver on the fact of acceptance**, never by the sender on the
  fact of sending, and only over an unbroken run. A gap holds it back — so a message that never
  arrived is asked for again; a *parked* message does not — its row is in the log, so it is
  accounted for and visible.
- **A refusal always leaves a row.** Silence plus an optimistic cursor is unrecoverable loss.
- **`mq.purge` never deletes what a live node has not confirmed**, retention or not — and it counts
  nodes that have never synchronised at all, which have no cursor row yet. Those are precisely the
  nodes that need the log from zero. How long a silent node may hold the log is the owner's call
  and is deliberately not decided here.
- **There is no path here that disables triggers.** Reception writes through the ordinary
  `Create<X>`/`api` path; the original identifier can be passed in (`CreateObject` reads
  `object.id` from the session variable), while `owner`, `suid` and the dates are assigned by the
  receiving side no matter what — so a hash preimage must not read them, or the same fact will
  hash differently on the two nodes.
