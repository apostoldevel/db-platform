--------------------------------------------------------------------------------
-- REFERENCE -------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.reference ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.reference
AS
  SELECT * FROM AccessReference;

GRANT SELECT ON api.reference TO administrator;

--------------------------------------------------------------------------------
-- api.add_reference -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new reference catalog entry via the API.
 * @param {uuid} pParent - Parent reference or NULL
 * @param {uuid} pType - Reference type
 * @param {text} pCode - Unique business code
 * @param {text} pName - Display name
 * @param {text} pDescription - Optional description
 * @return {uuid} - ID of the created reference
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.add_reference (
  pParent       uuid,
  pType         uuid,
  pCode         text,
  pName         text,
  pDescription  text DEFAULT null
) RETURNS       uuid
AS $$
BEGIN
  RETURN CreateReference(pParent, pType, pCode, pName, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_reference --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update an existing reference catalog entry via the API.
 * @param {uuid} pId - Reference to update
 * @param {uuid} pParent - New parent (NULL keeps current)
 * @param {uuid} pType - New type (NULL keeps current)
 * @param {text} pCode - New code (NULL keeps current)
 * @param {text} pName - New name (NULL keeps current)
 * @param {text} pDescription - New description (NULL keeps current)
 * @return {void}
 * @throws ObjectNotFound - When reference with given ID does not exist
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.update_reference (
  pId           uuid,
  pParent       uuid DEFAULT null,
  pType         uuid DEFAULT null,
  pCode         text DEFAULT null,
  pName         text DEFAULT null,
  pDescription  text DEFAULT null
) RETURNS       void
AS $$
DECLARE
  uReference    uuid;
BEGIN
  SELECT t.id INTO uReference FROM db.reference t WHERE t.id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('справочник', 'id', pId);
  END IF;

  PERFORM EditReference(uReference, pParent, pType, pCode, pName, pDescription, current_locale());
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_reference -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Upsert a reference: create when pId is NULL, otherwise update. Return the row.
 * @param {uuid} pId - Reference ID (NULL = create new)
 * @param {uuid} pParent - Parent reference or NULL
 * @param {uuid} pType - Reference type
 * @param {text} pCode - Unique business code
 * @param {text} pName - Display name
 * @param {text} pDescription - Optional description
 * @return {SETOF api.reference} - The created or updated reference row
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.set_reference (
  pId           uuid,
  pParent       uuid DEFAULT null,
  pType         uuid DEFAULT null,
  pCode         text DEFAULT null,
  pName         text DEFAULT null,
  pDescription  text DEFAULT null
) RETURNS       SETOF api.reference
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_reference(pParent, pType, pCode, pName, pDescription);
  ELSE
    PERFORM api.update_reference(pId, pParent, pType, pCode, pName, pDescription);
  END IF;

  RETURN QUERY SELECT * FROM api.reference WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_reference -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve a single reference entry by ID (with access check).
 * @param {uuid} pId - Reference ID
 * @return {SETOF api.reference} - Matching row or empty set
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_reference (
  pId       uuid
) RETURNS   SETOF api.reference
AS $$
  SELECT * FROM api.reference WHERE id = pId AND CheckObjectAccess(id, B'100')
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_reference ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List reference entries with optional search, filter, and pagination.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Exact-match filter object
 * @param {integer} pLimit - Maximum rows to return
 * @param {integer} pOffSet - Rows to skip
 * @param {jsonb} pOrderBy - Sort fields array
 * @return {SETOF api.reference} - Matching rows
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_reference (
  pSearch    jsonb DEFAULT null,
  pFilter    jsonb DEFAULT null,
  pLimit     integer DEFAULT null,
  pOffSet    integer DEFAULT null,
  pOrderBy   jsonb DEFAULT null
) RETURNS    SETOF api.reference
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'reference', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
