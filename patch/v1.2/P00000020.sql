--------------------------------------------------------------------------------
-- P00000020 -------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Schema `gateway` — the database half of the GatewayAPI module (track A,
-- /api/v2): gateway.node (one row per module instance), gateway.log (state
-- transitions), the AFTER trigger that journals + pg_notify('gateway'), and the
-- view gateway.route. The api.* wrappers of the module (api.authorize_local,
-- api.log_request, api.parse_message) are functions and come with update.psql
-- (gateway/update.psql) right after this patch.
--
-- Moved into the platform from the apostol-csms configuration (T301,
-- 16.09.2026). Two kinds of installed bases meet this patch:
--
--   * a base that already carries the schema from the project's own patch
--     (csms P00000044, v1.13.0): every statement here is IF NOT EXISTS / OR
--     REPLACE / a repeated GRANT — the only visible change is the grant to the
--     `administrator` group, where the project version granted the `admin`
--     login directly (left in place; admin is a member of administrator);
--   * any other db-platform base: the schema is created here, in full.
--
-- Self-contained snapshot on purpose (the same bodies as gateway/table.sql and
-- gateway/view.sql): migrate.sh may run a patch from a scratch directory where
-- a relative \ir does not resolve, and update.psql never re-runs table.sql.
-- Single phase, kernel: DDL and GRANTs only, no session. Idempotent.
--------------------------------------------------------------------------------

CREATE SCHEMA IF NOT EXISTS gateway;

GRANT USAGE ON SCHEMA gateway TO kernel;
GRANT USAGE ON SCHEMA gateway TO administrator;
GRANT USAGE ON SCHEMA gateway TO daemon;
GRANT USAGE ON SCHEMA gateway TO apibot;

-- csms P00000044 carried no schema comment; fresh installs have it — converge.
COMMENT ON SCHEMA gateway IS 'GatewayAPI, track A (track-a-gateway.md §5): the database mirror of the gateway''s module registry — which /api/v2 module instances exist, where they listen and in what state. Written by the GatewayAPI worker that owns the instance''s control socket, read by other applications through gateway.route.';

--------------------------------------------------------------------------------
-- gateway.node ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS gateway.node (
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

CREATE INDEX IF NOT EXISTS node_state_idx ON gateway.node (state);

--------------------------------------------------------------------------------
-- gateway.log -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS gateway.log (
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

CREATE INDEX IF NOT EXISTS log_module_instance_datetime_idx ON gateway.log (module, instance, datetime);

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

DROP TRIGGER IF EXISTS t_gateway_node_notify ON gateway.node;
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

--------------------------------------------------------------------------------
-- gateway.route ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Prefix → module → how many instances are in rotation. What another
 *        application (and GET /gateway/list) reads instead of gateway.node
 *        (track-a-gateway.md §5). Only `ready` counts: suspect, draining,
 *        overloaded and offline are outside rotation by contract К8.
 */
CREATE OR REPLACE VIEW gateway.route
AS
  SELECT p.prefix, n.module,
         count(*) FILTER (WHERE n.state = 'ready')::integer AS instances_ready,
         count(*)::integer                                   AS instances_total
    FROM gateway.node n
   CROSS JOIN LATERAL unnest(n.prefixes) AS p(prefix)
   GROUP BY p.prefix, n.module;

COMMENT ON VIEW gateway.route IS 'Routing table as the gateway sees it: one row per (prefix, module) with the number of ready instances. Zero ready with total > 0 is the 503 no-instance case of contract К7.';

GRANT SELECT ON gateway.route TO daemon, apibot, administrator;
