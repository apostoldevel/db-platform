--------------------------------------------------------------------------------
-- CreateReport ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new report definition and trigger the 'create' workflow method.
 * @param {uuid} pParent - Parent object identifier
 * @param {uuid} pType - Type identifier (must belong to entity 'report')
 * @param {uuid} pTree - Report tree node to attach the report to
 * @param {uuid} pForm - Input form for report parameters (NULL if none)
 * @param {uuid} pBinding - Class tree binding for object-scoped reports (NULL for global)
 * @param {text} pCode - Unique string code
 * @param {text} pName - Human-readable name
 * @param {text} pDescription - Detailed description
 * @param {jsonb} pInfo - Extra metadata (JSON)
 * @return {uuid} - Identifier of the newly created report
 * @throws IncorrectClassType - When pType does not belong to the 'report' entity
 * @see EditReport, GetReport
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CreateReport (
  pParent       uuid,
  pType         uuid,
  pTree         uuid,
  pForm         uuid,
  pBinding      uuid,
  pCode         text,
  pName         text default null,
  pDescription  text default null,
  pInfo         jsonb default null
) RETURNS       uuid
AS $$
DECLARE
  uReference    uuid;
  uClass        uuid;
  uMethod       uuid;
BEGIN
  SELECT class INTO uClass FROM db.type WHERE id = pType;

  IF GetEntityCode(uClass) <> 'report' THEN
    PERFORM IncorrectClassType();
  END IF;

  uReference := CreateReference(pParent, pType, pCode, pName, pDescription);

  INSERT INTO db.report (id, reference, tree, form, binding, info)
  VALUES (uReference, uReference, pTree, pForm, pBinding, pInfo);

  uMethod := GetMethod(uClass, GetAction('create'));
  PERFORM ExecuteMethod(uReference, uMethod);

  RETURN uReference;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditReport ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update an existing report definition (NULL parameters keep current values).
 * @param {uuid} pId - Report identifier
 * @param {uuid} pParent - New parent object or NULL to keep
 * @param {uuid} pType - New type or NULL to keep
 * @param {uuid} pTree - New tree node or NULL to keep
 * @param {uuid} pForm - New input form or NULL to keep
 * @param {uuid} pBinding - New class binding or NULL to keep
 * @param {text} pCode - New code or NULL to keep
 * @param {text} pName - New name or NULL to keep
 * @param {text} pDescription - New description or NULL to keep
 * @param {jsonb} pInfo - New metadata or NULL to keep
 * @return {void}
 * @see CreateReport, GetReport
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EditReport (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pTree         uuid default null,
  pForm         uuid default null,
  pBinding      uuid default null,
  pCode         text default null,
  pName         text default null,
  pDescription  text default null,
  pInfo         jsonb default null
) RETURNS       void
AS $$
DECLARE
  uClass        uuid;
  uMethod       uuid;
BEGIN
  PERFORM EditReference(pId, pParent, pType, pCode, pName, pDescription, current_locale());

  UPDATE db.report
     SET tree = coalesce(pTree, tree),
         form = CheckNull(coalesce(pForm, form, null_uuid())),
         binding = CheckNull(coalesce(pBinding, binding, null_uuid())),
         info = CheckNull(coalesce(pInfo, info, '{}'))
   WHERE id = pId;

  SELECT class INTO uClass FROM db.object WHERE id = pId;

  uMethod := GetMethod(uClass, GetAction('edit'));
  PERFORM ExecuteMethod(pId, uMethod);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetReport -------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Look up a report identifier by its unique code.
 * @param {text} pCode - Unique report code
 * @return {uuid} - Report identifier or NULL if not found
 * @see CreateReport
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetReport (
  pCode      text
) RETURNS    uuid
AS $$
BEGIN
  RETURN GetReference(pCode, 'report');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- InitReport ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Initialise a complete report with its input form and generation routine in one step.
 * @param {uuid} pParent - Parent object identifier
 * @param {uuid} pType - Type identifier for the report
 * @param {uuid} pTree - Report tree node
 * @param {text} pCode - Unique report code
 * @param {text} pName - Human-readable name
 * @param {text} pDescription - Detailed description
 * @return {uuid} - Identifier of the created report
 * @see CreateReport, CreateReportForm, CreateReportRoutine
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION InitReport (
  pParent       uuid,
  pType         uuid,
  pTree         uuid,
  pCode         text,
  pName         text,
  pDescription  text
)
RETURNS         uuid
AS $$
DECLARE
  uForm         uuid;
  uReport       uuid;
