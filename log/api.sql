--------------------------------------------------------------------------------
-- EVENT LOG -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.event_log
AS
  SELECT * FROM EventLog;

GRANT SELECT ON api.event_log TO administrator;

--------------------------------------------------------------------------------
-- api.event_log ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Filter event log entries by username, type, code, and date range.
 * @param {text} pUserName - Login name to filter by (null = all users)
 * @param {char} pType - Event severity filter: M=message, W=warning, E=error, D=debug
 * @param {integer} pCode - Application-defined event code filter
 * @param {timestamptz} pDateFrom - Start of the date range (inclusive)
 * @param {timestamptz} pDateTo - End of the date range (exclusive)
 * @return {SETOF api.event_log} - Matching log entries, max 500, newest first
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.event_log (
  pUserName      text DEFAULT null,
  pType          char DEFAULT null,
  pCode          integer DEFAULT null,
  pDateFrom      timestamptz DEFAULT null,
  pDateTo        timestamptz DEFAULT null
) RETURNS        SETOF api.event_log
AS $$
  SELECT *
    FROM api.event_log
   WHERE username = coalesce(pUserName, username)
     AND type = coalesce(pType, type)
     AND code = coalesce(pCode, code)
     AND datetime >= coalesce(pDateFrom, MINDATE())
     AND datetime < coalesce(pDateTo, MAXDATE())
   ORDER BY datetime DESC, id
   LIMIT 500
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.write_to_log ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Write a custom event to the log via the API and return the created entry.
 * @param {text} pType - Event severity: M=message, W=warning, E=error
 * @param {integer} pCode - Application-defined numeric event code
 * @param {text} pText - Human-readable event description
 * @return {SETOF api.event_log} - The newly created log entry
 * @see AddEventLog
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.write_to_log (
  pType         text,
  pCode         integer,
  pText         text
) RETURNS       SETOF api.event_log
AS $$
DECLARE
  nId           bigint;
BEGIN
  nId := AddEventLog(pType, pCode, 'api', pText);
  RETURN QUERY SELECT * FROM api.get_event_log(nId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_event_log -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Fetch a single event log entry by its identifier.
 * @param {bigint} pId - Unique event log identifier
 * @return {SETOF api.event_log} - The matching log entry (one row or empty)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_event_log (
  pId       bigint
) RETURNS   SETOF api.event_log
AS $$
  SELECT * FROM api.event_log WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_event_log ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List event log entries with dynamic search, filtering, pagination, and sorting.
 * @param {jsonb} pSearch - Search conditions: [{"condition": "AND|OR", "field": "<col>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<val>"}]
 * @param {jsonb} pFilter - Equality filter: {"<column>": "<value>"}
 * @param {integer} pLimit - Maximum number of rows to return
 * @param {integer} pOffSet - Number of rows to skip before returning results
 * @param {jsonb} pOrderBy - Array of column names to sort by
 * @return {SETOF api.event_log} - Matching log entries
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_event_log (
  pSearch    jsonb DEFAULT null,
  pFilter    jsonb DEFAULT null,
  pLimit     integer DEFAULT null,
  pOffSet    integer DEFAULT null,
  pOrderBy   jsonb DEFAULT null
) RETURNS    SETOF api.event_log
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'event_log', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- USER EVENT LOG --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.user_log
AS
  WITH cu AS (
    SELECT current_username() AS username
  )
  SELECT el.* FROM EventLog el INNER JOIN cu ON el.username = cu.username;

GRANT SELECT ON api.user_log TO administrator;

--------------------------------------------------------------------------------
-- api.user_log ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Filter the current user's event log by type, code, and date range.
 * @param {char} pType - Event severity filter: M=message, W=warning, E=error, D=debug
 * @param {integer} pCode - Application-defined event code filter
 * @param {timestamptz} pDateFrom - Start of the date range (inclusive)
 * @param {timestamptz} pDateTo - End of the date range (exclusive)
 * @return {SETOF api.user_log} - Matching entries for the current user, max 500, newest first
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.user_log (
  pType         char DEFAULT null,
  pCode         integer DEFAULT null,
  pDateFrom     timestamptz DEFAULT null,
  pDateTo       timestamptz DEFAULT null
) RETURNS       SETOF api.user_log
AS $$
  SELECT *
    FROM api.user_log
   WHERE type = coalesce(pType, type)
     AND code = coalesce(pCode, code)
     AND datetime >= coalesce(pDateFrom, MINDATE())
     AND datetime < coalesce(pDateTo, MAXDATE())
   ORDER BY datetime DESC, id
   LIMIT 500
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_user_log ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Fetch a single event log entry for the current user by its identifier.
 * @param {bigint} pId - Unique event log identifier
 * @return {SETOF api.user_log} - The matching log entry (one row or empty)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_user_log (
  pId       bigint
) RETURNS   SETOF api.user_log
AS $$
  SELECT * FROM api.user_log WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_user_log -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List current user's log entries with dynamic search, filtering, pagination, and sorting.
 * @param {jsonb} pSearch - Search conditions: [{"condition": "AND|OR", "field": "<col>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<val>"}]
 * @param {jsonb} pFilter - Equality filter: {"<column>": "<value>"}
 * @param {integer} pLimit - Maximum number of rows to return
 * @param {integer} pOffSet - Number of rows to skip before returning results
 * @param {jsonb} pOrderBy - Array of column names to sort by
 * @return {SETOF api.user_log} - Matching log entries for the current user
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_user_log (
  pSearch    jsonb DEFAULT null,
  pFilter    jsonb DEFAULT null,
  pLimit     integer DEFAULT null,
  pOffSet    integer DEFAULT null,
  pOrderBy   jsonb DEFAULT null
) RETURNS    SETOF api.user_log
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'user_log', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
