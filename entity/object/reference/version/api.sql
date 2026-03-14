--------------------------------------------------------------------------------
-- VERSION ---------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.version -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.version
AS
  SELECT * FROM ObjectVersion;

GRANT SELECT ON api.version TO administrator;

--------------------------------------------------------------------------------
-- api.add_version -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new version record via the API (defaults to 'api.version' type).
 * @param {uuid} pParent - Parent object or NULL
 * @param {uuid} pType - Version type (NULL = api.version)
 * @param {text} pCode - Unique business code
 * @param {text} pName - Version string
 * @param {text} pDescription - Optional description
 * @return {uuid} - ID of the created version
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.add_version (
  pParent       uuid,
  pType         uuid,
  pCode         text,
  pName         text,
  pDescription  text default null
) RETURNS       uuid
AS $$
BEGIN
  RETURN CreateVersion(pParent, coalesce(pType, GetType('api.version')), pCode, pName, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_version ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update an existing version record via the API.
 * @param {uuid} pId - Version to update
 * @param {uuid} pParent - New parent (NULL keeps current)
 * @param {uuid} pType - New type (NULL keeps current)
 * @param {text} pCode - New code (NULL keeps current)
 * @param {text} pName - New name (NULL keeps current)
 * @param {text} pDescription - New description (NULL keeps current)
 * @return {void}
 * @throws ObjectNotFound - When version with given ID does not exist
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.update_version (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pCode         text default null,
  pName         text default null,
  pDescription  text default null
) RETURNS       void
AS $$
DECLARE
  uVersion      uuid;
BEGIN
  SELECT t.id INTO uVersion FROM db.version t WHERE t.id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('version', 'id', pId);
  END IF;

  PERFORM EditVersion(uVersion, pParent, pType, pCode, pName, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_version -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Upsert a version: create when pId is NULL, otherwise update. Return the row.
 * @param {uuid} pId - Version ID (NULL = create new)
 * @param {uuid} pParent - Parent object or NULL
 * @param {uuid} pType - Version type
 * @param {text} pCode - Business code
 * @param {text} pName - Version string
 * @param {text} pDescription - Optional description
 * @return {SETOF api.version} - The created or updated version row
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.set_version (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pCode         text default null,
  pName         text default null,
  pDescription  text default null
) RETURNS       SETOF api.version
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_version(pParent, pType, pCode, pName, pDescription);
  ELSE
    PERFORM api.update_version(pId, pParent, pType, pCode, pName, pDescription);
  END IF;

  RETURN QUERY SELECT * FROM api.version WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_version -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve a single version by ID (with access check).
 * @param {uuid} pId - Version ID
 * @return {SETOF api.version} - Matching row or empty set
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_version (
  pId       uuid
) RETURNS   SETOF api.version
AS $$
  SELECT * FROM api.version WHERE id = pId AND CheckObjectAccess(id, B'100')
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_version ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List versions with optional search, filter, and pagination.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Exact-match filter object
 * @param {integer} pLimit - Maximum rows to return
 * @param {integer} pOffSet - Rows to skip
 * @param {jsonb} pOrderBy - Sort fields array
 * @return {SETOF api.version} - Matching rows
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_version (
  pSearch   jsonb default null,
  pFilter   jsonb default null,
  pLimit    integer default null,
  pOffSet   integer default null,
  pOrderBy  jsonb default null
) RETURNS   SETOF api.version
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'version', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_version_id ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Resolve a version ID from a code or UUID string.
 * @param {text} pCode - Version code or UUID
 * @return {uuid} - Version ID
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_version_id (
  pCode     text
) RETURNS   uuid
AS $$
BEGIN
  IF length(pCode) = 36 AND SubStr(pCode, 15, 1) = '4' THEN
    RETURN pCode;
  END IF;

  RETURN GetVersion(pCode);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
