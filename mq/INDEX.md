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
| `mq.session` | What an exchange carried | `id bigserial PK`, `peer`, `channel`, `link`, `direction` (send/receive), `messages`, `bytes`, `result` (ok/partial/failed) |
| `mq.link` | A kind of link, with the lowest lane priority it admits | `id serial PK`, `code text UNIQUE`, `metered bool`, `threshold 1..3`, `enabled` |
| `mq.schedule` | Session settings on the pair (channel, link) | `id serial PK`, `peer` (NULL = default for every node), `channel`, `link`, `period interval`, `batch int`, `timeout`, `backoff`, `catchup` |

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
| `MQLink` | `mq.link` |
| `MQSchedule` | Schedule rows as stored, with codes |
| `MQPlan` | What happens on every (node, channel, link): whether the lane travels there, which row governs it, when the next session is due, how far behind the node is |

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
| `mq.create_link(pCode, pName, pMetered, pThreshold, pDescription)` | `integer` | Register a kind of link |
| `mq.edit_link(pId, ...)` | `void` | Change one |
| `mq.get_link(pCode)` | `integer` | Resolve a code (NULL when unknown) |

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
| `mq.set_schedule(pChannel, pLink, pPeriod, pBatch, pTimeout, pBackoff, pCatchup, pPeer)` | `integer` | Set the schedule on a pair; a row naming a node overrides the default |
| `mq.delete_schedule(pChannel, pLink, pPeer)` | `boolean` | Remove one |
| `mq.get_schedule(pChannel, pLink, pPeer)` | `(id, period, batch, timeout, backoff, catchup, scope)` | The row in force, and **which** row it is |
| `mq.next_session(pPeer, pChannel, pLink)` | `timestamptz` | When the next sending session is due; **NULL when the lane does not travel over that link at all** |
| `mq.depth(pPeer, pChannel)` | `bigint` | How much that node has not confirmed |
| `mq.session_open(pPeer, pChannel, pDirection, pLink)` | `bigint` | Open a session |
| `mq.session_close(pId, pResult, pMessages, pBytes, pMessage)` | `void` | Close it with its outcome |
| `mq.compact(pChannel)` | `integer` | Keep the last message per key on a compacted channel |
| `mq.purge(pChannel)` | `integer` | Drop what retention no longer requires — never a message a live node has not confirmed |

## API

`api.mq_channel`, `api.mq_peer`, `api.mq_message`, `api.mq_watermark`, `api.mq_dead`,
`api.mq_session`, `api.mq_link`, `api.mq_schedule`, `api.mq_plan` (views); `api.mq_publish`, `api.mq_queue`, `api.mq_accept`, `api.mq_confirm`,
`api.mq_retry`, `api.mq_floor`, `api.mq_advance`, `api.mq_session_open`, `api.mq_session_close`,
`api.mq_compact`, `api.mq_purge`, `api.mq_create_link`, `api.mq_edit_link`, `api.mq_set_schedule`,
`api.mq_delete_schedule`, `api.mq_get_schedule`, `api.mq_next_session`;
`api.list_*` / `api.count_*` for message, dead, session, watermark, schedule and plan.

**The API speaks codes.** Identifiers are local to each database — the same channel is 3 here and 7
there — so anything crossing the boundary as a number would silently mean a different lane on the
far side. `api.mq_channel_id` / `api.mq_peer_id` / `api.mq_link_id` resolve a code and refuse an unknown one rather
than registering it.

## REST

`POST /api/v1/mq/...`: `publish`, `queue`, `floor`, `accept`, `advance`, `confirm`, `retry`, `compact`, `purge`,
`channel/list`, `session/open`, `session/close`, `session/next`, `session/list`, `session/count`,
`message/list`, `message/count`, `dead/list`, `dead/count`, `watermark/list`, `watermark/count`,
`link/create`, `link/edit`, `link/list`, `schedule/set`, `schedule/get`, `schedule/delete`,
`schedule/list`, `schedule/count`, `plan/list`, `plan/count`.

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

