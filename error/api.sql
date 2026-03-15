--------------------------------------------------------------------------------
-- ERROR CATALOG ---------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.add_error ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new error catalog entry with a localized message for the current locale.
 * @param {text} pCode - Structured error identifier (e.g., ERR-400-001)
 * @param {integer} pHttpCode - HTTP status code group (400, 401, 403, 404, 500)
 * @param {char} pSeverity - Severity level: E = error, W = warning
 * @param {text} pCategory - Functional category: auth, access, validation, entity, workflow, system
 * @param {text} pMessage - Short user-facing error message
 * @param {text} pDescription - Detailed explanation for documentation and support agents
 * @param {text} pResolution - Recommended steps to resolve the error
 * @return {uuid} - ID of the created error catalog entry
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.add_error (
  pCode         text,
  pHttpCode     integer,
  pSeverity     char DEFAULT 'E',
  pCategory     text DEFAULT 'validation',
  pMessage      text DEFAULT null,
  pDescription  text DEFAULT null,
  pResolution   text DEFAULT null
) RETURNS       uuid
AS $$
DECLARE
  uId           uuid;
BEGIN
  uId := CreateErrorCatalog(pCode, pHttpCode, pSeverity, pCategory);

  IF pMessage IS NOT NULL THEN
    PERFORM SetErrorCatalogText(uId, current_locale(), pMessage, pDescription, pResolution);
  END IF;

  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_error ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update an existing error catalog entry.
 * @param {uuid} pId - Error catalog entry to update
 * @param {text} pCode - New error code (NULL keeps current)
 * @param {integer} pHttpCode - New HTTP status code (NULL keeps current)
 * @param {char} pSeverity - New severity level (NULL keeps current)
 * @param {text} pCategory - New functional category (NULL keeps current)
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.update_error (
  pId           uuid,
  pCode         text DEFAULT null,
  pHttpCode     integer DEFAULT null,
  pSeverity     char DEFAULT null,
  pCategory     text DEFAULT null
) RETURNS       void
AS $$
BEGIN
  PERFORM EditErrorCatalog(pId, pCode, pHttpCode, pSeverity, pCategory);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_error ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Upsert an error catalog entry: create when pId is NULL, otherwise update. Return the row.
 * @param {uuid} pId - Error catalog entry ID (NULL = create new)
 * @param {text} pCode - Structured error identifier
 * @param {integer} pHttpCode - HTTP status code group
 * @param {char} pSeverity - Severity level
 * @param {text} pCategory - Functional category
 * @param {text} pMessage - Short user-facing error message
 * @param {text} pDescription - Detailed explanation
 * @param {text} pResolution - Recommended resolution steps
 * @return {SETOF api.error_catalog} - The created or updated error catalog row
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.set_error (
  pId           uuid,
  pCode         text DEFAULT null,
  pHttpCode     integer DEFAULT null,
  pSeverity     char DEFAULT null,
  pCategory     text DEFAULT null,
  pMessage      text DEFAULT null,
  pDescription  text DEFAULT null,
  pResolution   text DEFAULT null
) RETURNS       SETOF api.error_catalog
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_error(pCode, pHttpCode, pSeverity, pCategory, pMessage, pDescription, pResolution);
  ELSE
    PERFORM api.update_error(pId, pCode, pHttpCode, pSeverity, pCategory);
    IF pMessage IS NOT NULL THEN
      PERFORM SetErrorCatalogText(pId, current_locale(), pMessage, pDescription, pResolution);
    END IF;
  END IF;

  RETURN QUERY SELECT * FROM api.error_catalog WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_error ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve a single error catalog entry by ID.
 * @param {uuid} pId - Error catalog entry ID
 * @return {SETOF api.error_catalog} - Matching row or empty set
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_error (
  pId       uuid
) RETURNS   SETOF api.error_catalog
AS $$
  SELECT * FROM api.error_catalog WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_error_by_code -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve a single error catalog entry by its code string.
 * @param {text} pCode - Structured error identifier (e.g., ERR-400-001)
 * @return {SETOF api.error_catalog} - Matching row or empty set
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_error_by_code (
  pCode     text
) RETURNS   SETOF api.error_catalog
AS $$
  SELECT * FROM api.error_catalog WHERE code = pCode
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_error --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List error catalog entries with optional search, filter, and pagination.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Exact-match filter object
 * @param {integer} pLimit - Maximum rows to return
 * @param {integer} pOffSet - Rows to skip
 * @param {jsonb} pOrderBy - Sort fields array
 * @return {SETOF api.error_catalog} - Matching rows
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_error (
  pSearch   jsonb DEFAULT null,
  pFilter   jsonb DEFAULT null,
  pLimit    integer DEFAULT null,
  pOffSet   integer DEFAULT null,
  pOrderBy  jsonb DEFAULT null
) RETURNS   SETOF api.error_catalog
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'error_catalog', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
