--------------------------------------------------------------------------------
-- RESOURCE --------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.resource ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.resource
AS
  SELECT * FROM Resource;

GRANT SELECT ON api.resource TO administrator;

--------------------------------------------------------------------------------
-- api.resource_tree -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.resource_tree
AS
  SELECT * FROM ResourceTree;

GRANT SELECT ON api.resource_tree TO administrator;

--------------------------------------------------------------------------------
-- api.create_resource ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new resource node via the public API.
 * @param {uuid} pId - Explicit UUID or NULL to auto-generate
 * @param {uuid} pRoot - Root node of the tree (NULL to start a new tree)
 * @param {uuid} pNode - Parent node in the hierarchy
 * @param {text} pType - MIME type of the content
 * @param {text} pName - Human-readable name / key
 * @param {text} pDescription - Longer description or label
 * @param {text} pEncoding - Character encoding of the data payload
 * @param {text} pData - Actual content payload
 * @param {integer} pSequence - Sort position among siblings
 * @param {text} pLocaleCode - ISO locale code (e.g. 'en', 'ru')
 * @return {uuid} - ID of the newly created resource
 * @throws IncorrectLocaleCode - When pLocaleCode does not match any known locale
 * @see CreateResource
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.create_resource (
  pId           uuid,
  pRoot         uuid,
  pNode         uuid,
  pType         text,
  pName         text,
  pDescription  text DEFAULT null,
  pEncoding     text DEFAULT null,
  pData         text DEFAULT null,
  pSequence     integer DEFAULT null,
  pLocaleCode   text DEFAULT locale_code()
) RETURNS       uuid
AS $$
DECLARE
  uLocale        uuid;
BEGIN
  SELECT id INTO uLocale FROM db.locale WHERE code = pLocaleCode;

  IF NOT FOUND THEN
    PERFORM IncorrectLocaleCode(pLocaleCode);
  END IF;

  RETURN CreateResource(pId, pRoot, pNode, pType, pName, pDescription, pEncoding, pData, pSequence, uLocale);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_resource ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update an existing resource node via the public API.
 * @param {uuid} pId - Resource to update
 * @param {uuid} pRoot - New root node (NULL to keep current)
 * @param {uuid} pNode - New parent node (NULL to keep current)
 * @param {text} pType - New MIME type (NULL to keep current)
 * @param {text} pName - New name (NULL to keep current)
 * @param {text} pDescription - New description (NULL to keep current)
 * @param {text} pEncoding - New encoding (NULL to keep current)
 * @param {text} pData - New content payload (NULL to keep current)
 * @param {integer} pSequence - New sort position (NULL to keep current)
 * @param {text} pLocaleCode - ISO locale code (e.g. 'en', 'ru')
 * @return {void}
 * @throws IncorrectLocaleCode - When pLocaleCode does not match any known locale
 * @see UpdateResource
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.update_resource (
  pId           uuid,
  pRoot         uuid DEFAULT null,
  pNode         uuid DEFAULT null,
  pType         text DEFAULT null,
  pName         text DEFAULT null,
  pDescription  text DEFAULT null,
  pEncoding     text DEFAULT null,
  pData         text DEFAULT null,
  pSequence     integer DEFAULT null,
  pLocaleCode   text DEFAULT locale_code()
) RETURNS       void
AS $$
DECLARE
  uLocale       uuid;
BEGIN
  SELECT id INTO uLocale FROM db.locale WHERE code = pLocaleCode;

  IF NOT FOUND THEN
    PERFORM IncorrectLocaleCode(pLocaleCode);
  END IF;

  PERFORM UpdateResource(pId, pRoot, pNode, pType, pName, pDescription, pEncoding, pData, pSequence, uLocale);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_resource ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create or update a resource node (upsert) and return the full row.
 * @param {uuid} pId - Resource ID (NULL to create new)
 * @param {uuid} pRoot - Root node of the tree
 * @param {uuid} pNode - Parent node in the hierarchy
 * @param {text} pType - MIME type of the content
 * @param {text} pName - Human-readable name / key
 * @param {text} pDescription - Longer description or label
 * @param {text} pEncoding - Character encoding of the data payload
 * @param {text} pData - Actual content payload
 * @param {integer} pSequence - Sort position among siblings
 * @param {text} pLocaleCode - ISO locale code (e.g. 'en', 'ru')
 * @return {SETOF api.resource} - The created or updated resource row
 * @throws IncorrectLocaleCode - When pLocaleCode does not match any known locale
 * @see SetResource
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.set_resource (
  pId           uuid,
  pRoot         uuid DEFAULT null,
  pNode         uuid DEFAULT null,
  pType         text DEFAULT null,
  pName         text DEFAULT null,
  pDescription  text DEFAULT null,
  pEncoding     text DEFAULT null,
  pData         text DEFAULT null,
  pSequence     integer DEFAULT null,
  pLocaleCode   text DEFAULT locale_code()
) RETURNS       SETOF api.resource
AS $$
DECLARE
  uLocale       uuid;
  uResource     uuid;
BEGIN
  SELECT id INTO uLocale FROM db.locale WHERE code = pLocaleCode;

  IF NOT FOUND THEN
    PERFORM IncorrectLocaleCode(pLocaleCode);
  END IF;

  uResource := SetResource(pId, pRoot, pNode, pType, pName, pDescription, pEncoding, pData, pSequence, uLocale);

  RETURN QUERY SELECT * FROM api.resource WHERE id = uResource;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_resource ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Fetch a single resource by ID.
 * @param {uuid} pId - Resource to retrieve
 * @return {SETOF api.resource} - Matching resource row
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_resource (
  pId       uuid
) RETURNS   SETOF api.resource
AS $$
  SELECT * FROM api.resource WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.delete_resource ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Delete a resource node by ID.
 * @param {uuid} pId - Resource to delete
 * @return {void}
 * @see DeleteResource
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.delete_resource (
  pId       uuid
) RETURNS   void
AS $$
BEGIN
  PERFORM DeleteResource(pId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.count_resource ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Count resource records matching search/filter criteria.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Exact-match filter object
 * @return {SETOF bigint} - Record count
 * @since 1.2.1
 */
CREATE OR REPLACE FUNCTION api.count_resource (
  pSearch    jsonb default null,
  pFilter    jsonb default null
) RETURNS    SETOF bigint
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'resource', pSearch, pFilter, 0, null, '{}'::jsonb, '["count(id)"]'::jsonb);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_resource -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List resources with optional search, filter, pagination, and sorting.
 * @param {jsonb} pSearch - Search conditions: '[{"condition": "AND|OR", "field": "<col>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<val>"}, ...]'
 * @param {jsonb} pFilter - Equality filter: '{"<col>": "<val>"}'
 * @param {integer} pLimit - Maximum number of rows to return
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Columns to sort by (JSON array)
 * @return {SETOF api.resource} - Matching resource rows
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_resource (
  pSearch   jsonb default null,
  pFilter   jsonb default null,
  pLimit    integer default null,
  pOffSet   integer default null,
  pOrderBy  jsonb default null
) RETURNS   SETOF api.resource
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'resource', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
