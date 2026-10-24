--------------------------------------------------------------------------------
-- P00000035 -------------------------------------------------------------------
--------------------------------------------------------------------------------
-- The module `notify` and its producers (apostol-csms T1100, stage E1 of T996).
--
-- What arrives: schema notify -- notify.channel (the delivery policy per
-- channel), notify.queue (a row per unit of work of a channel that is switched
-- to `single`), notify.subscriber (the live listeners), the functions send,
-- subscribe, heartbeat, drain, unsubscribe, take, ack, nack, sweep,
-- sweep_channel, retarget, the views, api.* and the /notify/... routes of the
-- administrator. Every channel of the platform is recorded as `legacy`:
-- notify.send of a legacy channel is exactly pg_notify(channel, data), so a
-- binary that knows nothing of the module and a binary that does can share a
-- database.
--
-- What changes: the twelve trigger functions below call notify.send where they
-- called pg_notify. `update.psql` never re-runs table.sql, which is why they are
-- here, as a self-contained snapshot of the bodies in the table.sql files
-- (one function: gateway.ft_node_notify, is the body of P00000032). The
-- triggers themselves are untouched. The routines that are not trigger
-- functions (mq.advance & co.) are replaced by `update.psql` after the patches,
-- as always.
--
-- The module's own create.psql is included rather than copied (the reasoning
-- of P00000016): a second copy of the DDL is a second copy that drifts.
--
-- ORDER. The module is created first: the functions below call notify.send, and a
-- function body is resolved when it runs, so the other order would only be
-- wrong for the length of this patch -- but it would be wrong. A configuration
-- that registers channels of its own (notify.channel rows with target_fn and
-- on_abandon) does so AFTER this patch and after its own functions exist: the
-- names are checked when the row is written (notify.ft_channel_check).
--
-- Single phase, kernel: DDL only, no session. Re-runnable: the module is
-- skipped when it is there, CREATE OR REPLACE changes nothing the second time.
--------------------------------------------------------------------------------

DO $$
DECLARE
  present   integer;
BEGIN
  -- Two situations put a "notify" schema here before this patch runs, and they
  -- need opposite answers (the same two as in P00000016): the database was built
  -- by a create.psql that carries the module and nobody ran migrate.sh
  -- --baseline afterwards -- then it is ours and complete, and it is skipped
  -- quietly below; or somebody's own schema is called notify -- that one must
  -- not be written over.
  SELECT count(*) INTO present
    FROM information_schema.tables
   WHERE table_schema = 'notify'
     AND table_name IN ('channel', 'queue', 'subscriber');

  IF EXISTS (SELECT FROM information_schema.schemata WHERE schema_name = 'notify') AND present <> 3 THEN
    RAISE EXCEPTION 'A schema named "notify" already exists here and is not the platform''s (% of 3 tables)', present
      USING HINT = 'Reconcile it by hand before this patch is recorded as applied.';
  END IF;

  -- The three tables are there but the module is not whole: an earlier run died
  -- inside create.psql (the patch has no transaction). Skipping the module and
  -- replacing the trigger functions would point every producer at a notify.send
  -- that does not exist.
  IF present = 3 AND to_regprocedure('notify.send(text, text, text, interval, integer)') IS NULL THEN
    RAISE EXCEPTION 'The module "notify" is half installed here (3 tables, no notify.send)'
      USING HINT = 'DROP SCHEMA notify CASCADE and run this patch again.';
  END IF;
END $$;

SELECT NOT EXISTS (SELECT FROM information_schema.schemata WHERE schema_name = 'notify') AS notify_absent \gset

\if :notify_absent
\ir '../../notify/create.psql'
\else
\echo '[M] notify: schema already present, module skipped (built by create.psql, not yet baselined)'
\endif

--------------------------------------------------------------------------------
-- db.ft_message_after_insert --------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Emit pg_notify on the message channel with class, type, agent, and address details after insert.
 * @return {trigger}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION db.ft_message_after_insert()
RETURNS trigger AS $$
DECLARE
  vClass    text;
  vType     text;
  vAgent    text;
BEGIN
  SELECT c.code INTO vClass
    FROM db.object o INNER JOIN db.class_tree c ON c.id = o.class
   WHERE o.id = NEW.id;

  SELECT t.code, a.code INTO vType, vAgent
    FROM db.reference a INNER JOIN db.type t ON t.id = a.type
   WHERE a.id = NEW.agent;

  PERFORM notify.send('message', json_build_object('id', NEW.id, 'class', vClass, 'type', vType, 'agent', vAgent, 'code', NEW.code, 'profile', NEW.profile, 'address', NEW.address, 'subject', NEW.subject)::text);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- db.ft_object_coordinates_after_insert ---------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Send a pg_notify geo event when a current-period coordinate is inserted.
 * @param {trigger} NEW - Newly inserted coordinate row
 * @return {trigger} - NEW (unchanged)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION db.ft_object_coordinates_after_insert()
