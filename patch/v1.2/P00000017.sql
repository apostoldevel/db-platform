--------------------------------------------------------------------------------
-- mq: session schedule on the pair (channel, link) -----------------------------
--------------------------------------------------------------------------------

-- The exchange schedule -- how often a session opens, how much it carries, how
-- long it may take, how it backs off after a failure and how it catches up --
-- could not live on the mq.channel row where the design sketch put it. It
-- belongs to a PAIR (channel, kind of link), and a pair fits on a single row
-- only as jsonb, which is the free-form configuration this module exists to get
-- away from.
--
-- What arrives: mq.link (the kinds of link, each with the lowest lane priority
-- it admits), mq.schedule (the settings on the pair, optionally narrowed to one
-- node), a link column on mq.session, and two triggers that notify mq_cmd so a
-- running process picks the change up without a restart.
--
-- The DDL below is a copy of the corresponding block of mq/table.sql, and that
-- is deliberate where P00000016 included the module instead: including
-- mq/create.psql here would rebuild the whole schema, not extend it. The copy
-- was taken from the file mechanically, and the guard below makes re-running
-- this patch a no-op rather than a half-applied mess.

SELECT NOT EXISTS (
  SELECT FROM information_schema.tables WHERE table_schema = 'mq' AND table_name = 'link'
) AS link_absent \gset

\if :link_absent

--------------------------------------------------------------------------------
-- mq.link ---------------------------------------------------------------------
--------------------------------------------------------------------------------

-- The kind of link a session runs over: a satellite terminal, a berth network,
-- a cable. The same pair of nodes exchanges over different kinds at different
-- times, and what an exchange COSTS differs between them by orders of magnitude
-- -- a metered satellite link is billed by the megabyte, a berth network is not.
-- That is why the schedule cannot be a property of the channel alone.
--
-- This is a table rather than a CHECK list, unlike the three axes of a channel,
-- and the difference is who owns the value. The axes of a channel are a POLICY
-- the platform itself reasons about -- what may be dropped, what may be
-- repeated, what may expire -- so a free-form policy would be an invariant held
-- by configuration. A kind of link is a fact about the world the installation
-- lives in: a fleet takes on a new carrier and the administrator names it.
-- Enumerating those in the platform would mean a release to add "5G in port".

CREATE TABLE mq.link (
    id          serial PRIMARY KEY,
    code        text NOT NULL UNIQUE,
    name        text NOT NULL,
    description text,
    metered     boolean NOT NULL DEFAULT false,
    threshold   integer NOT NULL DEFAULT 3 CHECK (threshold BETWEEN 1 AND 3),
    enabled     boolean NOT NULL DEFAULT true,
    created     timestamptz NOT NULL DEFAULT Now(),
    updated     timestamptz NOT NULL DEFAULT Now()
);

COMMENT ON TABLE mq.link IS 'A kind of link a session runs over. The schedule is set on the pair (channel, link): the same lane is carried differently over a metered satellite link and over a berth network.';

COMMENT ON COLUMN mq.link.id IS 'Link identifier, local to this node -- as with the channel and the peer, what travels between nodes is the code.';
COMMENT ON COLUMN mq.link.code IS 'Link code, unique and stable -- the name used in configuration and by the process reporting what it is connected over.';
COMMENT ON COLUMN mq.link.name IS 'Human-readable link name.';
COMMENT ON COLUMN mq.link.description IS 'What this kind of link is and what it costs.';
COMMENT ON COLUMN mq.link.metered IS 'Whether traffic is billed by volume. Not decoration: it is the reason a lane may be excluded here and carried freely in port, and it belongs next to the threshold that acts on it.';
COMMENT ON COLUMN mq.link.threshold IS 'The lowest lane priority this link admits: a channel travels here when its priority is at or above the threshold in importance (channel.priority <= threshold). This lives on the LINK and not on the schedule row on purpose -- it answers "how narrow is this link", not "how is this lane carried". On the pair it would give two mechanisms the power to silence a lane, and two mechanisms deciding the same thing eventually disagree without raising anything.';
COMMENT ON COLUMN mq.link.enabled IS 'Whether this kind of link is in service.';
COMMENT ON COLUMN mq.link.created IS 'When the link kind was registered.';
COMMENT ON COLUMN mq.link.updated IS 'When it was last changed.';

