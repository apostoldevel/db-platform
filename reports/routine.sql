--------------------------------------------------------------------------------
-- REPORT FORM -----------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- rfc_identifier_form ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Build the object identifier input form definition.
 * @param {uuid} pForm - Report form identifier
 * @param {json} pParams - Optional parameters (unused)
 * @return {json} - Form descriptor with a single UUID identifier field
 * @see rfc_import_file, rfc_import_files
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION report.rfc_identifier_form (
  pForm         uuid,
  pParams       json default null
) RETURNS       json
AS $$
DECLARE
  l             record;
  label         text;
BEGIN
  FOR l IN SELECT code FROM db.locale WHERE id = current_locale()
  LOOP
    IF l.code = 'ru' THEN
      label := 'Идентификатор';
    ELSE
      label := 'Identifier';
    END IF;
  END LOOP;

  RETURN json_build_object('form', pForm, 'fields', jsonb_build_array(jsonb_build_object('type', 'string', 'format', 'uuid', 'key', 'identifier', 'label', label)));
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- rfc_import_file -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Build the single-file import form definition.
 * @param {uuid} pForm - Report form identifier
 * @param {json} pParams - Optional parameters (unused)
 * @return {json} - Form descriptor with a single JSON file upload field
 * @see rfc_identifier_form, rfc_import_files
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION report.rfc_import_file (
  pForm         uuid,
  pParams       json default null
) RETURNS       json
AS $$
DECLARE
  l             record;
  label         text;
BEGIN
  FOR l IN SELECT code FROM db.locale WHERE id = current_locale()
  LOOP
    IF l.code = 'ru' THEN
      label := 'Импортировать файл';
    ELSE
      label := 'Import file';
    END IF;
  END LOOP;

  RETURN json_build_object('form', pForm, 'fields', jsonb_build_array(jsonb_build_object('type', 'file', 'format', 'JSON', 'key', 'files', 'label', label)));
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- rfc_import_files ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Build the multi-file import form definition.
 * @param {uuid} pForm - Report form identifier
 * @param {json} pParams - Optional parameters (unused)
 * @return {json} - Form descriptor with a multiple JSON file upload field
 * @see rfc_identifier_form, rfc_import_file
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION report.rfc_import_files (
  pForm         uuid,
  pParams       json default null
) RETURNS       json
AS $$
DECLARE
  l             record;
  label         text;
BEGIN
  FOR l IN SELECT code FROM db.locale WHERE id = current_locale()
  LOOP
    IF l.code = 'ru' THEN
      label := 'Импортировать файлы';
    ELSE
      label := 'Import files';
    END IF;
  END LOOP;

  RETURN json_build_object('form', pForm, 'fields', jsonb_build_array(jsonb_build_object('type', 'file', 'format', 'JSON', 'key', 'files', 'multiple', true, 'label', label)));
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;
