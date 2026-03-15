--------------------------------------------------------------------------------
-- CreateErrorCatalog ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Register a new error code in the catalog.
 * @param {text} pCode - Structured error identifier (e.g., ERR-400-001)
 * @param {integer} pHttpCode - HTTP status code group (400, 401, 403, 404, 500)
 * @param {char} pSeverity - Severity level: E = error, W = warning
 * @param {text} pCategory - Functional category: auth, access, validation, entity, workflow, system
 * @return {uuid} - Identifier of the newly created error catalog entry
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CreateErrorCatalog (
  pCode       text,
  pHttpCode   integer,
  pSeverity   char DEFAULT 'E',
  pCategory   text DEFAULT 'validation'
) RETURNS     uuid
AS $$
DECLARE
  uId         uuid;
BEGIN
  INSERT INTO db.error_catalog (code, http_code, severity, category)
  VALUES (pCode, pHttpCode, pSeverity, pCategory)
  RETURNING id INTO uId;

  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditErrorCatalog ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update an existing error catalog entry (NULL parameters keep current values).
 * @param {uuid} pId - Identifier of the error catalog entry to update
 * @param {text} pCode - New structured error identifier, or NULL to keep current
 * @param {integer} pHttpCode - New HTTP status code group, or NULL to keep current
 * @param {char} pSeverity - New severity level, or NULL to keep current
 * @param {text} pCategory - New functional category, or NULL to keep current
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EditErrorCatalog (
  pId         uuid,
  pCode       text DEFAULT null,
  pHttpCode   integer DEFAULT null,
  pSeverity   char DEFAULT null,
  pCategory   text DEFAULT null
) RETURNS     void
AS $$
BEGIN
  UPDATE db.error_catalog
     SET code      = coalesce(pCode, code),
         http_code = coalesce(pHttpCode, http_code),
         severity  = coalesce(pSeverity, severity),
         category  = coalesce(pCategory, category)
   WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetErrorCatalog -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Look up an error catalog entry identifier by its code.
 * @param {text} pCode - Structured error identifier to search for
 * @return {uuid} - Identifier of the matching entry, or NULL if not found
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetErrorCatalog (
  pCode       text
) RETURNS     uuid
AS $$
  SELECT id FROM db.error_catalog WHERE code = pCode;
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteErrorCatalog ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Remove an error catalog entry and its translations (CASCADE).
 * @param {uuid} pId - Identifier of the error catalog entry to delete
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DeleteErrorCatalog (
  pId         uuid
) RETURNS     void
AS $$
BEGIN
  DELETE FROM db.error_catalog WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SetErrorCatalogText ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Upsert a locale-specific message for an error catalog entry.
 * @param {uuid} pErrorId - Identifier of the error catalog entry
 * @param {uuid} pLocale - Target locale identifier
 * @param {text} pMessage - Short user-facing error message (may contain %s placeholders)
 * @param {text} pDescription - Detailed explanation for documentation and support agents
 * @param {text} pResolution - Recommended steps to resolve the error
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SetErrorCatalogText (
  pErrorId    uuid,
  pLocale     uuid,
  pMessage    text,
  pDescription text DEFAULT null,
  pResolution text DEFAULT null
) RETURNS     void
AS $$
BEGIN
  INSERT INTO db.error_catalog_text (error_id, locale, message, description, resolution)
  VALUES (pErrorId, pLocale, pMessage, pDescription, pResolution)
  ON CONFLICT (error_id, locale) DO UPDATE
     SET message     = pMessage,
         description = pDescription,
         resolution  = pResolution;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetErrorCatalogMessage ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the localized message for an error code, falling back to English.
 * @param {text} pCode - Structured error identifier to look up
 * @param {uuid} pLocale - Target locale identifier, or NULL to use the session locale
 * @return {text} - Localized error message, or NULL if the code does not exist
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetErrorCatalogMessage (
  pCode       text,
  pLocale     uuid DEFAULT null
) RETURNS     text
AS $$
DECLARE
  uId         uuid;
  vMessage    text;
BEGIN
  uId := GetErrorCatalog(pCode);

  IF uId IS NULL THEN
    RETURN null;
  END IF;

  SELECT coalesce(
    (SELECT message FROM db.error_catalog_text WHERE error_id = uId AND locale = coalesce(pLocale, current_locale())),
    (SELECT message FROM db.error_catalog_text WHERE error_id = uId AND locale = GetLocale('en'))
  ) INTO vMessage;

  RETURN vMessage;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RegisterError ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Register or update an error code with its localized message in one call.
 * @param {text} pCode - Structured error identifier (e.g., ERR-400-001)
 * @param {integer} pHttpCode - HTTP status code group (400, 401, 403, 404, 500)
 * @param {char} pSeverity - Severity level: E = error, W = warning
 * @param {text} pCategory - Functional category: auth, access, validation, entity, workflow, system
 * @param {text} pLocaleCode - Locale code for the message (e.g., 'en', 'ru')
 * @param {text} pMessage - Short user-facing error message
 * @param {text} pDescription - Detailed explanation for documentation and support agents
 * @param {text} pResolution - Recommended steps to resolve the error
 * @return {uuid} - Identifier of the error catalog entry (existing or newly created)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION RegisterError (
  pCode        text,
  pHttpCode    integer,
  pSeverity    char,
  pCategory    text,
  pLocaleCode  text,
  pMessage     text,
  pDescription text DEFAULT null,
  pResolution  text DEFAULT null
) RETURNS      uuid
AS $$
DECLARE
  uId          uuid;
BEGIN
  uId := GetErrorCatalog(pCode);

  IF uId IS NULL THEN
    uId := CreateErrorCatalog(pCode, pHttpCode, pSeverity, pCategory);
  END IF;

  PERFORM SetErrorCatalogText(uId, GetLocale(pLocaleCode), pMessage, pDescription, pResolution);

  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