BEGIN
  uForm := CreateReportForm(pParent, GetType('json.report_form'), 'rfc_' || pCode, pName, 'rfc_' || pCode, pDescription);
  uReport := CreateReport(pParent, pType, pTree, uForm, null, pCode, pName, pDescription);
  PERFORM CreateReportRoutine(pParent, GetType('plpgsql.report_routine'), uReport, 'rpc_' || pCode, pName, 'rpc_' || pCode, pDescription);

  RETURN uReport;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- InitObjectReport ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Initialise an object-scoped report with its generation routine (form supplied externally).
 * @param {uuid} pParent - Parent object identifier
 * @param {uuid} pTree - Report tree node
 * @param {uuid} pForm - Pre-existing input form identifier
 * @param {uuid} pBinding - Class tree binding for object scope
 * @param {text} pCode - Unique report code
 * @param {text} pName - Human-readable name
 * @param {text} pDescription - Detailed description
 * @return {uuid} - Identifier of the created report
 * @see InitReport, CreateReport
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION InitObjectReport (
  pParent       uuid,
  pTree         uuid,
  pForm         uuid,
  pBinding      uuid,
  pCode         text,
  pName         text,
  pDescription  text
)
RETURNS         uuid
AS $$
DECLARE
  uReport       uuid;
BEGIN
  uReport := CreateReport(pParent, GetType('object.report'), pTree, pForm, pBinding, pCode, pName, pDescription);
  PERFORM CreateReportRoutine(pParent, GetType('plpgsql.report_routine'), uReport, 'rpc_' || pCode, pName, 'rpc_' || pCode, pDescription);

  RETURN uReport;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- BuildReport -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Build a report — create a report_ready document from a report definition with form data.
 * @param {uuid} pReport - Report definition identifier
 * @param {uuid} pType - Type for the report_ready document (defaults to 'sync.report_ready')
 * @param {jsonb} pForm - Input form parameters (JSON)
 * @return {uuid} - Identifier of the newly created report_ready document
 * @see CreateReportReady, ExecuteReportReady
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION BuildReport (
  pReport   uuid,
  pType     uuid default null,
  pForm     jsonb default null
) RETURNS   uuid
AS $$
DECLARE
  r         record;
BEGIN
  pType := coalesce(pType, GetType('sync.report_ready'));

  SELECT name, description INTO r FROM Report WHERE id = pReport;

  RETURN CreateReportReady(pReport, pType, pReport, pForm, r.name, r.description);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetForReportDocumentJson ----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Fetch active documents of a given entity as a JSON array of {value, label} pairs for report form selectors.
 * @param {uuid} pEntity - Entity identifier to filter documents by
 * @param {uuid[]} pClasses - Optional class filter array (NULL = all classes)
 * @param {integer} pLimit - Maximum number of rows (default 500)
 * @return {json} - JSON array of {value: uuid, label: text} objects
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetForReportDocumentJson (
  pEntity   uuid,
  pClasses  uuid[] DEFAULT null,
  pLimit    integer DEFAULT 500
) RETURNS   json
AS $$
DECLARE
  r         record;
  arResult  json[];
