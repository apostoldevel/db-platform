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
