--------------------------------------------------------------------------------
-- MQ --------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Store-and-forward message transport between two or more instances of the same
-- platform: a hub and the edge nodes that reach it over a link that is expensive,
-- narrow and interrupted for hours or weeks at a time.
--
-- The model is Kafka's, not RabbitMQ's: a message is a FACT in an append-only
-- log, not a TASK that disappears when it is read. A receiver that lost its
-- database must be able to ask for everything again, and a sender must be able
-- to show what it handed over. Routing is taken from RabbitMQ, because a
-- metered link makes classes of data unequal and Kafka knows no priorities at
-- all.
--
-- What this schema deliberately does NOT contain is a path that writes an
-- incoming fact by raw DML with the triggers switched off. Reception goes
-- through the mq.ingest registry: a handler is registered per message type and
-- called by the dispatcher, and it writes through the ordinary Create<X>/api
-- path. The difference from a "disable the triggers and insert" relay is meant
-- to be MECHANICAL rather than a matter of the handler author's discipline —
-- an invariant that rests on discipline is an invariant that rests on nothing.

--------------------------------------------------------------------------------
-- mq.channel ------------------------------------------------------------------
--------------------------------------------------------------------------------

-- A channel is a lane with a policy, and the policy is three ENUMERATED axes:
-- priority, delivery guarantee, lifetime. They are deliberately not free-form
-- settings — a free-form policy is an invariant held by configuration, which is
-- how replication.list came to decide what replicates.
--
-- The identifier is a small integer rather than a uuid, but note what does NOT
-- follow from that: it is LOCAL. What travels between nodes is the channel
-- CODE, and the receiving side maps it to whatever number it uses itself.
-- Numbering agreed across nodes would be a shared invariant with nothing
-- holding it -- create one channel in a different order on the far node and
-- every message afterwards is filed under the wrong lane, silently. Numeric
-- aliases for a metered link belong in the packet header, assigned by the
-- transport per session, not in the database.

CREATE TABLE mq.channel (
    id          serial PRIMARY KEY,
    code        text NOT NULL UNIQUE,
    name        text NOT NULL,
    description text,
    direction   text NOT NULL DEFAULT 'both' CHECK (direction IN ('edge-to-hub', 'hub-to-edge', 'both')),
    priority    integer NOT NULL DEFAULT 2 CHECK (priority BETWEEN 1 AND 3),
    delivery    text NOT NULL DEFAULT 'at-least-once' CHECK (delivery IN ('at-most-once', 'at-least-once')),
    lifetime    interval,
    compaction  boolean NOT NULL DEFAULT false,
    retention   interval,
    serial      bigint NOT NULL DEFAULT 0,
    enabled     boolean NOT NULL DEFAULT true,
    created     timestamptz NOT NULL DEFAULT Now(),
    updated     timestamptz NOT NULL DEFAULT Now()
);

COMMENT ON TABLE mq.channel IS 'Message channel: a lane with an enumerated policy — priority, delivery guarantee, lifetime. Bindings decide what travels on it; peers keep a watermark per channel.';

