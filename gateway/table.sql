--------------------------------------------------------------------------------
-- gateway.node ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE gateway.node (
    module      text NOT NULL,
    instance    text NOT NULL,
    version     text,
    address     text NOT NULL,
    prefixes    text[] NOT NULL,
    state       text NOT NULL CHECK (state IN ('ready', 'draining', 'suspect', 'offline', 'overloaded')),
    capacity    integer,
    worker      integer,
    registered  timestamptz NOT NULL DEFAULT Now(),
    seen        timestamptz NOT NULL DEFAULT Now(),
    updated     timestamptz NOT NULL DEFAULT Now(),
    PRIMARY KEY (module, instance)
);

COMMENT ON TABLE gateway.node IS 'One row per registered /api/v2 module instance (track-a-gateway.md §5). Written only by the GatewayAPI worker holding the instance''s control socket, and only on a state transition — `seen` moves once per heartbeat interval, not per heartbeat. Rows are never deleted by the database: a dead instance is marked offline by the workers'' sweep.';

COMMENT ON COLUMN gateway.node.module     IS 'Module name from /register (contract К4).';
COMMENT ON COLUMN gateway.node.instance   IS 'Instance name from /register; a second socket with the same (module, instance) replaces the first (contract К2, gateway.log reason = replaced).';
COMMENT ON COLUMN gateway.node.version    IS 'Module version string, informational.';
COMMENT ON COLUMN gateway.node.address    IS 'host:port of the data plane the gateway forwards to (contract К7).';
COMMENT ON COLUMN gateway.node.prefixes   IS 'Path prefixes under /api/v2 this instance serves.';
COMMENT ON COLUMN gateway.node.state      IS 'ready | draining | suspect | offline | overloaded — contract К8; only ready is in rotation.';
COMMENT ON COLUMN gateway.node.capacity   IS 'Declared concurrency, informational for the rotation.';
COMMENT ON COLUMN gateway.node.worker     IS 'pid of the gateway worker holding the control socket.';
COMMENT ON COLUMN gateway.node.registered IS 'When this (module, instance) was last (re)registered.';
COMMENT ON COLUMN gateway.node.seen       IS 'Last heartbeat, one write per interval.';
COMMENT ON COLUMN gateway.node.updated    IS 'Last state change.';

CREATE INDEX ON gateway.node (state);

--------------------------------------------------------------------------------
-- gateway.log -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE gateway.log (
    id          bigserial PRIMARY KEY,
    datetime    timestamptz NOT NULL DEFAULT Now(),
    module      text NOT NULL,
    instance    text NOT NULL,
    state_from  text,
    state_to    text NOT NULL,
    worker      integer,
    reason      text
);

COMMENT ON TABLE gateway.log IS 'Journal of instance state transitions (track-a-gateway.md §5): one row per transition, written by the trigger below from every INSERT / state UPDATE / DELETE on gateway.node. `reason` is what the worker put into the row (replaced, socket closed, heartbeat timeout, …).';

CREATE INDEX ON gateway.log (module, instance, datetime);

--------------------------------------------------------------------------------
-- gateway.ft_node_notify ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief AFTER trigger on gateway.node: journals the transition into gateway.log
 *        and tells every listening gateway worker about it with
 *        pg_notify('gateway', …) — the ≤ 1 s half of "draining accepted → all
 *        workers stop routing" (contract К8; the 60 s re-read is the other half,
 *        for a lost NOTIFY). Fires on INSERT, DELETE and on an UPDATE that changes
 *        `state` — NOT on a heartbeat that only moves `seen`, so a fleet of
 *        modules cannot turn the channel into a metronome.
 *
 * Payload (JSON): {"op": "INSERT|UPDATE|DELETE", "module", "instance",
 *                  "state", "state_from", "address", "prefixes", "worker"}.
 * NOTIFY is transactional: a listener sees the row committed.
 *
 * `reason` travels through the row itself: the worker writes it into a session
 * GUC `gateway.reason` before the statement (set_config('gateway.reason', …,
 * true)), the trigger copies it into the journal and clears nothing — the GUC
 * dies with the transaction.
 */
CREATE OR REPLACE FUNCTION gateway.ft_node_notify()
RETURNS trigger
AS $$
DECLARE
  vOp         text := TG_OP;
  vFrom       text;
  vTo         text;
  vReason     text;
BEGIN
  vReason := nullif(current_setting('gateway.reason', true), '');

  IF TG_OP = 'DELETE' THEN
    vFrom := OLD.state;
    vTo   := 'offline';
  ELSIF TG_OP = 'INSERT' THEN
    vFrom := null;
    vTo   := NEW.state;
  ELSE
    IF NEW.state IS NOT DISTINCT FROM OLD.state THEN
      RETURN NULL;          -- heartbeat / address refresh: no journal, no NOTIFY
    END IF;
    vFrom := OLD.state;
    vTo   := NEW.state;
  END IF;

  INSERT INTO gateway.log (module, instance, state_from, state_to, worker, reason)
  VALUES (coalesce(NEW.module, OLD.module), coalesce(NEW.instance, OLD.instance), vFrom, vTo,
          coalesce(NEW.worker, OLD.worker), vReason);

  PERFORM pg_notify('gateway', json_build_object(
    'op',         vOp,
    'module',     coalesce(NEW.module, OLD.module),
    'instance',   coalesce(NEW.instance, OLD.instance),
    'state',      vTo,
    'state_from', vFrom,
    'address',    coalesce(NEW.address, OLD.address),
    'prefixes',   coalesce(NEW.prefixes, OLD.prefixes),
    'worker',     coalesce(NEW.worker, OLD.worker)
  )::text);

  RETURN NULL;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = gateway, kernel, pg_temp;

CREATE TRIGGER t_gateway_node_notify
  AFTER INSERT OR UPDATE OR DELETE ON gateway.node
  FOR EACH ROW EXECUTE FUNCTION gateway.ft_node_notify();

--------------------------------------------------------------------------------
-- grants: the GatewayAPI worker writes as daemon (worker pool) or apibot ------
--------------------------------------------------------------------------------

GRANT SELECT, INSERT, UPDATE, DELETE ON gateway.node TO daemon, apibot;
GRANT SELECT, INSERT ON gateway.log TO daemon, apibot;
GRANT USAGE ON SEQUENCE gateway.log_id_seq TO daemon, apibot;
GRANT SELECT ON gateway.node, gateway.log TO administrator;