--------------------------------------------------------------------------------
-- mq.schedule -----------------------------------------------------------------
--------------------------------------------------------------------------------

-- When a session opens, how much it carries, how long it may take and how it
-- backs off after a failure -- per (channel, link), optionally per node.
--
-- The setting could NOT live on the channel row where the design sketch put it.
-- It belongs to a pair, and a pair fits on a single row only as jsonb -- which
-- is exactly the free-form configuration this module exists to get away from.
--
-- peer IS NULL is the default for every node; a row naming a peer overrides it.
-- The override is not an extra: tariffs differ per vessel, so "this setting is
-- per ship, not per fleet" was the first thing said about it.
--
-- There is no cap on the backoff, because the schedule already is one: the
-- backoff grows until it reaches the period, and waiting longer than the
-- ordinary interval buys nothing that the ordinary interval does not.

CREATE TABLE mq.schedule (
    id          serial PRIMARY KEY,
    peer        integer REFERENCES mq.peer(id) ON DELETE CASCADE,
    channel     integer NOT NULL REFERENCES mq.channel(id) ON DELETE CASCADE,
    link        integer NOT NULL REFERENCES mq.link(id) ON DELETE CASCADE,
    period      interval NOT NULL CHECK (period > interval '0'),
    batch       integer NOT NULL DEFAULT 100 CHECK (batch > 0),
    timeout     interval NOT NULL DEFAULT interval '5 minutes' CHECK (timeout > interval '0'),
    backoff     interval NOT NULL DEFAULT interval '1 minute' CHECK (backoff > interval '0'),
    catchup     interval NOT NULL DEFAULT interval '30 seconds' CHECK (catchup > interval '0'),
    created     timestamptz NOT NULL DEFAULT Now(),
    updated     timestamptz NOT NULL DEFAULT Now()
);

COMMENT ON TABLE mq.schedule IS 'Session schedule on the pair (channel, link), optionally narrowed to one node. Read by the exchange process; changed while it runs -- every write notifies mq_cmd.';

COMMENT ON COLUMN mq.schedule.id IS 'Schedule identifier.';
COMMENT ON COLUMN mq.schedule.peer IS 'The node this row applies to. NULL is the default for every node; a row naming a node wins over it. Tariffs differ per vessel, which is why the narrower row exists at all.';
COMMENT ON COLUMN mq.schedule.channel IS 'The lane being scheduled.';
COMMENT ON COLUMN mq.schedule.link IS 'The kind of link this schedule applies to.';
COMMENT ON COLUMN mq.schedule.period IS 'How often a session opens on this lane. READ THIS BEFORE CHANGING IT ON AN EVIDENTIAL LANE (mq.channel with no lifetime and no retention -- see MQPlan.evidential): the value answers two independent questions, not one. The first is operational -- how fresh what the far side sees is. The second is evidential -- the hub anchors the hash of the last link it received PER SESSION, so the window in which a truncated tail of the log stays undetectable EQUALS the time since the last session. An hour changed to a day does not make the exchange cheaper by a factor of 24; it makes that window 24 times wider. The two are not split into two settings because physically they are one session.';
COMMENT ON COLUMN mq.schedule.batch IS 'Largest number of messages one session carries. A metered link is paid for by volume, and a bounded session is also a bounded loss when it fails.';
COMMENT ON COLUMN mq.schedule.timeout IS 'How long a session may stay open before it is treated as lost. A session still open past this is a symptom, not a delay.';
COMMENT ON COLUMN mq.schedule.backoff IS 'First delay after a failed session; doubled per consecutive failure and capped by the period. A partial session counts as progress and resets it -- something did get through.';
COMMENT ON COLUMN mq.schedule.catchup IS 'Interval used instead of the period while the node is behind. Breaks in service run to twelve hours here, so catching up is the ordinary path, not the emergency one: a ship idle for a month must not need a month to catch up.';
COMMENT ON COLUMN mq.schedule.created IS 'When the schedule was set.';
COMMENT ON COLUMN mq.schedule.updated IS 'When it was last changed.';

-- Two partial indexes rather than one over (peer, channel, link): the default
-- row and the per-node row must each be unique, and a plain unique index does
-- not constrain rows whose peer is NULL at all.

