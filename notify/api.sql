--------------------------------------------------------------------------------
-- NOTIFY ----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.notify_channel
AS
  SELECT * FROM NotifyChannel;

GRANT SELECT ON api.notify_channel TO administrator;
GRANT SELECT ON api.notify_channel TO apibot;

--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.notify_subscriber
AS
  SELECT * FROM NotifySubscriber;

GRANT SELECT ON api.notify_subscriber TO administrator;
GRANT SELECT ON api.notify_subscriber TO apibot;

--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.notify_queue
AS
  SELECT * FROM NotifyQueue;

GRANT SELECT ON api.notify_queue TO administrator;
GRANT SELECT ON api.notify_queue TO apibot;

--------------------------------------------------------------------------------
-- api.count_notify_subscriber -------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Count subscribers matching search/filter criteria.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Exact-match filter object
 * @return {SETOF bigint} - Record count
 * @since 1.2.37
 */
CREATE OR REPLACE FUNCTION api.count_notify_subscriber (
  pSearch    jsonb default null,
  pFilter    jsonb default null
) RETURNS    SETOF bigint
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'notify_subscriber', pSearch, pFilter, 0, null, '{}'::jsonb, '["count(id)"]'::jsonb);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_notify_subscriber --------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief List subscribers with optional search, filter and pagination.
 * @param {jsonb} pSearch - Full-text search criteria
 * @param {jsonb} pFilter - Column-level filter conditions
 * @param {integer} pLimit - Maximum number of rows to return
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Sort specification
 * @return {SETOF api.notify_subscriber} - Matching subscribers
 * @since 1.2.37
 */
CREATE OR REPLACE FUNCTION api.list_notify_subscriber (
  pSearch       jsonb default null,
  pFilter       jsonb default null,
  pLimit        integer default null,
  pOffSet       integer default null,
  pOrderBy      jsonb default null
) RETURNS       SETOF api.notify_subscriber
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'notify_subscriber', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.count_notify_queue ------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Count delivery rows matching search/filter criteria.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Exact-match filter object
 * @return {SETOF bigint} - Record count
 * @since 1.2.37
 */
CREATE OR REPLACE FUNCTION api.count_notify_queue (
  pSearch    jsonb default null,
  pFilter    jsonb default null
) RETURNS    SETOF bigint
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'notify_queue', pSearch, pFilter, 0, null, '{}'::jsonb, '["count(id)"]'::jsonb);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_notify_queue -------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief List delivery rows with optional search, filter and pagination.
 * @param {jsonb} pSearch - Full-text search criteria
 * @param {jsonb} pFilter - Column-level filter conditions
 * @param {integer} pLimit - Maximum number of rows to return
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Sort specification
 * @return {SETOF api.notify_queue} - Matching rows
 * @since 1.2.37
 */
CREATE OR REPLACE FUNCTION api.list_notify_queue (
  pSearch       jsonb default null,
  pFilter       jsonb default null,
  pLimit        integer default null,
  pOffSet       integer default null,
  pOrderBy      jsonb default null
) RETURNS       SETOF api.notify_queue
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'notify_queue', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_notify_channel ------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief One channel.
 * @param {text} pCode - Channel code
 * @return {SETOF api.notify_channel}
 * @since 1.2.37
 */
CREATE OR REPLACE FUNCTION api.get_notify_channel (
  pCode         text
) RETURNS       SETOF api.notify_channel
AS $$
  SELECT * FROM api.notify_channel WHERE code = pCode;
$$ LANGUAGE sql STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_notify_channel ------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Change the delivery policy of a channel. NULL leaves the value in place.
 *        target_fn and on_abandon are not here on purpose: they name functions that
 *        run with the module's rights, and are set by the module's own scripts.
 * @param {text} pCode - Channel code (must exist)
 * @param {text} pMode - broadcast, single or legacy
 * @param {text} pAffinity - any, key or route
 * @param {interval} pGrace - Grace
 * @param {interval} pLease - Lease
 * @param {interval} pExpire - Expire
 * @param {integer} pMaxAttempts - Repeats allowed
 * @param {boolean} pResendEnabled - Emergency brake: false forbids every repeat
 * @param {boolean} pOnExpire - Call on_abandon for a row that never left
 * @param {boolean} pDedupe - One row per (channel, key)
 * @param {interval} pRetainDone - Retention of confirmed rows
 * @param {interval} pRetainClosed - Retention of closed rows
 * @param {interval} pAlive - Silence after which a subscriber is not chosen
 * @param {interval} pSweepEvery - The tick of notify.sweep
 * @return {SETOF api.notify_channel} - The channel after the change
 * @throws ERR-40000 - When there is no such channel
 * @since 1.2.37
 */
CREATE OR REPLACE FUNCTION api.set_notify_channel (
  pCode           text,
  pMode           text DEFAULT null,
  pAffinity       text DEFAULT null,
  pGrace          interval DEFAULT null,
  pLease          interval DEFAULT null,
  pExpire         interval DEFAULT null,
  pMaxAttempts    integer DEFAULT null,
  pResendEnabled  boolean DEFAULT null,
  pOnExpire       boolean DEFAULT null,
  pDedupe         boolean DEFAULT null,
  pRetainDone     interval DEFAULT null,
  pRetainClosed   interval DEFAULT null,
  pAlive          interval DEFAULT null,
  pSweepEvery     interval DEFAULT null
) RETURNS         SETOF api.notify_channel
AS $$
BEGIN
  UPDATE notify.channel
     SET mode = coalesce(pMode, mode),
         affinity = coalesce(pAffinity, affinity),
         grace = coalesce(pGrace, grace),
         lease = coalesce(pLease, lease),
         expire = coalesce(pExpire, expire),
         max_attempts = coalesce(pMaxAttempts, max_attempts),
         resend_enabled = coalesce(pResendEnabled, resend_enabled),
         on_expire = coalesce(pOnExpire, on_expire),
         dedupe = coalesce(pDedupe, dedupe),
         retain_done = coalesce(pRetainDone, retain_done),
         retain_closed = coalesce(pRetainClosed, retain_closed),
         alive = coalesce(pAlive, alive),
         sweep_every = coalesce(pSweepEvery, sweep_every),
         classified = true
   WHERE code = pCode;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'ERR-40000: Channel "%" not found.', pCode;
  END IF;

  RETURN QUERY SELECT * FROM api.notify_channel WHERE code = pCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.sweep_notify_channel ----------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Look over a channel -- the body of a job for a channel that may have no live
 *        subscriber (every holder of its rows is down): the waiting rows are closed
 *        by expire or as unrouted, the taken ones by lease, and the channel's
 *        on_abandon is called. It does only what notify.sweep of a subscriber
 *        would do, so calling it for a channel that has subscribers is harmless.
 * @param {text} pCode - Channel code
 * @param {integer} pLimit - Rows per kind per call
 * @return {integer} - Rows it acted on; 0 for an unknown channel
 * @since 1.2.37
 */
CREATE OR REPLACE FUNCTION api.sweep_notify_channel (
  pCode         text,
  pLimit        integer DEFAULT 100
) RETURNS       integer
AS $$
  SELECT notify.sweep_channel(pCode, pLimit);
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
