--------------------------------------------------------------------------------
-- P00000032 -------------------------------------------------------------------
--------------------------------------------------------------------------------
-- The identity of a gateway worker beyond its pid (apostol-csms T592, stage 1;
-- owner's decision Р2). `worker integer` is a pid, and two pods — or two
-- containers on one database — hand the same pid to two workers: each then
-- takes the other's row in gateway.node for its own (closes it, or re-claims
-- it with its own clock). The worker will write its node identity (libapostol
-- node_id(): NODE_NAME, else the host name) next to its pid:
--
--   gateway.node.node, gateway.log.node — text, nullable, no default. `worker`
--   keeps its type: a binary that knows nothing of `node` writes exactly as
--   before and its rows carry node = NULL. Columns without a default: metadata
--   only, no rewrite; each ALTER takes ACCESS EXCLUSIVE for a moment, under
--   lock_timeout — the gateway workers write gateway.node on every transition.
--   Table-level grants (daemon, apibot, administrator) cover the new columns.
--
--   gateway.ft_node_notify — journals `node` into gateway.log; the NOTIFY
--   payload gains `node` and `updated` after the eight keys it had, which stay
--   as they were.
--
-- Self-contained snapshot, the same body as gateway/table.sql: update.psql
-- never re-runs table.sql, and migrate.sh may run a patch from a scratch
-- directory where a relative \ir does not resolve. The trigger itself is
-- unchanged (P00000020): only its function is replaced.
--
-- ORDER. migrate.sh runs platform patches before configuration ones, and
-- apostol-csms configuration P00000044 re-creates gateway.ft_node_notify with
-- the body of P00000020: on any base where migrate applies P00000044 after
-- this patch the columns stay, the payload and the journal lose `node`, and
-- migrate still ends with rc 0. That is a csms base whose db.patch_log lacks
-- P00000044 — one older than csms v1.13.0, or a source-clone install followed
-- by `install.sh --migrate` without `--baseline` (migrate.sh then replays every
-- patch; the image path baselines first). Such a base needs this file once
-- more after its migrate. A base that has P00000044 in db.patch_log is not
-- affected.
--
-- Single phase, kernel: DDL only, no session. Re-runnable: a second run
-- changes nothing.
--------------------------------------------------------------------------------

SET lock_timeout = '10s';

ALTER TABLE gateway.node ADD COLUMN IF NOT EXISTS node text;
ALTER TABLE gateway.log ADD COLUMN IF NOT EXISTS node text;

RESET lock_timeout;

COMMENT ON COLUMN gateway.node.node       IS 'Identity of the gateway process holding the control socket, unique across pods and containers (T592): a pid alone repeats between them. NULL — written by a binary that does not know the column.';
COMMENT ON COLUMN gateway.log.node IS 'gateway.node.node of the row at the transition (T592) — the process holding the instance, like `worker` its pid; not necessarily the one that wrote it (a sweep by another worker keeps the holder). NULL from a binary that does not know the column.';

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
 *                  "state", "state_from", "address", "prefixes", "worker",
 *                  "node", "updated"}.
 * `node` and `updated` (T592) are those of the row after the statement — of
 * the deleted row on DELETE; `node` is null from a binary that does not write
 * it. The first eight keys are unchanged since P00000020.
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
  vNode       text;
  vUpdated    timestamptz;
BEGIN
  vReason := nullif(current_setting('gateway.reason', true), '');

  IF TG_OP = 'DELETE' THEN
    vFrom := OLD.state;
    vTo   := 'offline';
    vNode := OLD.node;
    vUpdated := OLD.updated;
  ELSIF TG_OP = 'INSERT' THEN
    vFrom := null;
    vTo   := NEW.state;
    vNode := NEW.node;
    vUpdated := NEW.updated;
  ELSE
    IF NEW.state IS NOT DISTINCT FROM OLD.state THEN
      RETURN NULL;          -- heartbeat / address refresh: no journal, no NOTIFY
    END IF;
    vFrom := OLD.state;
    vTo   := NEW.state;
    vNode := NEW.node;
    vUpdated := NEW.updated;
  END IF;

  INSERT INTO gateway.log (module, instance, state_from, state_to, worker, reason, node)
  VALUES (coalesce(NEW.module, OLD.module), coalesce(NEW.instance, OLD.instance), vFrom, vTo,
          coalesce(NEW.worker, OLD.worker), vReason, vNode);

  PERFORM pg_notify('gateway', json_build_object(
    'op',         vOp,
    'module',     coalesce(NEW.module, OLD.module),
    'instance',   coalesce(NEW.instance, OLD.instance),
    'state',      vTo,
    'state_from', vFrom,
    'address',    coalesce(NEW.address, OLD.address),
    'prefixes',   coalesce(NEW.prefixes, OLD.prefixes),
    'worker',     coalesce(NEW.worker, OLD.worker),
    'node',       vNode,
    'updated',    vUpdated
  )::text);

  RETURN NULL;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = gateway, kernel, pg_temp;
