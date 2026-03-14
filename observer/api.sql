--------------------------------------------------------------------------------
-- OBSERVER --------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.publisher ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Expose all registered publishers as a read-only API view.
 * @since 1.0.0
 */
CREATE OR REPLACE VIEW api.publisher
AS
  SELECT * FROM Publisher;

GRANT SELECT ON api.publisher TO administrator;

--------------------------------------------------------------------------------
-- api.publisher ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Look up a single publisher by its code.
 * @param {text} pCode - Publisher code
 * @return {SETOF api.publisher}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.publisher (
  pCode         text
) RETURNS       SETOF api.publisher
AS $$
  SELECT * FROM api.publisher WHERE code = pCode;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_publisher -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve a single publisher by its code.
 * @param {text} pCode - Publisher code
 * @return {SETOF api.publisher}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_publisher (
  pCode     text
) RETURNS   SETOF api.publisher
AS $$
  SELECT * FROM api.publisher WHERE code = pCode;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_publisher ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List publishers with optional search, filter, pagination, and sorting.
 * @param {jsonb} pSearch - Search condition: '[{"condition": "AND|OR", "field": "<col>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<val>"}]'
 * @param {jsonb} pFilter - Equality filter: '{"<col>": "<val>"}'
 * @param {integer} pLimit - Maximum number of rows to return
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Array of column names to sort by
 * @return {SETOF api.publisher}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_publisher (
  pSearch       jsonb DEFAULT null,
  pFilter       jsonb DEFAULT null,
  pLimit        integer DEFAULT null,
  pOffSet       integer DEFAULT null,
  pOrderBy      jsonb DEFAULT null
) RETURNS       SETOF api.publisher
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'publisher', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.listener ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Expose all listener subscriptions as a read-only API view.
 * @since 1.0.0
 */
CREATE OR REPLACE VIEW api.listener
AS
  SELECT * FROM Listener;

GRANT SELECT ON api.listener TO administrator;

--------------------------------------------------------------------------------
-- api.listener ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Look up a single listener by publisher, session, and identity.
 * @param {text} pPublisher - Publisher code
 * @param {varchar} pSession - Session code
 * @param {text} pIdentity - Subscription identity
 * @return {SETOF api.listener}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.listener (
  pPublisher    text,
  pSession      varchar,
  pIdentity     text
) RETURNS       SETOF api.listener
AS $$
  SELECT * FROM api.listener WHERE publisher = pPublisher AND session = pSession AND identity = pIdentity
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.add_listener ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new listener subscription for a publisher.
 * @param {text} pPublisher - Publisher code to subscribe to
 * @param {varchar} pSession - Session code that owns the subscription
 * @param {text} pIdentity - Logical subscription name within the session
 * @param {jsonb} pFilter - JSON filter criteria for event matching
 * @param {jsonb} pParams - Delivery parameters (type, optional hook config)
 * @return {void}
 * @see api.update_listener, api.set_listener
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.add_listener (
  pPublisher    text,
  pSession    	varchar,
  pIdentity		text,
  pFilter		jsonb,
  pParams		jsonb
) RETURNS		void
AS $$
BEGIN
  PERFORM CreateListener(pPublisher, pSession, pIdentity, pFilter, pParams);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_listener ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update filter and params of an existing listener subscription.
 * @param {text} pPublisher - Publisher code
 * @param {varchar} pSession - Session code
 * @param {text} pIdentity - Subscription identity
 * @param {jsonb} pFilter - New JSON filter criteria
 * @param {jsonb} pParams - New delivery parameters
 * @return {boolean} - true if a matching listener was found and updated
 * @see api.add_listener, api.set_listener
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.update_listener (
  pPublisher	text,
  pSession		varchar,
  pIdentity		text,
  pFilter		jsonb,
  pParams		jsonb
) RETURNS		boolean
AS $$
BEGIN
  RETURN EditListener(pPublisher, pSession, pIdentity, pFilter, pParams);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_listener ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Upsert a listener: update if exists, otherwise create, then return the result.
 * @param {text} pPublisher - Publisher code
 * @param {varchar} pSession - Session code
 * @param {text} pIdentity - Subscription identity
 * @param {jsonb} pFilter - JSON filter criteria
 * @param {jsonb} pParams - Delivery parameters
 * @return {SETOF api.listener} - The created or updated listener record
 * @see api.add_listener, api.update_listener
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.set_listener (
  pPublisher	text,
  pSession		varchar,
  pIdentity		text,
  pFilter		jsonb,
  pParams		jsonb
) RETURNS       SETOF api.listener
AS $$
BEGIN
  IF NOT api.update_listener(pPublisher, pSession, pIdentity, pFilter, pParams) THEN
    PERFORM api.add_listener(pPublisher, pSession, pIdentity, pFilter, pParams);
  END IF;

  RETURN QUERY SELECT * FROM api.get_listener(pPublisher, pSession, pIdentity);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_listener ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve a single listener by publisher, session, and identity.
 * @param {text} pPublisher - Publisher code
 * @param {varchar} pSession - Session code
 * @param {text} pIdentity - Subscription identity
 * @return {SETOF api.listener}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_listener (
  pPublisher	text,
  pSession		varchar,
  pIdentity		text
) RETURNS       SETOF api.listener
AS $$
  SELECT * FROM api.listener(pPublisher, pSession, pIdentity);
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_listener -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List listeners with optional search, filter, pagination, and sorting.
 * @param {jsonb} pSearch - Search condition: '[{"condition": "AND|OR", "field": "<col>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<val>"}]'
 * @param {jsonb} pFilter - Equality filter: '{"<col>": "<val>"}'
 * @param {integer} pLimit - Maximum number of rows to return
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Array of column names to sort by
 * @return {SETOF api.listener}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_listener (
  pSearch		jsonb DEFAULT null,
  pFilter		jsonb DEFAULT null,
  pLimit		integer DEFAULT null,
  pOffSet		integer DEFAULT null,
  pOrderBy		jsonb DEFAULT null
) RETURNS		SETOF api.listener
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'listener', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.subscribe_observer ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Subscribe to a publisher using the current or specified session.
 * @param {text} pPublisher - Publisher code to subscribe to
 * @param {varchar} pSession - Session code (defaults to current session)
 * @param {text} pIdentity - Logical subscription name within the session
 * @param {jsonb} pFilter - JSON filter criteria for event matching
 * @param {jsonb} pParams - Delivery parameters (type, optional hook config)
 * @return {SETOF api.listener} - The created or updated listener record
 * @see api.unsubscribe_observer, api.set_listener
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.subscribe_observer (
  pPublisher	text,
  pSession		varchar,
  pIdentity		text,
  pFilter		jsonb,
  pParams		jsonb
) RETURNS		SETOF api.listener
AS $$
BEGIN
  RETURN QUERY SELECT * FROM api.set_listener(pPublisher, coalesce(pSession, current_session()), pIdentity, pFilter, pParams);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.unsubscribe_observer ----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Unsubscribe from a publisher by removing the listener record.
 * @param {text} pPublisher - Publisher code to unsubscribe from
 * @param {varchar} pSession - Session code (defaults to current session)
 * @param {text} pIdentity - Subscription identity to remove
 * @return {boolean} - true if a matching listener was found and deleted
 * @see api.subscribe_observer
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.unsubscribe_observer (
  pPublisher	text,
  pSession		varchar,
  pIdentity		text
) RETURNS		boolean
AS $$
BEGIN
  RETURN DeleteListener(pPublisher, coalesce(pSession, current_session()), pIdentity);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