CREATE UNIQUE INDEX ON mq.schedule (channel, link) WHERE peer IS NULL;
CREATE UNIQUE INDEX ON mq.schedule (peer, channel, link) WHERE peer IS NOT NULL;

--------------------------------------------------------------------------------

/**
 * @brief Notify listeners that the schedule changed.
 * @return {trigger}
 * @since 1.2.18
 */
CREATE OR REPLACE FUNCTION mq.ft_schedule_after()
RETURNS trigger AS $$
DECLARE
  r             record;
BEGIN
  -- NEW is not assigned on DELETE and reading it raises there, so the row is
  -- picked once and every field is read from the copy.

  IF TG_OP = 'DELETE' THEN r := OLD; ELSE r := NEW; END IF;

  PERFORM pg_notify('mq_cmd', json_build_object(
    'object', 'schedule',
    'action', lower(TG_OP),
    'peer', (SELECT p.code FROM mq.peer p WHERE p.id = r.peer),
    'channel', (SELECT c.code FROM mq.channel c WHERE c.id = r.channel),
    'link', (SELECT l.code FROM mq.link l WHERE l.id = r.link)
  )::text);

  RETURN null;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

-- The schedule is changed while the exchange runs. On a vessel, restarting a
-- process is an event; adjusting an interval must not be one.

CREATE TRIGGER t_mq_schedule_after
  AFTER INSERT OR UPDATE OR DELETE ON mq.schedule
  FOR EACH ROW
  EXECUTE PROCEDURE mq.ft_schedule_after();

--------------------------------------------------------------------------------

/**
 * @brief Notify listeners that a link kind changed.
 * @return {trigger}
 * @since 1.2.18
 */
CREATE OR REPLACE FUNCTION mq.ft_link_after()
RETURNS trigger AS $$
DECLARE
  r             record;
BEGIN
  IF TG_OP = 'DELETE' THEN r := OLD; ELSE r := NEW; END IF;

  PERFORM pg_notify('mq_cmd', json_build_object(
    'object', 'link',
    'action', lower(TG_OP),
    'link', r.code
  )::text);

  RETURN null;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

-- The threshold decides which lanes travel here at all, so a change to it moves
-- as much as a change to an interval does.

CREATE TRIGGER t_mq_link_after
  AFTER INSERT OR UPDATE OR DELETE ON mq.link
  FOR EACH ROW
  EXECUTE PROCEDURE mq.ft_link_after();

--------------------------------------------------------------------------------
-- mq.session.link --------------------------------------------------------------
--------------------------------------------------------------------------------

-- Which kind of link a session actually ran over. A fact recorded after the
-- event, not a stored "current link": what a node is reachable over right now
-- is a fact about the world the database cannot verify, and a stored copy goes
-- stale silently. Without it a short session cannot be told from a cheap one,
-- and no claim about whether a schedule was honoured can be checked.

ALTER TABLE mq.session ADD COLUMN link integer REFERENCES mq.link(id);

-- mq.next_session asks mq.session three times per pair, and all three are "the
-- latest rows of one pair in one direction". Without this index each is a scan
-- of that pair's whole history: measured at five years of hourly sessions
-- (43 800 rows), 8.9 ms against 0.67 ms.

CREATE INDEX ON mq.session (peer, channel, direction, finished DESC NULLS FIRST);

COMMENT ON COLUMN mq.session.link IS 'Kind of link this session ran over. A fact recorded after the event, not a stored "current link": which link a node is reachable over is a fact about the world the database cannot verify, and a stored copy of it goes stale silently. Without this column a short session cannot be told from a cheap one, and no claim about whether a schedule was actually honoured can be checked.';

--------------------------------------------------------------------------------
-- Old signatures ---------------------------------------------------------------
--------------------------------------------------------------------------------

-- session_open gained a link parameter with a default. CREATE OR REPLACE does
-- not replace a function whose argument list changed -- it creates a SECOND
-- one, and then a three-argument call matches both and fails as ambiguous. The
-- old signature is dropped by hand, here, before routine.sql recreates the new
-- one.

DROP FUNCTION IF EXISTS api.mq_session_open(text, text, text);
DROP FUNCTION IF EXISTS mq.session_open(integer, integer, text);

\else
\echo '[M] mq: schedule already present, patch skipped'
\endif