RETURNS trigger AS $$
BEGIN
  IF NEW.validToDate = MAXDATE() THEN
    PERFORM notify.send('geo', json_build_object('id', NEW.id, 'object', NEW.object, 'code', NEW.code)::text);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- db.ft_file_notify -----------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Emit a LISTEN/NOTIFY event for the PGFile helper on every file change.
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION db.ft_file_notify()
RETURNS trigger AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.type != 's' THEN
      PERFORM notify.send('file', json_build_object('session', current_session(), 'operation', TG_OP, 'id', NEW.id, 'type', NEW.type, 'name', NEW.name, 'path', NEW.path, 'hash', NEW.hash)::text);
    END IF;
  ELSE
    PERFORM notify.send('file', json_build_object('session', current_session(), 'operation', TG_OP, 'id', OLD.id, 'type', NEW.type, 'name', OLD.name, 'path', OLD.path, 'hash', OLD.hash)::text);
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

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

  PERFORM notify.send('gateway', json_build_object(
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

--------------------------------------------------------------------------------
-- http.ft_request_after_insert ------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Fire a NOTIFY event after a new HTTP request is inserted.
 * @return {trigger} - After-insert trigger return
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION http.ft_request_after_insert()
RETURNS     trigger
AS $$
BEGIN
  PERFORM notify.send('http', NEW.id::text, NEW.id::text, NEW.expire, NEW.max_attempts);
  RETURN NULL;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- db.ft_log_after_insert ------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Broadcast a pg_notify event after a log row is inserted.
 * @return {trigger} - Unchanged NEW row (notification is a side effect)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION db.ft_log_after_insert()
RETURNS trigger AS $$
BEGIN
  PERFORM notify.send('log', json_build_object('id', NEW.id, 'type', NEW.type, 'code', NEW.code, 'username', NEW.username, 'scope', NEW.scope, 'event', NEW.event, 'category', NEW.category)::text);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- mq.ft_schedule_after --------------------------------------------------------
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

  PERFORM notify.send('mq_cmd', json_build_object(
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
-- mq.ft_link_after ------------------------------------------------------------
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

  PERFORM notify.send('mq_cmd', json_build_object(
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
-- mq.ft_message_after_insert --------------------------------------------------
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
    PERFORM notify.send('mq', json_build_object('channel', NEW.channel, 'target', NEW.target, 'serial', NEW.serial, 'type', NEW.type)::text);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- db.ft_notice_after_insert ---------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Fire a pg_notify on the 'notice' channel after a new notice is inserted.
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION db.ft_notice_after_insert()
RETURNS trigger AS $$
BEGIN
  PERFORM notify.send('notice', json_build_object('id', NEW.id, 'userid', NEW.userid, 'object', NEW.object, 'category', NEW.category)::text);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- db.ft_notification_after_insert ---------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Dispatch pg_notify signals after a notification insert (notify, inbox, outbox, report channels).
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION db.ft_notification_after_insert()
RETURNS     trigger
AS $$
DECLARE
  vClass    text;
  vEntity   text;
  vAction   text;
BEGIN
  IF NOT GetNotificationMode() THEN
	RETURN NEW;
  END IF;

  PERFORM notify.send('notify', row_to_json(NEW)::text);

  vEntity := GetEntityCode(NEW.entity);

  IF vEntity = 'message' THEN

    vClass := GetClassCode(NEW.class);
    vAction := GetActionCode(NEW.action);

    IF vClass = 'inbox' THEN
      IF vAction = 'create' THEN
        PERFORM notify.send('inbox', NEW.object::text);
      END IF;
    ELSIF vClass = 'outbox' THEN
      IF vAction = 'submit' OR vAction = 'repeat' THEN
        PERFORM notify.send('outbox', NEW.object::text);
      END IF;
    END IF;

  ELSIF vEntity = 'report_ready' THEN

    vAction := GetActionCode(NEW.action);

    IF vAction = 'execute' THEN
      PERFORM notify.send('report', json_build_object('session', current_session(), 'id', NEW.object)::text);
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- replication.ft_log_after_insert ---------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Emit pg_notify on the replication channel after a new log entry is inserted.
 * @return {trigger}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION replication.ft_log_after_insert()
RETURNS trigger AS $$
BEGIN
  PERFORM notify.send('replication', json_build_object('id', NEW.id, 'datetime', NEW.datetime, 'action', NEW.action, 'schema', NEW.schema, 'name', NEW.name, 'source', NEW.source)::text);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