BEGIN
  IF pClasses IS NULL THEN
    FOR r IN
      SELECT id AS value, label
        FROM ObjectDocument
       WHERE entity = pEntity
         AND statetype = '00000000-0000-4000-b001-000000000002'::uuid
       ORDER BY label
       LIMIT pLimit
    LOOP
      arResult := array_append(arResult, row_to_json(r));
    END LOOP;
  ELSE
    FOR r IN
      SELECT id AS value, label
    	FROM ObjectDocument
	   WHERE entity = pEntity
	     AND class IN (SELECT unnest(pClasses))
         AND statetype = '00000000-0000-4000-b001-000000000002'::uuid
	   ORDER BY label
	   LIMIT pLimit
	LOOP
	  arResult := array_append(arResult, row_to_json(r));
	END LOOP;
  END IF;

  RETURN array_to_json(arResult);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetForReportReferenceJson ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Fetch active reference objects of a given entity as a JSON array of {value, label} pairs for report form selectors.
 * @param {uuid} pEntity - Entity identifier to filter references by
 * @param {uuid[]} pClasses - Optional class filter array (NULL = all classes)
 * @param {integer} pLimit - Maximum number of rows (default 500)
 * @return {json} - JSON array of {value: uuid, label: text} objects
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetForReportReferenceJson (
  pEntity   uuid,
  pClasses  uuid[] DEFAULT null,
  pLimit    integer DEFAULT 500
) RETURNS	json
AS $$
DECLARE
  r			record;
  arResult	json[];
BEGIN
  IF pClasses IS NULL THEN
	FOR r IN
	  SELECT id AS value, name AS label
		FROM ObjectReference
	   WHERE entity = pEntity
         AND statetype = '00000000-0000-4000-b001-000000000002'::uuid
	   ORDER BY name
	   LIMIT pLimit
	LOOP
	  arResult := array_append(arResult, row_to_json(r));
	END LOOP;
  ELSE
	FOR r IN
	  SELECT id AS value, label
		FROM ObjectReference
	   WHERE entity = pEntity
	     AND class IN (SELECT unnest(pClasses))
         AND statetype = '00000000-0000-4000-b001-000000000002'::uuid
	   ORDER BY label
	   LIMIT pLimit
	LOOP
	  arResult := array_append(arResult, row_to_json(r));
	END LOOP;
  END IF;

  RETURN array_to_json(arResult);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetForReportTypeJson --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Fetch all types for a given entity as a JSON array of {value, label} pairs for report form selectors.
 * @param {uuid} pEntity - Entity identifier to list types for
 * @param {integer} pLimit - Maximum number of rows (default 500)
 * @return {json} - JSON array of {value: uuid, label: text} objects
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetForReportTypeJson (
  pEntity   uuid,
  pLimit    integer DEFAULT 500
) RETURNS	json
AS $$
DECLARE
  r			record;
  arResult	json[];
BEGIN
  FOR r IN
    SELECT id AS value, name AS label
      FROM Type
     WHERE entity = pEntity
     ORDER BY name
     LIMIT pLimit
  LOOP
    arResult := array_append(arResult, row_to_json(r));
  END LOOP;

  RETURN array_to_json(arResult);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetForReportStateJson -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Fetch all states for a given class as a JSON array of {value, label} pairs for report form selectors.
 * @param {uuid} pClass - Class identifier to list states for
 * @param {integer} pLimit - Maximum number of rows (default 500)
 * @return {json} - JSON array of {value: uuid, label: text} objects
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetForReportStateJson (
  pClass    uuid,
  pLimit    integer DEFAULT 500
) RETURNS	json
AS $$
DECLARE
  r			record;
  arResult	json[];
BEGIN
  FOR r IN
    SELECT s.id AS value, st.label
      FROM db.state s INNER JOIN db.state_text st ON s.id = st.state AND st.locale = current_locale()
     WHERE s.class = pClass
     ORDER BY label
     LIMIT pLimit
  LOOP
    arResult := array_append(arResult, row_to_json(r));
  END LOOP;

  RETURN array_to_json(arResult);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION ReportErrorHTML ----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Generate an HTML error page for a failed report rendering.
 * @param {integer} pCode - Exception error code
 * @param {text} pMessage - Error message text
 * @param {text} pContext - PL/pgSQL context / stack trace
 * @param {uuid} pLocale - Locale for the HTML lang attribute (defaults to current)
 * @return {text} - Complete HTML document string
 * @see ReportHeadHTML
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION ReportErrorHTML (
  pCode 	integer,
  pMessage 	text,
  pContext 	text,
  pLocale   uuid DEFAULT current_locale()
) RETURNS 	text
AS $$
DECLARE
  l         record;
  vHTML     text;
