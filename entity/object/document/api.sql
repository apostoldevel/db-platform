--------------------------------------------------------------------------------
-- DOCUMENT --------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.document ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.document
AS
  SELECT * FROM ObjectDocument;

GRANT SELECT ON api.document TO administrator;

--------------------------------------------------------------------------------
-- api.add_document ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new document record.
 * @param {uuid} pParent - Parent object reference (or NULL for root)
 * @param {uuid} pType - Document type identifier
 * @param {text} pLabel - Display label
 * @param {text} pDescription - Localized description
 * @param {text} pData - Full-text content
 * @return {uuid} - Identifier of the created document
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.add_document (
  pParent       uuid,
  pType         uuid,
  pLabel        text default null,
  pDescription  text DEFAULT null,
  pData         text DEFAULT null
) RETURNS       uuid
AS $$
BEGIN
  RETURN CreateDocument(pParent, pType, pLabel, pDescription, pData);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_document ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update an existing document record.
 * @param {uuid} pId - Document identifier
 * @param {uuid} pParent - New parent object (NULL keeps current)
 * @param {uuid} pType - New document type (NULL keeps current)
 * @param {text} pLabel - New display label (NULL keeps current)
 * @param {text} pDescription - New description (NULL keeps current)
 * @param {text} pData - New full-text content (NULL keeps current)
 * @return {void}
 * @throws ObjectNotFound - When no document matches pId
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.update_document (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pLabel        text default null,
  pDescription  text DEFAULT null,
  pData         text DEFAULT null
) RETURNS       void
AS $$
DECLARE
  uDocument     uuid;
BEGIN
  SELECT t.id INTO uDocument FROM db.document t WHERE t.id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('document', 'id', pId);
  END IF;

  PERFORM EditDocument(uDocument, pParent, pType,pLabel, pDescription, pData, current_locale());
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_document ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create or update a document (upsert). Routes to add or update based on pId.
 * @param {uuid} pId - Document identifier (NULL to create)
 * @param {uuid} pParent - Parent object reference
 * @param {uuid} pType - Document type identifier
 * @param {text} pLabel - Display label
 * @param {text} pDescription - Localized description
 * @param {text} pData - Full-text content
 * @return {SETOF api.document} - The created or updated document
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.set_document (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pLabel        text default null,
  pDescription  text DEFAULT null,
  pData         text DEFAULT null
) RETURNS       SETOF api.document
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_document(pParent, pType, pLabel, pDescription, pData);
  ELSE
    PERFORM api.update_document(pId, pParent, pType, pLabel, pDescription, pData);
  END IF;

  RETURN QUERY SELECT * FROM api.document WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_document ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve a single document by identifier with access check.
 * @param {uuid} pId - Document identifier
 * @return {SETOF api.document} - Matching document record
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_document (
  pId       uuid
) RETURNS   SETOF api.document
AS $$
  SELECT * FROM api.document WHERE id = pId AND CheckObjectAccess(id, B'100')
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_document -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List documents matching search, filter, and sort criteria.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Field-level equality filter
 * @param {integer} pLimit - Maximum number of rows to return
 * @param {integer} pOffSet - Number of rows to skip
 * @param {jsonb} pOrderBy - Array of fields to sort by
 * @return {SETOF api.document} - Matching document records
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_document (
  pSearch    jsonb default null,
  pFilter    jsonb default null,
  pLimit     integer default null,
  pOffSet    integer default null,
  pOrderBy   jsonb default null
) RETURNS    SETOF api.document
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'document', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.change_document_area ----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Reassign a document (and children) to a different visibility area.
 * @param {uuid} pId - Document identifier
 * @param {uuid} pArea - Target area identifier
 * @return {SETOF api.document}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.change_document_area (
  pId           uuid,
  pArea         uuid
) RETURNS       SETOF api.document
AS $$
BEGIN
  PERFORM ChangeDocumentArea(pId, pArea);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
