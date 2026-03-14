--------------------------------------------------------------------------------
-- FUNCTION GetLocale ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Look up a locale UUID by its ISO 639-1 code.
 * @param {text} pCode - Two-letter ISO 639-1 language code (e.g. 'en', 'ru')
 * @return {uuid} - Locale identifier, or NULL if the code does not exist
 * @see GetLocaleCode
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetLocale (
  pCode     text
) RETURNS   uuid
AS $$
  SELECT id FROM db.locale WHERE code = pCode;
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetLocaleCode ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the ISO 639-1 language code for a given locale identifier.
 * @param {uuid} pId - Locale UUID
 * @return {text} - Two-letter language code, or NULL if the identifier does not exist
 * @see GetLocale
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetLocaleCode (
  pId       uuid
) RETURNS   text
AS $$
  SELECT code FROM db.locale WHERE id = pId;
$$ LANGUAGE sql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