COMMENT ON COLUMN mq.channel.id IS 'Channel identifier, local to this node. What travels between nodes is the code: numbering agreed across nodes is an invariant nothing holds, and getting it wrong files messages under the wrong lane with no error anywhere.';
COMMENT ON COLUMN mq.channel.code IS 'Channel code, unique and stable — the name used in configuration and in bindings.';
COMMENT ON COLUMN mq.channel.name IS 'Human-readable channel name.';
COMMENT ON COLUMN mq.channel.description IS 'What travels on this channel and why it is separate from the others.';
COMMENT ON COLUMN mq.channel.direction IS 'Which way messages flow, named by absolute poles rather than "in"/"out": the same row exists on both nodes, and a relative direction would read backwards on one of them.';
COMMENT ON COLUMN mq.channel.priority IS 'Lane priority 1..3. A narrow link carries the low numbers first, and may be configured to carry nothing else.';
COMMENT ON COLUMN mq.channel.delivery IS 'Delivery guarantee: at-most-once (may be lost, never repeated) or at-least-once (repeated until confirmed, de-duplicated by the primary key of mq.message).';
COMMENT ON COLUMN mq.channel.lifetime IS 'How long a message stays worth delivering. NULL means it never expires — the correct value for anything evidential; a duration is right for telemetry, which nobody wants a week late.';
COMMENT ON COLUMN mq.channel.compaction IS 'Keep only the last message per key. Turns the channel into a snapshot: a node joining for the first time reads it from zero and arrives at the current state without replaying every revision.';
COMMENT ON COLUMN mq.channel.retention IS 'How long delivered messages are kept in the log. NULL means forever, which is what an evidential channel needs.';
COMMENT ON COLUMN mq.channel.serial IS 'Counter of the last serial issued on this channel by THIS node. Kept in the row rather than in a sequence on purpose: a sequence leaves gaps when a transaction rolls back, and the receiving side checks for gaps to detect a truncated tail.';
COMMENT ON COLUMN mq.channel.enabled IS 'Whether the channel is in service.';
COMMENT ON COLUMN mq.channel.created IS 'When the channel was created.';
COMMENT ON COLUMN mq.channel.updated IS 'When the channel was last changed.';

CREATE INDEX ON mq.channel (priority);

--------------------------------------------------------------------------------
-- mq.peer ---------------------------------------------------------------------
--------------------------------------------------------------------------------

-- The other end, and ourselves: exactly one row carries local = true.
--
-- The platform had no notion of "which instance am I" — replication is told its
-- source by the process that calls it, which means the database cannot tell its
-- own messages from someone else's without being informed every time. Here the
-- node knows itself, because the publishing side has to stamp a source into
-- every message it writes.

CREATE TABLE mq.peer (
    id          serial PRIMARY KEY,
    code        text NOT NULL UNIQUE,
    name        text NOT NULL,
    role        text NOT NULL CHECK (role IN ('hub', 'edge')),
    local       boolean NOT NULL DEFAULT false,
    area        uuid REFERENCES db.area(id),
    key         text,
    enabled     boolean NOT NULL DEFAULT true,
    created     timestamptz NOT NULL DEFAULT Now(),
    updated     timestamptz NOT NULL DEFAULT Now(),
    seen        timestamptz
);

COMMENT ON TABLE mq.peer IS 'A node of the exchange: the local instance (local = true, exactly one row) and every remote instance it exchanges messages with.';

COMMENT ON COLUMN mq.peer.id IS 'Node identifier, local to this node -- as with the channel, what travels between nodes is the code.';
COMMENT ON COLUMN mq.peer.code IS 'Node code, unique and stable.';
COMMENT ON COLUMN mq.peer.name IS 'Human-readable node name.';
COMMENT ON COLUMN mq.peer.role IS 'hub — the centre every edge reaches; edge — a node that reaches the hub and not its siblings.';
COMMENT ON COLUMN mq.peer.local IS 'Whether this row is the instance the database belongs to. Exactly one row may carry it, enforced by a unique index.';
COMMENT ON COLUMN mq.peer.area IS 'Area an incoming fact from this node is written into. Not decoration: db.ft_object_before_insert refuses an object whose scope does not match the session area, so a receiver that does not move into the right area either fails outright or writes into the wrong one.';
COMMENT ON COLUMN mq.peer.key IS 'Public key that verifies this node''s packet signature. Separate from the key that signs the records themselves: one proves who wrote a record, the other proves who sent a packet, and merging them would let a node sign records.';
COMMENT ON COLUMN mq.peer.enabled IS 'Whether exchange with this node is in service.';
COMMENT ON COLUMN mq.peer.created IS 'When the node was registered.';
COMMENT ON COLUMN mq.peer.updated IS 'When the node was last changed.';
COMMENT ON COLUMN mq.peer.seen IS 'When this node was last heard from. The observability answer to "the ship went off the air" without polling for it.';

CREATE UNIQUE INDEX ON mq.peer (local) WHERE local;

