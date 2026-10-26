--------------------------------------------------------------------------------
-- NOTIFY ----------------------------------------------------------------------
--------------------------------------------------------------------------------

-- pg_notify is a broadcast: every instance listening on a channel does the same
-- work once. This module turns the channels that carry WORK (an outbound HTTP
-- call, a mail, a report, a job, a command to a station) into rows that are
-- handed to exactly one live subscriber, taken under a token, and confirmed
-- with the same token in the same transaction as the result. A late
-- confirmation under an old token is refused together with the result it
-- carries. What a channel does is decided by the channel table, not by the
-- producer: the producer calls notify.send in place of pg_notify and does not
-- know the mode.
--
-- Nothing here is a result store. The result lives in the producer's own record
-- (http.response, an outbox message, a job); a row of notify.queue is the trace
-- of the DELIVERY -- who took it, how many times, why it was closed.

--------------------------------------------------------------------------------
-- notify.channel --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE notify.channel (
  code            text PRIMARY KEY CHECK (char_length(code) BETWEEN 1 AND 50),
  description     text,
  -- broadcast: plain pg_notify. single: a row and one addressee. legacy: as
  -- before this module existed (plain pg_notify) -- the switch of a rollout, it
  -- is what lets old and new binaries share a database.
  mode            text NOT NULL DEFAULT 'legacy' CHECK (mode IN ('broadcast', 'single', 'legacy')),
  -- who gets a row: any -- the least loaded live subscriber; key -- the same one
  -- for the same key (highest rendezvous hash of key and subscriber number);
  -- route -- the one target_fn(key) names at the moment of taking.
  affinity        text NOT NULL DEFAULT 'any' CHECK (affinity IN ('any', 'key', 'route')),
  -- route only: function (text) RETURNS integer, a key to a subscriber number.
  target_fn       text,
  -- how long the addressee may leave a row before any subscriber may take it
  -- (any, key); route has no "anybody".
  grace           interval NOT NULL DEFAULT interval '3 seconds',
  -- how long a taken row may stay unconfirmed before it is given out again or
  -- closed. A property of the executor: longer than its own timeout.
  lease           interval NOT NULL DEFAULT interval '1 minute',
  -- defaults for a producer that gave none. A repeat is a delivery after the
  -- first: max_attempts = 0 means none. expire counts from `seen`.
  expire          interval,
  max_attempts    integer CHECK (max_attempts >= 0),
  -- emergency brake: false -- no row of the channel that was SENT is repeated (a row refused as `unsent:` on its first delivery goes back all the same: it never left).
  resend_enabled  boolean NOT NULL DEFAULT true,
  -- function (bigint, text, text, text) -- (queue id, key, payload, reason): called
  -- when a row is closed without a confirmation.
  on_abandon      text,
  -- call on_abandon also when the row was never handed out (expired or
  -- unrouted), not only when it was sent and its outcome is unknown.
  on_expire       boolean NOT NULL DEFAULT false,
  -- one row per (channel, key) in every state while the row is kept.
  dedupe          boolean NOT NULL DEFAULT false,
  retain_done     interval NOT NULL DEFAULT interval '7 days',
  retain_closed   interval NOT NULL DEFAULT interval '90 days',
  -- a subscriber silent longer than this is not chosen as the addressee.
  alive           interval NOT NULL DEFAULT interval '15 seconds',
  -- the tick of notify.sweep; not longer than grace.
  sweep_every     interval NOT NULL DEFAULT interval '2 seconds',
  -- false: written by notify.send / notify.subscribe on first sight, nobody
  -- assigned its mode.
  classified      boolean NOT NULL DEFAULT true,
  first_seen      timestamptz NOT NULL DEFAULT clock_timestamp(),
  purged          timestamptz,
  -- function (boolean, integer) RETURNING integer -- (switch, limit): the owning module's own look at the objects
  -- that stand in the delivery of this channel and hold no open row of notify.queue (a callback that failed, an
  -- object the old path had when the channel was switched). Called by notify.release: with switch = true by the
  -- trigger that follows a change of the mode to single, with switch = false by the sweep of a single channel.
  -- Last in the table on purpose: a base that got it by a patch has it last too.
  on_release      text,
  CHECK (affinity <> 'route' OR target_fn IS NOT NULL),
  CHECK (NOT dedupe OR retain_done >= interval '1 hour')
);

COMMENT ON TABLE notify.channel IS 'Delivery policy per pg_notify channel: broadcast, single (one addressee, taken under a token) or legacy (rollout switch).';

-- target_fn and on_abandon are text that notify.route_holder and notify.close run
-- under EXECUTE, and a misspelt name there would not fail: route_holder reads a
-- failure as "no holder", for every row of the channel, leaving no trace. So the
-- name is checked where it is written -- an INSERT, or an UPDATE that names the
-- column (the sweep updates `purged` every minute and must not depend on it). A
-- text that is not a plain function name does not resolve either, which is the
-- second thing this guards: the name is interpolated into a statement.
CREATE OR REPLACE FUNCTION notify.ft_channel_check()
RETURNS trigger
AS $$
DECLARE
  rFn           regprocedure;
