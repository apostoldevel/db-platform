--------------------------------------------------------------------------------
-- REPORT ----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- CreateReportReady -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new generated report document and trigger the 'create' workflow method.
 * @param {uuid} pParent - Parent object identifier or NULL
 * @param {uuid} pType - Type identifier (must belong to entity 'report_ready')
 * @param {uuid} pReport - Source report definition that produces this output
 * @param {jsonb} pForm - Input parameters snapshot (JSON)
 * @param {text} pLabel - Display label for the document
 * @param {text} pDescription - Detailed description
 * @return {uuid} - Identifier of the newly created report_ready document
 * @throws IncorrectClassType - When pType does not belong to the 'report_ready' entity
 * @throws ObjectNotFound - When pReport does not reference an existing report
 * @see EditReportReady, ExecuteReportReady
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CreateReportReady (
  pParent       uuid,
  pType         uuid,
  pReport       uuid default null,
  pForm         jsonb default null,
  pLabel        text default null,
  pDescription  text default null
) RETURNS       uuid
AS $$
DECLARE
  uId           uuid;
  uReportReady  uuid;
  uDocument     uuid;

  uClass        uuid;
  uMethod       uuid;
BEGIN
  SELECT class INTO uClass FROM type WHERE id = pType;

  IF GetEntityCode(uClass) <> 'report_ready' THEN
    PERFORM IncorrectClassType();
  END IF;

  SELECT id INTO uId FROM db.report WHERE id = pReport;
  IF NOT FOUND THEN
    PERFORM ObjectNotFound('report', 'id', pReport);
  END IF;

  uDocument := CreateDocument(pParent, pType, pLabel, pDescription);

  INSERT INTO db.report_ready (id, document, report, form)
  VALUES (uDocument, uDocument, pReport, pForm)
  RETURNING id INTO uReportReady;

  uMethod := GetMethod(uClass, GetAction('create'));
  PERFORM ExecuteMethod(uReportReady, uMethod);

  RETURN uReportReady;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditReportReady -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update an existing generated report document (NULL parameters keep current values).
 * @param {uuid} pId - Report ready document identifier
 * @param {uuid} pParent - New parent object or NULL to keep
 * @param {uuid} pType - New type or NULL to keep
 * @param {uuid} pReport - New source report or NULL to keep
 * @param {text} pForm - New input parameters or NULL to keep
 * @param {text} pLabel - New display label or NULL to keep
 * @param {text} pDescription - New description or NULL to keep
 * @return {void}
 * @throws ObjectNotFound - When pReport does not reference an existing report
 * @see CreateReportReady
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EditReportReady (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pReport       uuid default null,
  pForm         text default null,
  pLabel        text default null,
  pDescription  text default null
) RETURNS       void
AS $$
DECLARE
  uId           uuid;
  uClass        uuid;
  uMethod       uuid;
BEGIN
  IF pReport IS NOT NULL THEN
    SELECT id INTO uId FROM db.report WHERE id = pReport;
    IF NOT FOUND THEN
      PERFORM ObjectNotFound('report', 'id', pReport);
    END IF;
  END IF;

  PERFORM EditDocument(pId, pParent, pType, pLabel, pDescription, pDescription, current_locale());

  UPDATE db.report_ready
     SET report = coalesce(pReport, report),
         form = coalesce(pForm, form)
   WHERE id = pId;

  uClass := GetObjectClass(pId);
  uMethod := GetMethod(uClass, GetAction('edit'));

  PERFORM ExecuteMethod(pId, uMethod);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetReportReadyForm ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the input parameters snapshot for a generated report.
 * @param {uuid} pId - Report ready document identifier
 * @return {jsonb} - Input form parameters (JSON) or NULL
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetReportReadyForm (
  pId       uuid
) RETURNS   jsonb
AS $$
  SELECT form FROM db.report_ready WHERE id = pId;
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ExecuteReportReady ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Execute all generation routines for a report_ready document in sequence order.
 * @param {uuid} pId - Report ready document identifier
 * @return {void}
 * @see BuildReport, CreateReportReady
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION ExecuteReportReady (
  pId       uuid
) RETURNS   void
AS $$
DECLARE
  r         record;

  uReport   uuid;
  jForm     jsonb;
BEGIN
  SELECT report, form INTO uReport, jForm FROM db.report_ready WHERE id = pId;

  FOR r IN SELECT definition FROM db.report_routine WHERE report = uReport ORDER BY sequence
  LOOP
    EXECUTE 'SELECT report.' || r.definition || '($1, $2);' USING pId, jForm;
  END LOOP;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
