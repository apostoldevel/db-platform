--------------------------------------------------------------------------------
-- P00000023 -------------------------------------------------------------------
--------------------------------------------------------------------------------
-- mq: a message is addressed. Streams (channel, target), serial per stream.
--
-- Until now a channel had one counter and one log, and mq.queue(peer, channel)
-- handed a node everything this node had published on the lane after that
-- node's cursor. On a hub serving many edge nodes that is one ship's evidence
-- and accounts going to every other ship (ship-safety T163, ИН-09 §2.6, ОБ-14).
-- Filtering at delivery is not a fix: the receiver's cursor moves over an
-- unbroken run of serials, so the numbers filtered out become gaps it waits
-- on for ever — and on an evidential lane no floor may step over them.
--
-- So the serial is now numbered per STREAM — the pair (channel, target),
-- target 0 being "everyone" and otherwise the mq.peer the message is for —
-- and the counters move from mq.channel.serial into mq.stream. A node
-- exchanging a channel has two streams on it (everyone's and its own), each
-- with its own cursor row in mq.watermark, and a session carries them one at
-- a time. Kafka's partition per consumer, with the broadcast log kept as a
-- partition of its own so that a node joining later still reads the current
-- state from zero. Everything without a target means what it meant: the
-- stream to everyone.
--
-- Order matters here and is commented step by step: the primary keys change,
-- and mq.dead points at mq.message's. The functions that gained a trailing
-- parameter are DROPPED by their old signature — CREATE OR REPLACE with a new
-- parameter list creates an overload, and a call with defaults omitted then
-- fails as "not unique" (apostol-csms P00000040, T196). update.psql of this
-- version creates the new ones right after this patch.
--
-- Re-runnable from top to bottom (IF EXISTS / IF NOT EXISTS, constraints
-- dropped by both their names); the data step is guarded by the column it
-- migrates from.
--
-- One reading changes meaning: mq.channel.updated no longer moves on every
-- publication — the counter and its timestamp live in mq.stream now.

-- 1. The counters, one row per stream. Existing counters become the stream
--    to everyone — the only stream there was.

CREATE TABLE IF NOT EXISTS mq.stream (
    channel     integer NOT NULL REFERENCES mq.channel(id) ON DELETE CASCADE,
    target      integer NOT NULL DEFAULT 0,
    serial      bigint NOT NULL DEFAULT 0,
    updated     timestamptz NOT NULL DEFAULT Now(),
    PRIMARY KEY (channel, target)
);

COMMENT ON TABLE mq.stream IS 'Serial counter of THIS node per stream (channel, target). target 0 is the stream to everyone; otherwise the mq.peer the stream is addressed to.';
COMMENT ON COLUMN mq.stream.channel IS 'Channel.';
COMMENT ON COLUMN mq.stream.target IS 'Recipient node (mq.peer.id), or 0 for everyone. No foreign key: 0 is not a peer.';
COMMENT ON COLUMN mq.stream.serial IS 'Last serial issued on this stream by this node. A counter in the row, not a sequence: a rollback takes the number back, so the log has no gaps of its own making.';
COMMENT ON COLUMN mq.stream.updated IS 'When the counter last moved.';

DO $$
BEGIN
  IF EXISTS (SELECT FROM information_schema.columns WHERE table_schema = 'mq' AND table_name = 'channel' AND column_name = 'serial') THEN
    INSERT INTO mq.stream (channel, target, serial)
    SELECT id, 0, serial FROM mq.channel
    ON CONFLICT (channel, target) DO NOTHING;
  END IF;
END
$$;

-- 2. MQChannel keeps its serial column in place, now read from mq.stream —
--    the view is redefined BEFORE the column goes, because a SELECT * view
--    depends on the column and would block the DROP.

CREATE OR REPLACE VIEW MQChannel
AS
  SELECT c.id, c.code, c.name, c.description, c.direction, c.priority, c.delivery,
         c.lifetime, c.compaction, c.retention,
         coalesce((SELECT s.serial FROM mq.stream s WHERE s.channel = c.id AND s.target = 0), 0) AS serial,
         c.enabled, c.created, c.updated
    FROM mq.channel c;

ALTER TABLE mq.channel DROP COLUMN IF EXISTS serial;

-- 3. The log: target joins the primary key. mq.dead's foreign key points at
--    that key, so it goes first and comes back last.

-- Both names of the foreign key: the old one on a base being migrated, the new
-- one on a base where this file ran before — migrate.sh applies a patch
-- statement by statement, and a file that is not re-runnable turns "--init
-- without --baseline, then --migrate" into a base with no primary key on
-- mq.dead.

ALTER TABLE mq.dead DROP CONSTRAINT IF EXISTS dead_source_channel_serial_fkey;
ALTER TABLE mq.dead DROP CONSTRAINT IF EXISTS dead_source_channel_target_serial_fkey;
ALTER TABLE mq.dead DROP CONSTRAINT IF EXISTS dead_pkey;
ALTER TABLE mq.message DROP CONSTRAINT IF EXISTS message_pkey;

ALTER TABLE mq.message ADD COLUMN IF NOT EXISTS target integer NOT NULL DEFAULT 0;
ALTER TABLE mq.message ADD PRIMARY KEY (source, channel, target, serial);

COMMENT ON COLUMN mq.message.target IS 'Node the message is addressed to (mq.peer.id), or 0 for everyone. On the receiving side it is 0 or the local node: a message addressed to somebody else is refused by mq.accept, not filed.';
COMMENT ON COLUMN mq.message.serial IS 'Serial number within the stream (source, channel, target), monotonic and without gaps. Order and gap detection both rest on it — which is why it is a counter in mq.stream and not a sequence.';

DROP INDEX IF EXISTS mq.message_channel_serial_idx;
DROP INDEX IF EXISTS mq.message_channel_key_idx;
CREATE INDEX IF NOT EXISTS message_channel_target_serial_idx ON mq.message (channel, target, serial);
CREATE INDEX IF NOT EXISTS message_channel_target_key_idx ON mq.message (channel, target, key) WHERE key IS NOT NULL;

ALTER TABLE mq.dead ADD COLUMN IF NOT EXISTS target integer NOT NULL DEFAULT 0;
ALTER TABLE mq.dead ADD PRIMARY KEY (source, channel, target, serial);
ALTER TABLE mq.dead ADD FOREIGN KEY (source, channel, target, serial) REFERENCES mq.message(source, channel, target, serial) ON DELETE CASCADE;

COMMENT ON COLUMN mq.dead.target IS 'Stream it arrived on: 0 for everyone, otherwise this node.';

-- 4. The cursor: one row per stream.

ALTER TABLE mq.watermark DROP CONSTRAINT IF EXISTS watermark_pkey;
ALTER TABLE mq.watermark ADD COLUMN IF NOT EXISTS target integer NOT NULL DEFAULT 0;
ALTER TABLE mq.watermark ADD PRIMARY KEY (peer, channel, target);

COMMENT ON TABLE mq.watermark IS 'Exchange cursor for the triple (node, channel, stream). Kept per stream rather than per node so that a slow lane cannot be skipped by another lane''s answer, and per stream rather than per channel because serials are numbered per stream.';
COMMENT ON COLUMN mq.watermark.target IS 'The stream: 0 for the stream to everyone, otherwise the node the stream is addressed to — the other node on the sender, this node on the receiver.';

-- 5. Old signatures out; update.psql brings the new ones.

DROP FUNCTION IF EXISTS mq.publish(integer, text, jsonb, text, text, text);
DROP FUNCTION IF EXISTS mq.publish_object(uuid, uuid, jsonb);
DROP FUNCTION IF EXISTS mq.queue(integer, integer, integer);
DROP FUNCTION IF EXISTS mq.confirm(integer, integer, bigint, text);
DROP FUNCTION IF EXISTS mq.park(integer, integer, bigint, text);
DROP FUNCTION IF EXISTS mq.apply(integer, integer, bigint);
DROP FUNCTION IF EXISTS mq.accept(integer, integer, bigint, text, jsonb, text, text, text, timestamptz);
DROP FUNCTION IF EXISTS mq.retry(integer, integer, bigint);
DROP FUNCTION IF EXISTS mq.floor(integer, integer, bigint);
DROP FUNCTION IF EXISTS mq.advance(integer, integer, bigint, text);

DROP FUNCTION IF EXISTS api.mq_publish(text, text, jsonb, text, text, text);
DROP FUNCTION IF EXISTS api.mq_floor(text, text, bigint);
DROP FUNCTION IF EXISTS api.mq_advance(text, text, bigint, text);
DROP FUNCTION IF EXISTS api.mq_queue(text, text, integer);
DROP FUNCTION IF EXISTS api.mq_accept(text, text, bigint, text, jsonb, text, text, text, timestamptz);
DROP FUNCTION IF EXISTS api.mq_confirm(text, text, bigint, text);
DROP FUNCTION IF EXISTS api.mq_retry(text, text, bigint);
