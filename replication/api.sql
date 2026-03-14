--------------------------------------------------------------------------------
-- REPLICATION -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.replication_log
AS
  SELECT * FROM replication.log;

GRANT SELECT ON api.replication_log TO administrator;
GRANT SELECT ON api.replication_log TO apibot;

--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.relay_log
AS
  SELECT * FROM replication.relay;

GRANT SELECT ON api.relay_log TO administrator;
GRANT SELECT ON api.relay_log TO apibot;

--------------------------------------------------------------------------------
-- api.replication_log ---------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Fetch replication log entries after a given ID, excluding a specific source.
 * @param {bigint} pFrom - Log entry ID to start from (exclusive)
 * @param {text} pSource - Source instance to exclude from results
 * @param {int} pLimit - Maximum number of entries to return (default 500)
 * @return {SETOF api.replication_log} - Matching log entries
 * @see replication.log
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.replication_log (
  pFrom         bigint,
  pSource       text,
  pLimit        int DEFAULT 500
) RETURNS       SETOF api.replication_log
AS $$
  SELECT * FROM replication.log(pFrom, pSource, coalesce(pLimit, 500));
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_max_log_id ----------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Retrieve the maximum log entry ID from the replication log.
 * @return {bigint} - Highest log ID, or NULL if the log is empty
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_max_log_id()
RETURNS         bigint
AS $$
  SELECT max(id) FROM replication.log;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_max_relay_id --------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Retrieve the maximum relay entry ID for a given source instance.
 * @param {text} pSource - Originating instance identifier
 * @return {bigint} - Highest relay ID for the source, or NULL if none exist
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_max_relay_id (
  pSource   text
) RETURNS   bigint
AS $$
  SELECT max(id) FROM replication.relay WHERE source = pSource;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.add_to_relay_log --------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Add an entry to the relay log for deferred application from a remote instance.
 * @param {text} pSource - Originating instance identifier
 * @param {bigint} pId - Log entry ID from the source instance
 * @param {timestamptz} pDateTime - Original timestamp of the change
 * @param {char} pAction - DML action: I = INSERT, U = UPDATE, D = DELETE
 * @param {text} pSchema - Target table schema
 * @param {text} pName - Target table name
 * @param {jsonb} pKey - Primary key columns for row identification
 * @param {jsonb} pData - Row data to apply
 * @param {bool} pProxy - When TRUE, re-log the entry for further relay
 * @return {bigint} - The relay entry ID
 * @see replication.add_relay
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.add_to_relay_log (
  pSource       text,
  pId           bigint,
  pDateTime     timestamptz,
  pAction       char,
  pSchema       text,
  pName         text,
  pKey          jsonb,
  pData         jsonb,
  pProxy        bool DEFAULT false
) RETURNS       bigint
AS $$
BEGIN
  RETURN replication.add_relay(pSource, pId, pDateTime, pAction, pSchema, pName, pKey, pData, pProxy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_replication_log -----------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Retrieve a single replication log entry by ID.
 * @param {bigint} pId - Log entry identifier
 * @return {SETOF api.replication_log} - The matching log entry
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_replication_log (
  pId       bigint
) RETURNS   SETOF api.replication_log
AS $$
  SELECT * FROM api.replication_log WHERE id = pId;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_replication_log ----------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief List replication log entries with optional search, filter, and pagination.
 * @param {jsonb} pSearch - Full-text search criteria
 * @param {jsonb} pFilter - Column-level filter conditions
 * @param {integer} pLimit - Maximum number of rows to return
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Sort specification
 * @return {SETOF api.replication_log} - Matching log entries
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_replication_log (
  pSearch       jsonb default null,
  pFilter       jsonb default null,
  pLimit        integer default null,
  pOffSet       integer default null,
  pOrderBy      jsonb default null
) RETURNS       SETOF api.replication_log
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'replication_log', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_relay_log ----------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief List relay log entries with optional search, filter, and pagination.
 * @param {jsonb} pSearch - Full-text search criteria
 * @param {jsonb} pFilter - Column-level filter conditions
 * @param {integer} pLimit - Maximum number of rows to return
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Sort specification
 * @return {SETOF api.relay_log} - Matching relay entries
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_relay_log (
  pSearch       jsonb default null,
  pFilter       jsonb default null,
  pLimit        integer default null,
  pOffSet       integer default null,
  pOrderBy      jsonb default null
) RETURNS       SETOF api.relay_log
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'relay_log', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.replication_apply_relay -------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Apply a single relay entry and return the result message.
 * @param {text} pSource - Originating instance identifier
 * @param {bigint} pId - Relay entry ID to apply
 * @return {text} - Result message (e.g. "Success" or error description)
 * @see replication.apply_relay
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.replication_apply_relay (
  pSource       text,
  pId           bigint
) RETURNS       text
AS $$
  SELECT GetErrorMessage() FROM replication.apply_relay(pSource, pId)
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.replication_apply -------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Apply all pending relay entries for a given source instance.
 * @param {text} pSource - Originating instance identifier
 * @return {int} - Number of relay entries processed
 * @see replication.apply
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.replication_apply (
  pSource       text
)
RETURNS         int
AS $$
BEGIN
  RETURN replication.apply(pSource);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