BEGIN
  IF NEW.target_fn IS NOT NULL THEN
    rFn := to_regprocedure(NEW.target_fn || '(text)');

    IF rFn IS NULL OR (SELECT prorettype FROM pg_proc WHERE oid = rFn) <> 'integer'::regtype THEN
      RAISE EXCEPTION 'ERR-40000: Channel "%": target_fn "%" is not a function (text) RETURNING integer.', NEW.code, NEW.target_fn;
    END IF;
  END IF;

  IF NEW.on_abandon IS NOT NULL AND to_regprocedure(NEW.on_abandon || '(bigint,text,text,text)') IS NULL THEN
    RAISE EXCEPTION 'ERR-40000: Channel "%": on_abandon "%" is not a function (bigint, text, text, text).', NEW.code, NEW.on_abandon;
  END IF;

  IF NEW.on_release IS NOT NULL THEN
    rFn := to_regprocedure(NEW.on_release || '(boolean,integer)');

    IF rFn IS NULL OR (SELECT prorettype FROM pg_proc WHERE oid = rFn) <> 'integer'::regtype THEN
      RAISE EXCEPTION 'ERR-40000: Channel "%": on_release "%" is not a function (boolean, integer) RETURNING integer.', NEW.code, NEW.on_release;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

CREATE TRIGGER t_channel_check
  BEFORE INSERT OR UPDATE OF target_fn, on_abandon, on_release ON notify.channel
  FOR EACH ROW EXECUTE FUNCTION notify.ft_channel_check();

-- A channel that is switched to single must not leave behind what the old path had in its hands: an object that
-- stands in the delivery and has no row in notify.queue is taken by nobody once the poll of the old path is off
-- (a poller reads the mode in the same statement). The module that owns the channel names the function that sees
-- to it (on_release); it runs here, in the transaction of the switch, whoever made the switch (the REST route, the
-- api function, a hand-made UPDATE). A refusal of that function (an exception) refuses the switch: the mode stays.
-- AFTER the update, not before: notify.send reads the mode of the row, and a row put in on the way to single has
-- to see single.
CREATE OR REPLACE FUNCTION notify.ft_channel_switch()
RETURNS trigger
AS $$
BEGIN
  PERFORM notify.release(NEW.code, true, null);
  RETURN NULL;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

CREATE TRIGGER t_channel_switch
  AFTER UPDATE OF mode ON notify.channel
  FOR EACH ROW
  WHEN (NEW.mode = 'single' AND OLD.mode IS DISTINCT FROM NEW.mode)
  EXECUTE FUNCTION notify.ft_channel_switch();

COMMENT ON COLUMN notify.channel.mode IS 'broadcast: pg_notify; single: row + one addressee; legacy: as before the module (pg_notify) -- the rollout switch.';
COMMENT ON COLUMN notify.channel.affinity IS 'any: least loaded live subscriber; key: highest hash(key, subscriber id); route: target_fn(key) at the moment of taking.';
COMMENT ON COLUMN notify.channel.target_fn IS 'route only: function (text) RETURNS integer -- key to subscriber number; NULL or unknown subscriber means "no holder".';
COMMENT ON COLUMN notify.channel.grace IS 'How long the addressee may leave a row before any subscriber may take it (any, key). Counted from notify.queue.seen.';
COMMENT ON COLUMN notify.channel.lease IS 'How long a taken row may stay unconfirmed before it is given out again or closed.';
COMMENT ON COLUMN notify.channel.expire IS 'Default for a row that gave none: how long after `seen` the row may still be handed out. NULL -- no limit.';
COMMENT ON COLUMN notify.channel.max_attempts IS 'Default number of REPEATS after the first delivery (0 -- none). A repeat is allowed while attempts <= max_attempts.';
COMMENT ON COLUMN notify.channel.on_abandon IS 'Function (bigint, text, text, text) = (queue id, key, payload, reason) called when a row is closed without a confirmation.';
COMMENT ON COLUMN notify.channel.on_release IS 'Function (boolean, integer) RETURNING integer = (switch, limit): the owning module''s look at the objects that stand in the delivery of this channel and hold no open row of the queue. Called by the trigger that follows a switch to single (switch = true: it may refuse the switch) and by the sweep of a single channel (switch = false).';
COMMENT ON COLUMN notify.channel.on_expire IS 'Call on_abandon also for a row that was never handed out (expired, unrouted).';
COMMENT ON COLUMN notify.channel.classified IS 'false: the channel was recorded on first sight, nobody assigned its mode.';

--------------------------------------------------------------------------------
-- notify.queue ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE SEQUENCE notify.token;

