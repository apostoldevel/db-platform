--------------------------------------------------------------------------------
-- CreateReportForm ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new report input form and trigger the 'create' workflow method.
 * @param {uuid} pParent - Parent object identifier
 * @param {uuid} pType - Type identifier (must belong to entity 'report_form')
 * @param {text} pCode - Unique string code
 * @param {text} pName - Human-readable name
 * @param {text} pDefinition - PL/pgSQL function name that builds the form JSON
 * @param {text} pDescription - Detailed description
 * @return {uuid} - Identifier of the newly created form
 * @throws IncorrectClassType - When pType does not belong to the 'report_form' entity
 * @see EditReportForm, GetReportForm
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CreateReportForm (
  pParent       uuid,
  pType         uuid,
  pCode         text,
  pName         text,
  pDefinition   text,
  pDescription  text default null
) RETURNS       uuid
AS $$
DECLARE
  uReference    uuid;
  uClass        uuid;
  uMethod       uuid;
BEGIN
  SELECT class INTO uClass FROM db.type WHERE id = pType;

  IF GetEntityCode(uClass) <> 'report_form' THEN
    PERFORM IncorrectClassType();
  END IF;

  uReference := CreateReference(pParent, pType, pCode, pName, pDescription);

  INSERT INTO db.report_form (id, reference, definition)
  VALUES (uReference, uReference, pDefinition);

  uMethod := GetMethod(uClass, GetAction('create'));
  PERFORM ExecuteMethod(uReference, uMethod);

  RETURN uReference;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditReportForm --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update an existing report input form (NULL parameters keep current values).
 * @param {uuid} pId - Form identifier
 * @param {uuid} pParent - New parent object or NULL to keep
 * @param {uuid} pType - New type or NULL to keep
 * @param {text} pCode - New code or NULL to keep
 * @param {text} pName - New name or NULL to keep
 * @param {text} pDefinition - New function name or NULL to keep
 * @param {text} pDescription - New description or NULL to keep
 * @return {void}
 * @see CreateReportForm
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EditReportForm (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pCode         text default null,
  pName         text default null,
  pDefinition   text default null,
  pDescription  text default null
) RETURNS       void
AS $$
DECLARE
  uClass        uuid;
  uMethod       uuid;
BEGIN
  PERFORM EditReference(pId, pParent, pType, pCode, pName, pDescription, current_locale());

  UPDATE db.report_form
     SET definition = coalesce(pDefinition, definition)
   WHERE id = pId;

  SELECT class INTO uClass FROM db.object WHERE id = pId;

  uMethod := GetMethod(uClass, GetAction('edit'));
  PERFORM ExecuteMethod(pId, uMethod);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetReportForm ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Look up a report form identifier by its unique code.
 * @param {text} pCode - Unique form code
 * @return {uuid} - Form identifier or NULL if not found
 * @see CreateReportForm
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetReportForm (
  pCode       text
) RETURNS     uuid
AS $$
BEGIN
  RETURN GetReference(pCode, 'report_form');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetReportFormDefinition --------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the PL/pgSQL function name that generates a report form.
 * @param {uuid} pId - Form identifier
 * @return {text} - Function name stored in the definition column
 * @see BuildReportForm
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetReportFormDefinition (
  pId        uuid
) RETURNS    text
AS $$
  SELECT definition FROM db.report_form WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION BuildReportForm ----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Execute the form-building function to generate report parameter JSON.
 * @param {uuid} pForm - Form identifier
 * @param {json} pParams - Input parameters passed to the form builder
 * @return {SETOF json} - Generated form definition as JSON
 * @see GetReportFormDefinition
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION BuildReportForm (
  pForm     uuid,
  pParams   json
) RETURNS   SETOF json
AS $$
BEGIN
  RETURN QUERY EXECUTE 'SELECT report.' || GetReportFormDefinition(pForm) || '($1, $2);' USING pForm, pParams;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
