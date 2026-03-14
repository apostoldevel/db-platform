--------------------------------------------------------------------------------
-- AGENT -----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.agent -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.agent
AS
  SELECT * FROM ObjectAgent;

GRANT SELECT ON api.agent TO administrator;

--------------------------------------------------------------------------------
-- api.add_agent ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new delivery agent via the API (defaults to 'system.agent' type).
 * @param {uuid} pParent - Parent object or NULL
 * @param {uuid} pType - Agent type (NULL = system.agent)
 * @param {uuid} pVendor - Vendor that provides this agent
 * @param {text} pCode - Unique business code
 * @param {text} pName - Display name
 * @param {text} pDescription - Optional description
 * @return {uuid} - ID of the created agent
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.add_agent (
  pParent       uuid,
  pType         uuid,
  pVendor       uuid,
  pCode         text,
  pName         text,
  pDescription  text default null
) RETURNS       uuid
AS $$
BEGIN
  RETURN CreateAgent(pParent, coalesce(pType, GetType('system.agent')), pVendor, pCode, pName, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_agent ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update an existing delivery agent via the API.
 * @param {uuid} pId - Agent to update
 * @param {uuid} pParent - New parent (NULL keeps current)
 * @param {uuid} pType - New type (NULL keeps current)
 * @param {uuid} pVendor - New vendor (NULL keeps current)
 * @param {text} pCode - New code (NULL keeps current)
 * @param {text} pName - New name (NULL keeps current)
 * @param {text} pDescription - New description (NULL keeps current)
 * @return {void}
 * @throws ObjectNotFound - When agent with given ID does not exist
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.update_agent (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pVendor       uuid default null,
  pCode         text default null,
  pName         text default null,
  pDescription  text default null
) RETURNS       void
AS $$
DECLARE
  uAgent        uuid;
BEGIN
  SELECT t.id INTO uAgent FROM db.agent t WHERE t.id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('агент', 'id', pId);
  END IF;

  PERFORM EditAgent(uAgent, pParent, pType, pVendor, pCode, pName, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_agent ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Upsert an agent: create when pId is NULL, otherwise update. Return the row.
 * @param {uuid} pId - Agent ID (NULL = create new)
 * @param {uuid} pParent - Parent object or NULL
 * @param {uuid} pType - Agent type
 * @param {uuid} pVendor - Vendor
 * @param {text} pCode - Business code
 * @param {text} pName - Display name
 * @param {text} pDescription - Optional description
 * @return {SETOF api.agent} - The created or updated agent row
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.set_agent (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pVendor       uuid default null,
  pCode         text default null,
  pName         text default null,
  pDescription  text default null
) RETURNS       SETOF api.agent
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_agent(pParent, pType, pVendor, pCode, pName, pDescription);
  ELSE
    PERFORM api.update_agent(pId, pParent, pType, pVendor, pCode, pName, pDescription);
  END IF;

  RETURN QUERY SELECT * FROM api.agent WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_agent ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve a single agent by ID (with access check).
 * @param {uuid} pId - Agent ID
 * @return {SETOF api.agent} - Matching row or empty set
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_agent (
  pId       uuid
) RETURNS   SETOF api.agent
AS $$
  SELECT * FROM api.agent WHERE id = pId AND CheckObjectAccess(id, B'100')
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_agent --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List agents with optional search, filter, and pagination.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Exact-match filter object
 * @param {integer} pLimit - Maximum rows to return
 * @param {integer} pOffSet - Rows to skip
 * @param {jsonb} pOrderBy - Sort fields array
 * @return {SETOF api.agent} - Matching rows
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_agent (
  pSearch   jsonb default null,
  pFilter   jsonb default null,
  pLimit    integer default null,
  pOffSet   integer default null,
  pOrderBy  jsonb default null
) RETURNS   SETOF api.agent
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'agent', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_agent_id ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Resolve an agent ID from a code or UUID string.
 * @param {text} pCode - Agent code or UUID
 * @return {uuid} - Agent ID
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_agent_id (
  pCode     text
) RETURNS   uuid
AS $$
BEGIN
  IF length(pCode) = 36 AND SubStr(pCode, 15, 1) = '4' THEN
    RETURN pCode;
  END IF;

  RETURN GetAgent(pCode);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
