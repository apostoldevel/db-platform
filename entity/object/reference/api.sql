--------------------------------------------------------------------------------
-- REFERENCE -------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.reference ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.reference
AS
  SELECT t.* FROM ObjectReference t INNER JOIN AccessReference a ON t.id = a.object;

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
 * @throws AccessDenied - When the type is a program or a scheduler and the caller is not a platform administrator
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
  -- This is the generic road to any reference type. A program or a
  -- scheduler is the administrator's alone (api.add_program, api.add_scheduler),
  -- and made here it would be a bare object — class and code, no body or period —
  -- that holds the code against the administrator's own /program/set and
  -- /scheduler/set (ERR-400-030) and against a seed (unique code in the scope).
  IF session_user <> 'kernel' AND NOT IsAdmin() AND EXISTS (
       SELECT 1 FROM db.type t INNER JOIN db.class_tree c ON c.id = t.class
        WHERE t.id = pType AND c.code IN ('program', 'scheduler')) THEN
    PERFORM AccessDenied();
  END IF;

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
 * @throws AccessDenied - When the reference or the new type is a program or a scheduler and the caller is not a platform administrator
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
BEGIN
  -- See api.add_reference — the class of the object and of the new type both count.
  IF session_user <> 'kernel' AND NOT IsAdmin() AND EXISTS (
       SELECT 1 FROM db.class_tree c
        WHERE c.code IN ('program', 'scheduler')
          AND c.id IN (SELECT r.class FROM db.reference r WHERE r.id = pId
                       UNION ALL
                       SELECT t.class FROM db.type t WHERE t.id = pType)) THEN
    PERFORM AccessDenied();
  END IF;

  PERFORM FROM db.reference WHERE id = pId;
  IF NOT FOUND THEN
    PERFORM ObjectNotFound('reference', 'id', pId);
  END IF;

  PERFORM EditReference(pId, pParent, pType, pCode, pName, pDescription, current_locale());
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
  pId := coalesce(pId, GetReference(pCode));

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
  SELECT * FROM kernel.ObjectReference WHERE id = pId AND CheckObjectAccess(id, B'100')
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.count_reference ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Count reference records matching search/filter criteria.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Exact-match filter object
 * @return {SETOF bigint} - Record count
 * @since 1.2.1
 */
CREATE OR REPLACE FUNCTION api.count_reference (
  pSearch    jsonb default null,
  pFilter    jsonb default null
) RETURNS    SETOF bigint
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('kernel', 'ObjectReference', pSearch, pFilter, 0, null, '{}'::jsonb, '["count(id)"]'::jsonb);
END;
$$ LANGUAGE plpgsql
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
  RETURN QUERY EXECUTE api.sql('kernel', 'ObjectReference', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
