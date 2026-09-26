--------------------------------------------------------------------------------
-- NOTIFICATION ----------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.notification ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.notification
AS
  SELECT * FROM Notification;

GRANT SELECT ON api.notification TO administrator;

--------------------------------------------------------------------------------
-- api.notification ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve notifications since a given timestamp with access control.
 * @param {timestamptz} pDateFrom - Start timestamp (inclusive)
 * @param {uuid} pUserId - User whose permissions are checked; defaults to current session user
 * @return {SETOF api.notification} - Accessible notification rows
 * @see Notification
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.notification (
  pDateFrom     timestamptz,
  pUserId       uuid DEFAULT current_userid()
) RETURNS       SETOF api.notification
AS $$
  SELECT * FROM Notification(pDateFrom, pUserId);
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_notification --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve a single notification by identifier.
 * @param {uuid} pId - Notification identifier
 * @return {SETOF api.notification} - Matching notification row
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_notification (
  pId       uuid
) RETURNS   SETOF api.notification
AS $$
  SELECT * FROM api.notification WHERE id = pId;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.count_notification ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Count notification records matching search/filter criteria.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Exact-match filter object
 * @return {SETOF bigint} - Record count
 * @since 1.2.1
 */
CREATE OR REPLACE FUNCTION api.count_notification (
  pSearch    jsonb default null,
  pFilter    jsonb default null
) RETURNS    SETOF bigint
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'notification', pSearch, pFilter, 0, null, '{}'::jsonb, '["count(id)"]'::jsonb);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_notification -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List notifications with dynamic search, filter, and pagination.
 * @param {jsonb} pSearch - Search conditions: '[{"condition": "AND|OR", "field": "<col>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<val>"}]'
 * @param {jsonb} pFilter - Simple key-value filter: '{"<col>": "<val>"}'
 * @param {integer} pLimit - Maximum number of rows to return
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Array of column names to sort by
 * @return {SETOF api.notification} - Matching notification rows
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_notification (
  pSearch        jsonb DEFAULT null,
  pFilter        jsonb DEFAULT null,
  pLimit         integer DEFAULT null,
  pOffSet        integer DEFAULT null,
  pOrderBy       jsonb DEFAULT null
) RETURNS        SETOF api.notification
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'notification', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- MY NOTIFICATIONS ------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.my_notification (view) --------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief The notifications the current user may read: an administrator reads
 *        all, anyone else those about objects CheckObjectAccess lets him read.
 *        api.notification is unfiltered (an administrator's view), and the
 *        AOU of Notification() alone is granted per group — a group spans
 *        companies — so the read goes through CheckObjectAccess (AOU and the
 *        class mask) and CheckObjectArea (the area: what separates tenants
 *        on the platform), as get_object_file does; a configuration may add
 *        its own barrier to CheckObjectAccess. security_barrier keeps the
 *        caller's search and filter above the access condition.
 *
 *        A member of system and a session on the apibot or kernel connection
 *        pass CheckObjectAccess and read everything: on /api/v2 the route
 *        guards keep system out, and /api/v1 has no route to this view.
 *        count and an unbounded list scan the whole journal — give a date
 *        (datetime) when the journal is large. For a caller that is not an
 *        administrator: /api/v2 (1.2.31).
 * @since 1.2.31
 */
CREATE OR REPLACE VIEW api.my_notification WITH (security_barrier)
AS
  SELECT n.*
    FROM Notification n
   WHERE (SELECT IsAdmin()) OR (CheckObjectAccess(n.object, B'100') AND CheckObjectArea(n.object));

--------------------------------------------------------------------------------
-- api.my_notification ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief The current user's notifications since a moment — api.notification
 *        without a user argument: the user is the session's.
 * @param {timestamptz} pDateFrom - Start timestamp (inclusive)
 * @return {SETOF api.my_notification}
 * @since 1.2.31
 */
CREATE OR REPLACE FUNCTION api.my_notification (
  pDateFrom     timestamptz
) RETURNS       SETOF api.my_notification
AS $$
BEGIN
  RETURN QUERY SELECT * FROM api.my_notification WHERE datetime >= pDateFrom;
END;
$$ LANGUAGE plpgsql STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_my_notification -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief One notification of the current user by id.
 * @param {uuid} pId - Notification identifier
 * @return {SETOF api.my_notification}
 * @since 1.2.31
 */
CREATE OR REPLACE FUNCTION api.get_my_notification (
  pId           uuid
) RETURNS       SETOF api.my_notification
AS $$
BEGIN
  RETURN QUERY SELECT * FROM api.my_notification WHERE id = pId;
END;
$$ LANGUAGE plpgsql STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.count_my_notification ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Count the current user's notifications.
 * @param {jsonb} pSearch - Search conditions
 * @param {jsonb} pFilter - Filter: '{"<field>": "<value>"}'
 * @return {SETOF bigint}
 * @since 1.2.31
 */
CREATE OR REPLACE FUNCTION api.count_my_notification (
  pSearch       jsonb DEFAULT null,
  pFilter       jsonb DEFAULT null
) RETURNS       SETOF bigint
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'my_notification', pSearch, pFilter, 0, null, '{}'::jsonb, '["count(id)"]'::jsonb);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_my_notification ----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List the current user's notifications.
 * @param {jsonb} pSearch - Search conditions
 * @param {jsonb} pFilter - Filter: '{"<field>": "<value>"}'
 * @param {integer} pLimit - Maximum number of rows to return
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Sort by the fields specified in the array
 * @return {SETOF api.my_notification}
 * @since 1.2.31
 */
CREATE OR REPLACE FUNCTION api.list_my_notification (
  pSearch       jsonb DEFAULT null,
  pFilter       jsonb DEFAULT null,
  pLimit        integer DEFAULT null,
  pOffSet       integer DEFAULT null,
  pOrderBy      jsonb DEFAULT null
) RETURNS       SETOF api.my_notification
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'my_notification', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- OBJECT METHOD HISTORY -------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.object_method_history ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.object_method_history
AS
  SELECT * FROM ObjectMethodHistory;

GRANT SELECT ON api.object_method_history TO administrator;

--------------------------------------------------------------------------------
-- api.get_object_method_history -----------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the method execution history for a specific object.
 * @param {uuid} pId - Object identifier
 * @return {SETOF api.object_method_history} - History rows for the object
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_object_method_history (
  pId       uuid
) RETURNS   SETOF api.object_method_history
AS $$
  SELECT * FROM api.object_method_history WHERE id = pId;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.count_object_method_history ---------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Count object method history records matching search/filter criteria.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Exact-match filter object
 * @return {SETOF bigint} - Record count
 * @since 1.2.1
 */
CREATE OR REPLACE FUNCTION api.count_object_method_history (
  pSearch    jsonb default null,
  pFilter    jsonb default null
) RETURNS    SETOF bigint
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'object_method_history', pSearch, pFilter, 0, null, '{}'::jsonb, '["count(id)"]'::jsonb);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_object_method_history ----------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List method execution history with dynamic search, filter, and pagination.
 * @param {jsonb} pSearch - Search conditions
 * @param {jsonb} pFilter - Simple key-value filter
 * @param {integer} pLimit - Maximum number of rows to return
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Array of column names to sort by
 * @return {SETOF api.object_method_history} - Matching history rows
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_object_method_history (
  pSearch   jsonb DEFAULT null,
  pFilter   jsonb DEFAULT null,
  pLimit    integer DEFAULT null,
  pOffSet   integer DEFAULT null,
  pOrderBy  jsonb DEFAULT null
) RETURNS   SETOF api.object_method_history
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'object_method_history', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