--------------------------------------------------------------------------------
-- mq.binding ------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Publisher side. An entity's workflow event calls mq.publish_object(); which
-- channel that lands on, and under which message type, is decided here — so
-- adding an entity to the exchange does not touch the transport, and removing
-- one is a deleted row rather than an edit to a publishing function.

CREATE TABLE mq.binding (
    id          serial PRIMARY KEY,
    channel     integer NOT NULL REFERENCES mq.channel(id) ON DELETE CASCADE,
    class       uuid NOT NULL REFERENCES db.class_tree(id),
    action      uuid REFERENCES db.action(id),
    type        text NOT NULL,
    route       text NOT NULL,
    projection  jsonb,
    enabled     boolean NOT NULL DEFAULT true,
    created     timestamptz NOT NULL DEFAULT Now(),
    updated     timestamptz NOT NULL DEFAULT Now(),
    UNIQUE (class, action, channel)
);

COMMENT ON TABLE mq.binding IS 'Binding: which channel an entity class publishes to, under which message type, and which of its fields travel.';

COMMENT ON COLUMN mq.binding.id IS 'Binding identifier.';
COMMENT ON COLUMN mq.binding.channel IS 'Channel the message is written to.';
COMMENT ON COLUMN mq.binding.class IS 'Entity class this binding publishes.';
COMMENT ON COLUMN mq.binding.action IS 'Action that publishes. NULL binds every action of the class.';
COMMENT ON COLUMN mq.binding.type IS 'Message type: the name the receiving side looks up in mq.ingest. Text, not a uuid — the two nodes must agree on it, and identifiers generated per installation would not.';
COMMENT ON COLUMN mq.binding.route IS 'Routing key, hierarchical and dot-separated in the MQTT manner, e.g. "node.9123456.journal.bridge".';
COMMENT ON COLUMN mq.binding.projection IS 'Which fields of the entity travel, as a JSON array of names. NULL means the publisher decides — appropriate where the payload is assembled by the entity''s own function rather than copied field by field.';
COMMENT ON COLUMN mq.binding.enabled IS 'Whether the binding is in service.';
COMMENT ON COLUMN mq.binding.created IS 'When the binding was created.';
COMMENT ON COLUMN mq.binding.updated IS 'When the binding was last changed.';

CREATE INDEX ON mq.binding (channel);
CREATE INDEX ON mq.binding (class);

--------------------------------------------------------------------------------
-- mq.message ------------------------------------------------------------------
--------------------------------------------------------------------------------

-- The log, and both directions live in it: messages this node published (source
-- = the local peer) and messages it received (source = whoever sent them). One
-- table, because the primary key already separates them and because a receiver
-- that has to prove what it accepted needs the incoming half kept exactly as
-- the outgoing half is.
--
-- (source, channel, serial) as the primary key IS the idempotency: a repeat
-- delivery conflicts and changes nothing, which is what makes "at least once"
-- safe to build on.

CREATE TABLE mq.message (
    source      integer NOT NULL REFERENCES mq.peer(id),
    channel     integer NOT NULL REFERENCES mq.channel(id),
    serial      bigint NOT NULL,
    type        text NOT NULL,
    route       text,
    key         text,
    payload     jsonb NOT NULL,
    signature   text,
    created     timestamptz NOT NULL DEFAULT Now(),
    received    timestamptz,
    expires     timestamptz,
    PRIMARY KEY (source, channel, serial)
);

COMMENT ON TABLE mq.message IS 'Message log of every channel, both directions. Append-only: a message is not deleted when it is read, only when retention or compaction removes it.';