## When a session opens — the schedule on the pair

`mq.channel` says what a lane *is*; `mq.link` says what the wire *is*; `mq.schedule` sits on the
pair and says how the lane is carried over that wire. The same ship reaches shore over a metered
satellite terminal at sea and over a berth network in port, and the two are not the same setting
by a different value — they are different rows.

The setting deliberately does **not** live on `mq.channel`, where the design sketch put it. It
belongs to a pair, and a pair fits on one row only as `jsonb` — the free-form configuration this
module exists to get away from.

| Question | Where it is answered |
|---|---|
| Does this lane travel over this link at all? | `mq.link.threshold` — **and only there** |
| How often, how much, how long, how it retries | `mq.schedule` on (channel, link) |
| Does this particular ship differ? | `mq.schedule` row naming the peer; it wins over the default (`peer IS NULL`) |
| What is actually going to happen? | `MQPlan` — one row per (node, channel, link), with `state`, `due` and `depth` |

**One gate, not two.** Whether a lane is carried is decided by the threshold on the link. A
schedule row says *how*, never *whether*. Two mechanisms able to silence the same lane eventually
disagree, and neither raises anything when they do.

`mq.next_session` answers "when next" and is the whole point of the table:

1. lane, link, node or channel out of service, or the lane below the link's threshold → `NULL`;
2. no schedule row → `NULL` (**not** the same answer as the previous one, and `MQPlan.state` keeps
   them apart: `no-schedule` versus `below-threshold`);
3. a session still open → `started + timeout`; past that it is treated as lost;
4. never exchanged → now;
5. consecutive failures → `backoff`, doubled per failure and **capped by the period** — a `partial`
   session counts as progress and clears the count;
6. behind (`mq.depth > 0`) → `catchup`, not `period`. Breaks of twelve hours are ordinary here, so
   catching up is the ordinary path: a ship idle for a month must not need a month to catch up;
7. otherwise → `period`.

**The interval of an evidential lane is a parameter of evidential strength, not of performance.**
The hub anchors the hash of the last link it received *per session*, so the window in which a
truncated tail of the log stays undetectable **equals the time since the last session**. An hour
changed to a day widens that window twenty-four times. The two questions the value answers — how
fresh the far side is, and how large that window is — are not split into two settings because
physically they are one session; so the second one is named in the comment on
`mq.schedule.period`, which is where an administrator meets it, and `MQPlan.evidential` marks the
lanes it applies to. `evidential` is derived (`lifetime IS NULL AND retention IS NULL`), never
declared — a second column saying so could disagree with the first.

`MQPlan` is a cross join of nodes, channels and link kinds with `mq.next_session` called per row,
so its cost grows as their product: a hub with a hundred edges, five channels and three link kinds
builds fifteen hundred rows and asks the session history once for each. That is an administrator's
overview, refreshed by hand — not something a process should poll in a loop. A process asks
`mq.next_session` about the one pair it is working on.

**Changes take effect without a restart.** Every write to `mq.schedule` or `mq.link` sends
`NOTIFY mq_cmd` with what changed, in codes. On a vessel restarting a process is an event;
adjusting an interval must not be one.

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
- **Whether a lane travels is decided in exactly one place** — `mq.link.threshold`. A schedule row
  governs how, never whether.
- **The interval of an evidential lane sets the window of undetectable truncation.** It is not a
  performance knob, and the comment on `mq.schedule.period` says so where the administrator reads
  it.
- **`mq.session.link` is recorded after the event, never stored as "the current link".** What a
  node is reachable over right now is a fact about the world the database cannot verify, and a
  stored copy goes stale in silence.
- **There is no path here that disables triggers.** Reception writes through the ordinary
  `Create<X>`/`api` path; the original identifier can be passed in (`CreateObject` reads
  `object.id` from the session variable), while `owner`, `suid` and the dates are assigned by the
  receiving side no matter what — so a hash preimage must not read them, or the same fact will
  hash differently on the two nodes.