CREATE TABLE notify.queue (
  id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  channel         text NOT NULL,
  payload         text,
  key             text,
  expire          interval,
  max_attempts    integer CHECK (max_attempts >= 0),
  dedupe          boolean NOT NULL DEFAULT false,
  target          integer,
  -- 0 waiting, 1 taken, 2 confirmed, 3 closed (error, not sent, outcome unknown)
  state           smallint NOT NULL DEFAULT 0 CHECK (state BETWEEN 0 AND 3),
  owner           integer,
  token           bigint,
  taken           timestamptz,
  lease_until     timestamptz,
  -- the first time a subscriber looked at the row (a take or a sweep). grace and
  -- expire count from here, not from the insert: a producer's long transaction
  -- would otherwise let the row out already expired.
  seen            timestamptz,
  -- the last wake-up sent for the row after its first one: by the sweep, by a repeat (nack),
  -- by the settling of the row before it (wake_next), by a retarget. The sweep does not say
  -- a waiting row again for 3/4 of channel.sweep_every after it, whoever sweeps, and says
  -- it to ONE subscriber (the next in the ring): otherwise every subscriber's tick wakes
  -- every live subscriber for every waiting row, and an overloaded executor is answered
  -- with a storm.
  woken           timestamptz,
  attempts        integer NOT NULL DEFAULT 0,
  error           text,
  created         timestamptz NOT NULL DEFAULT clock_timestamp(),
  done            timestamptz
);

COMMENT ON TABLE notify.queue IS 'Delivery rows of single channels: who took it, under which token, how many times, why it was closed.';

COMMENT ON COLUMN notify.queue.state IS '0 waiting, 1 taken, 2 confirmed, 3 closed without a confirmation.';
COMMENT ON COLUMN notify.queue.token IS 'Taken under this token; notify.ack and notify.nack accept only the current one.';
COMMENT ON COLUMN notify.queue.seen IS 'First observation by a subscriber; grace and expire count from it, not from created.';
COMMENT ON COLUMN notify.queue.woken IS 'The last wake-up sent for the row after its first (sweep, repeat, next of a key, retarget); the sweep does not say a waiting row again for 3/4 of channel.sweep_every after it, and says it to one subscriber, the next in the ring.';
COMMENT ON COLUMN notify.queue.attempts IS 'Deliveries so far (a take is one).';
COMMENT ON COLUMN notify.queue.dedupe IS 'Copied from the channel at insert: a row of a dedupe channel is unique by (channel, key).';

CREATE INDEX queue_pending ON notify.queue (channel, id) WHERE state < 2;
CREATE INDEX queue_key ON notify.queue (channel, key, id) WHERE state < 2 AND key IS NOT NULL;
-- every state: a producer that keeps its own record next to a delivery row (http.sweep asks "has this request a
-- delivery row, closed or not") looks up by (channel, key); queue_key above holds the open rows only.
CREATE INDEX queue_channel_key ON notify.queue (channel, key) WHERE key IS NOT NULL;
CREATE INDEX queue_target ON notify.queue (target) WHERE state = 0;
CREATE INDEX queue_owner ON notify.queue (owner) WHERE state = 1;
CREATE INDEX queue_lease ON notify.queue (lease_until) WHERE state = 1;
CREATE INDEX queue_kept ON notify.queue (channel, done) WHERE state >= 2;
CREATE UNIQUE INDEX queue_dedupe ON notify.queue (channel, key) WHERE dedupe;

--------------------------------------------------------------------------------
-- notify.subscriber -----------------------------------------------------------
--------------------------------------------------------------------------------

-- One row per (instance, channel). The number the database issues names the
-- personal channel "<channel>:<id>" that the addressee listens on; every
-- restart is a new number (a pid repeats between containers, a StatefulSet
-- gives a new pod the old pod's name).

CREATE TABLE notify.subscriber (
  id              integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  node            text NOT NULL,
  application     text,
  role            text,
  channel         text NOT NULL,
  state           text NOT NULL DEFAULT 'active' CHECK (state IN ('active', 'draining')),
  backend_pid     integer,
  started         timestamptz NOT NULL DEFAULT clock_timestamp(),
  seen            timestamptz NOT NULL DEFAULT clock_timestamp()
);

COMMENT ON TABLE notify.subscriber IS 'Live listeners of single channels; the number the database issues names the personal channel "<channel>:<id>".';

COMMENT ON COLUMN notify.subscriber.node IS 'Signature for people (node_id() of libapostol); not an identity -- the number is.';
COMMENT ON COLUMN notify.subscriber.state IS 'active -- may be chosen as the addressee; draining -- takes nothing new, finishes what it started.';
COMMENT ON COLUMN notify.subscriber.seen IS 'Last heartbeat; a subscriber silent longer than channel.alive is not chosen.';

CREATE INDEX subscriber_channel ON notify.subscriber (channel, state, seen);