COMMENT ON COLUMN mq.message.source IS 'Node that published the message. Equal to the local peer for everything this node produced.';
COMMENT ON COLUMN mq.message.channel IS 'Channel the message belongs to.';
COMMENT ON COLUMN mq.message.serial IS 'Serial number within (source, channel), monotonic and without gaps. Order and gap detection both rest on it — which is why it is a counter in mq.channel and not a sequence.';
COMMENT ON COLUMN mq.message.type IS 'Message type. The receiving side looks up its ingest handler by this name.';
COMMENT ON COLUMN mq.message.route IS 'Routing key the message was published with.';
COMMENT ON COLUMN mq.message.key IS 'Compaction key. On a compacted channel only the last message per key survives; NULL keeps the message out of compaction altogether.';
COMMENT ON COLUMN mq.message.payload IS 'Message body.';
COMMENT ON COLUMN mq.message.signature IS 'Signature of the sending node over the message. Verified on arrival against mq.peer.key; the transport does not take part in it, so changing the transport does not touch the proof.';
COMMENT ON COLUMN mq.message.created IS 'When the message was published, by the publisher''s clock.';
COMMENT ON COLUMN mq.message.received IS 'When the message arrived here. NULL for messages this node published itself.';
COMMENT ON COLUMN mq.message.expires IS 'When the message stops being worth delivering, computed from the channel lifetime at publication. NULL never expires.';

CREATE INDEX ON mq.message (channel, serial);
CREATE INDEX ON mq.message (channel, key) WHERE key IS NOT NULL;
CREATE INDEX ON mq.message (expires) WHERE expires IS NOT NULL;

--------------------------------------------------------------------------------

/**
 * @brief Notify listeners that a message was published locally.
 * @return {trigger}
 * @since 1.2.17
 */
CREATE OR REPLACE FUNCTION mq.ft_message_after_insert()
RETURNS trigger AS $$
BEGIN
  IF NEW.received IS NULL THEN
    PERFORM pg_notify('mq', json_build_object('channel', NEW.channel, 'serial', NEW.serial, 'type', NEW.type)::text);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

-- Only outgoing messages notify. An incoming one has already been carried here
-- by the process that would be woken by the notification, and waking it to tell
-- it what it just did is how a session loop starts feeding itself.

CREATE TRIGGER t_mq_message_after_insert
  AFTER INSERT ON mq.message
  FOR EACH ROW
  EXECUTE PROCEDURE mq.ft_message_after_insert();

--------------------------------------------------------------------------------
-- mq.watermark ----------------------------------------------------------------
--------------------------------------------------------------------------------

-- The cursor, and it lives on the pair (peer, channel) — not on the peer.
--
-- One cursor covering several classes of data is a modelling error, not an
-- arithmetic one: a slow lane gets skipped by another lane's answer, and the
-- messages it skipped are never asked for again. Taking max() over the answers
-- repairs the arithmetic and leaves the model broken.
--
-- The other half of the rule is who moves it: RECEIVED is moved by the receiver
-- on the fact of acceptance, never by the sender on the fact of sending. A
-- message that did not apply must not be stepped over because the peer said it
-- had scanned that far.

CREATE TABLE mq.watermark (
    peer        integer NOT NULL REFERENCES mq.peer(id) ON DELETE CASCADE,
    channel     integer NOT NULL REFERENCES mq.channel(id) ON DELETE CASCADE,
    sent        bigint NOT NULL DEFAULT 0,
    received    bigint NOT NULL DEFAULT 0,
    floor       bigint NOT NULL DEFAULT 0,
    skipped     bigint NOT NULL DEFAULT 0,
    stalled     integer NOT NULL DEFAULT 0,
    refused     integer NOT NULL DEFAULT 0,
    updated     timestamptz NOT NULL DEFAULT Now(),
    PRIMARY KEY (peer, channel)
);

COMMENT ON TABLE mq.watermark IS 'Exchange cursor for the pair (node, channel). Kept per pair rather than per node so that a slow lane cannot be skipped by another lane''s answer.';