BEGIN
  FOR l IN SELECT code FROM db.locale WHERE id = pLocale
  LOOP
	vHTML := E'<!DOCTYPE html>\n';

	vHTML := vHTML || format(E'<html lang="%s">\n', l.code);
	vHTML := vHTML || ReportHeadHTML('Familiarization');

	vHTML := vHTML || E'  <body>\n';
	vHTML := vHTML || E'    <div>\n';

	vHTML := vHTML || E'      <pre>';
	vHTML := vHTML || format(E'Exception (%s): %s', pCode, pMessage) || E'\n\n';
	vHTML := vHTML || format(E'Context: %s', pContext);
	vHTML := vHTML || E'      </pre>\n';

	vHTML := vHTML || E'    </div>\n';
	vHTML := vHTML || E'  </body>\n';
	vHTML := vHTML || E'</html>\n';
  END LOOP;

  RETURN vHTML;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ReportStyleHTML -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Generate the CSS style block for printed A4 report pages.
 * @return {text} - HTML <style> element string
 * @see ReportHeadHTML
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION ReportStyleHTML (
) RETURNS   text
AS $$
DECLARE
  vHTML      text;
BEGIN
  vHTML := E'  <style type="text/css">\n';
  vHTML := vHTML || E'    @page {\n';
  vHTML := vHTML || E'      size: A4 portrait;\n';
  vHTML := vHTML || E'      margin: 0.5in;\n';
  vHTML := vHTML || E'    }\n';
  vHTML := vHTML || E'    @media print {\n';
  vHTML := vHTML || E'      .pb-after { page-break-after: always; }\n';
  vHTML := vHTML || E'      .pb-inside { page-break-inside: avoid; }\n';
  vHTML := vHTML || E'      p {\n';
  vHTML := vHTML || E'        orphans: 3;\n';
  vHTML := vHTML || E'        widows: 3;\n';
  vHTML := vHTML || E'      }\n';
  vHTML := vHTML || E'      .report-font-size {\n';
  vHTML := vHTML || E'        font-size: 0.65rem;\n';
  vHTML := vHTML || E'      }\n';
  vHTML := vHTML || E'      .report-text {\n';
  vHTML := vHTML || E'        font-size: small;\n';
  vHTML := vHTML || E'        padding: 10px;\n';
  vHTML := vHTML || E'      }\n';
  vHTML := vHTML || E'      .report-header {\n';
  vHTML := vHTML || E'        font-size: small;\n';
  vHTML := vHTML || E'        margin-top: 15px;\n';
  vHTML := vHTML || E'        margin-left: 50%;\n';
  vHTML := vHTML || E'      }\n';
  vHTML := vHTML || E'      .report-header p {\n';
  vHTML := vHTML || E'        margin: 0;\n';
  vHTML := vHTML || E'        padding: 0;\n';
  vHTML := vHTML || E'      }\n';
  vHTML := vHTML || E'      .report-text p {\n';
  vHTML := vHTML || E'        text-indent: 20px;\n';
  vHTML := vHTML || E'      }\n';
  vHTML := vHTML || E'      .report-li li {\n';
  vHTML := vHTML || E'        margin-top: 5px;\n';
  vHTML := vHTML || E'      }\n';
  vHTML := vHTML || E'    }\n';
  vHTML := vHTML || E'  </style>\n';

  RETURN vHTML;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ReportHeadHTML --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Generate the HTML <head> section with charset, title, and print styles.
 * @param {text} pTitle - Page title
 * @return {text} - HTML <head> element string
 * @see ReportStyleHTML, ReportErrorHTML
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION ReportHeadHTML (
  pTitle    text
) RETURNS   text
AS $$
DECLARE
  vHTML      text;
BEGIN
  vHTML := E'<head>\n';
  vHTML := vHTML || E'  <meta charset="UTF-8">\n';
  vHTML := vHTML || format(E'  <title>%s</title>\n', pTitle);
  vHTML := vHTML || ReportStyleHTML();
  vHTML := vHTML || E'</head>\n';

  RETURN vHTML;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
