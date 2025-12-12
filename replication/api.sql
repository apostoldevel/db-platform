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