COMMENT ON COLUMN mq.watermark.peer IS 'The other node.';
COMMENT ON COLUMN mq.watermark.channel IS 'The channel this cursor belongs to.';
COMMENT ON COLUMN mq.watermark.sent IS 'Our serial up to which THAT node has confirmed reception. Moved by its report, which is its own received — never by the act of sending.';
COMMENT ON COLUMN mq.watermark.received IS 'That node''s serial up to which WE have accepted without a gap. Moved by the receiver on the fact of acceptance; a gap holds it back, so the missing message is asked for again at the next session.';
COMMENT ON COLUMN mq.watermark.floor IS 'Lowest serial the sender declared as never deliverable — compacted away or expired. Without it the rule above becomes a trap: the first compaction removes serial 1, the cursor of a node starting at zero waits for it forever, and every session re-sends the whole tail on a metered link.';
COMMENT ON COLUMN mq.watermark.skipped IS 'How many serials the cursor passed over on a floor without their message ever arriving. A floor is a claim that something no longer exists, so it leaves a count rather than nothing: a silent jump over a hundred records and a legitimate compaction would otherwise look identical.';
COMMENT ON COLUMN mq.watermark.stalled IS 'How many confirmations in a row reported a cursor stuck at a gap the receiver cannot cross by itself. One is a broken session; two in a row is a session that never sends the floor at all, and mq.confirm refuses it rather than letting the exchange re-send the same tail forever.';
COMMENT ON COLUMN mq.watermark.refused IS 'How many times a floor on this pair was refused because the batch behind it never arrived in full. On the receiving side it counts what this node refused; on the sending side, what the peer reported refusing. A refusal means the previous session broke in the middle — which on this link is ordinary weather, not a fault, and must never be confused with a session that omits the floor step altogether: the two look alike and are fixed in opposite places.';
COMMENT ON COLUMN mq.watermark.updated IS 'When the cursor last moved.';

--------------------------------------------------------------------------------
-- mq.ingest -------------------------------------------------------------------
--------------------------------------------------------------------------------

-- The reception contract: one handler per message type, and no general "apply".
--
-- Applying an incoming journal record through the ordinary api.<entity>_add
-- would create a NEW record with a new identifier, a new time and a new hash —
-- an incoming record is somebody else's fact and has to be accepted as one.
-- What the platform does allow is passing the identifier in
-- (CreateObject reads object.id from the session variable), so a handler writes
-- through the ordinary path WITH the original identifier rather than around it.
--
-- The service fields — owner, suid, pdate — are assigned by the trigger no
-- matter what, so the original author and time have to live in the entity's own
-- fields. A hash preimage that reaches into db.object therefore cannot match
-- between the two nodes, and that is a requirement on every class that travels,
-- not a detail of this table.

CREATE TABLE mq.ingest (
    type        text PRIMARY KEY,
    handler     text NOT NULL,
    channel     integer REFERENCES mq.channel(id) ON DELETE CASCADE,
    enabled     boolean NOT NULL DEFAULT true,
    created     timestamptz NOT NULL DEFAULT Now(),
    updated     timestamptz NOT NULL DEFAULT Now()
);

COMMENT ON TABLE mq.ingest IS 'Registry of reception handlers, one per message type. A message whose type has no handler is parked in mq.dead — it is never applied by a general fallback, and never silently dropped.';

COMMENT ON COLUMN mq.ingest.type IS 'Message type this handler accepts.';
COMMENT ON COLUMN mq.ingest.handler IS 'Name of the function called with the message. Checked to exist when it is registered, so a typo fails at registration rather than at the first arrival.';
COMMENT ON COLUMN mq.ingest.channel IS 'Channel this type is expected on. NULL accepts the type on any channel; a value refuses it elsewhere, which keeps a lane from being used to smuggle a class it was not opened for.';
COMMENT ON COLUMN mq.ingest.enabled IS 'Whether the handler is in service. A disabled handler parks arrivals in mq.dead rather than dropping them, so nothing is lost while it is off.';
COMMENT ON COLUMN mq.ingest.created IS 'When the handler was registered.';
COMMENT ON COLUMN mq.ingest.updated IS 'When the registration was last changed.';

--------------------------------------------------------------------------------
-- mq.dead ---------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Dead letters. One unusable message has no right to stop a channel: on a ship
-- that would mean the log stops reaching the shore because of a single bad row.
-- It is parked here WITH ITS REASON, an alarm is raised, and the channel goes
-- on.
--
-- The row in mq.message stays. That is what allows the watermark to move past a
-- parked message without the message being lost: the absence of a serial in
-- mq.message means "not delivered, ask again", while a parked one means
-- "delivered, refused, visible here".

CREATE TABLE mq.dead (
    source      integer NOT NULL,
    channel     integer NOT NULL,
    serial      bigint NOT NULL,
    reason      text NOT NULL,
    attempt     integer NOT NULL DEFAULT 1,
    state       text NOT NULL DEFAULT 'parked' CHECK (state IN ('parked', 'resolved')),
    created     timestamptz NOT NULL DEFAULT Now(),
    updated     timestamptz NOT NULL DEFAULT Now(),
    PRIMARY KEY (source, channel, serial),
    FOREIGN KEY (source, channel, serial) REFERENCES mq.message(source, channel, serial) ON DELETE CASCADE
);

COMMENT ON TABLE mq.dead IS 'Messages that arrived and were refused, with the reason and the number of attempts. Parking one keeps the channel moving; the message itself stays in mq.message.';

COMMENT ON COLUMN mq.dead.source IS 'Node that published the refused message.';
COMMENT ON COLUMN mq.dead.channel IS 'Channel it arrived on.';
COMMENT ON COLUMN mq.dead.serial IS 'Serial of the refused message.';
COMMENT ON COLUMN mq.dead.reason IS 'Why it was refused, in the words of the handler that refused it. A refusal with no reason recorded is the failure mode this table exists to prevent.';
COMMENT ON COLUMN mq.dead.attempt IS 'How many times acceptance has been attempted.';
COMMENT ON COLUMN mq.dead.state IS 'parked — awaiting a decision; resolved — dealt with, by a retry that succeeded or by a person.';
COMMENT ON COLUMN mq.dead.created IS 'When it was first parked.';
COMMENT ON COLUMN mq.dead.updated IS 'When it was last retried or resolved.';

CREATE INDEX ON mq.dead (state);

--------------------------------------------------------------------------------
-- mq.session ------------------------------------------------------------------
--------------------------------------------------------------------------------

-- An exchange session: one channel, one direction, one round trip. Kept because
-- queue depth and the age of the last session are what "is the exchange
-- healthy" actually means — and, for an evidential channel, because the window
-- in which a truncated tail stays undetectable is exactly the time since the
-- last session.

CREATE TABLE mq.session (
    id          bigserial PRIMARY KEY,
    peer        integer NOT NULL REFERENCES mq.peer(id) ON DELETE CASCADE,
    channel     integer NOT NULL REFERENCES mq.channel(id) ON DELETE CASCADE,
    direction   text NOT NULL CHECK (direction IN ('send', 'receive')),
    started     timestamptz NOT NULL DEFAULT Now(),
    finished    timestamptz,
    messages    integer NOT NULL DEFAULT 0,
    bytes       bigint NOT NULL DEFAULT 0,
    result      text CHECK (result IN ('ok', 'partial', 'failed')),
    message     text
);

COMMENT ON TABLE mq.session IS 'Exchange session: what was carried over one channel in one direction, when, how much of it, and how it ended.';

COMMENT ON COLUMN mq.session.id IS 'Session identifier.';
COMMENT ON COLUMN mq.session.peer IS 'The node on the other end.';
COMMENT ON COLUMN mq.session.channel IS 'Channel exchanged.';
COMMENT ON COLUMN mq.session.direction IS 'send — we handed messages over; receive — we took them.';
COMMENT ON COLUMN mq.session.started IS 'When the session opened.';
COMMENT ON COLUMN mq.session.finished IS 'When it closed. NULL while it is still open — and a session left open long past its timeout is itself a symptom.';
COMMENT ON COLUMN mq.session.messages IS 'How many messages were carried.';
COMMENT ON COLUMN mq.session.bytes IS 'How many bytes went over the link. Kept because the link is metered and the bill is a real constraint on how the exchange is configured.';
COMMENT ON COLUMN mq.session.result IS 'ok — everything carried; partial — some of it; failed — nothing.';
COMMENT ON COLUMN mq.session.message IS 'Error or explanation for a session that did not end ok.';

CREATE INDEX ON mq.session (peer, channel);
CREATE INDEX ON mq.session (started);
