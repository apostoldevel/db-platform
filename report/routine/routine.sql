--------------------------------------------------------------------------------
-- CreateReportRoutine ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new report generation routine and trigger the 'create' workflow method.
 * @param {uuid} pParent - Parent object identifier
 * @param {uuid} pType - Type identifier (must belong to entity 'report_routine')
 * @param {uuid} pReport - Report this routine belongs to
 * @param {text} pCode - Unique string code
 * @param {text} pName - Human-readable name
 * @param {text} pDefinition - PL/pgSQL function name to execute for report generation
 * @param {text} pDescription - Detailed description
 * @param {integer} pSequence - Execution order (auto-assigned if NULL)
 * @return {uuid} - Identifier of the newly created routine
 * @throws IncorrectClassType - When pType does not belong to the 'report_routine' entity
 * @see EditReportRoutine, GetReportRoutine
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CreateReportRoutine (
  pParent       uuid,
  pType         uuid,
  pReport       uuid,
  pCode         text,
  pName         text,
  pDefinition   text,
  pDescription  text DEFAULT null,
  pSequence     integer default null
) RETURNS       uuid
AS $$
DECLARE
  uReference    uuid;
  uClass        uuid;
  uMethod       uuid;
BEGIN
  SELECT class INTO uClass FROM db.type WHERE id = pType;

  IF GetEntityCode(uClass) <> 'report_routine' THEN
    PERFORM IncorrectClassType();
  END IF;

  IF NULLIF(pSequence, 0) IS NULL THEN
    SELECT max(sequence) + 1 INTO pSequence FROM db.report_routine WHERE report IS NOT DISTINCT FROM pReport;
  ELSE
    PERFORM SetReportRoutineSequence(pReport, pSequence, 1);
  END IF;

  uReference := CreateReference(pParent, pType, pCode, pName, pDescription);

  INSERT INTO db.report_routine (id, reference, report, definition, sequence)
  VALUES (uReference, uReference, pReport, pDefinition, coalesce(pSequence, 1));

  uMethod := GetMethod(uClass, GetAction('create'));
  PERFORM ExecuteMethod(uReference, uMethod);

  RETURN uReference;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditReportRoutine -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update an existing report generation routine (NULL parameters keep current values).
 * @param {uuid} pId - Routine identifier
 * @param {uuid} pParent - New parent object or NULL to keep
 * @param {uuid} pType - New type or NULL to keep
 * @param {uuid} pReport - New report association or NULL to keep
 * @param {text} pCode - New code or NULL to keep
 * @param {text} pName - New name or NULL to keep
 * @param {text} pDefinition - New function name or NULL to keep
 * @param {text} pDescription - New description or NULL to keep
 * @param {integer} pSequence - New execution order or NULL to keep
 * @return {void}
 * @see CreateReportRoutine
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EditReportRoutine (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pReport       uuid default null,
  pCode         text default null,
  pName         text default null,
  pDefinition   text default null,
  pDescription  text DEFAULT null,
  pSequence     integer default null
) RETURNS       void
AS $$
DECLARE
  nSequence     integer;

  uClass        uuid;
  uMethod       uuid;
BEGIN
  SELECT sequence INTO nSequence FROM db.report_routine WHERE id = pId;

  pSequence := coalesce(pSequence, nSequence);

  PERFORM EditReference(pId, pParent, pType, pCode, pName, pDescription, current_locale());

  UPDATE db.report_routine
     SET report = coalesce(pReport, report),
         definition = coalesce(pDefinition, definition),
         sequence = pSequence
   WHERE id = pId;

  IF pSequence < nSequence THEN
    PERFORM SetReportRoutineSequence(pId, pSequence, 1);
  END IF;

  IF pSequence > nSequence THEN
    PERFORM SetReportRoutineSequence(pId, pSequence, -1);
  END IF;

  SELECT class INTO uClass FROM db.object WHERE id = pId;

  uMethod := GetMethod(uClass, GetAction('edit'));
  PERFORM ExecuteMethod(pId, uMethod);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetReportRoutine ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Look up a report routine identifier by its unique code.
 * @param {text} pCode - Unique routine code
 * @return {uuid} - Routine identifier or NULL if not found
 * @see CreateReportRoutine
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetReportRoutine (
  pCode       text
) RETURNS     uuid
AS $$
BEGIN
  RETURN GetReference(pCode, 'report_routine');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetReportRoutineDefinition -----------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the PL/pgSQL function name stored for a report routine.
 * @param {uuid} pId - Routine identifier
 * @return {text} - Function name from the definition column
 * @see ExecuteReportReady
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetReportRoutineDefinition (
  pId        uuid
) RETURNS    text
AS $$
  SELECT definition FROM db.report_routine WHERE id = pId
$$ LANGUAGE SQL STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetReportRoutineSequence -------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Set the execution order for a routine, recursively shifting siblings to avoid collisions.
 * @param {uuid} pId - Routine identifier
 * @param {integer} pSequence - Target sequence number
 * @param {integer} pDelta - Shift direction (+1 or -1) for displaced siblings; 0 = direct set
 * @return {void}
 * @see SortReportRoutine
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SetReportRoutineSequence (
  pId       uuid,
  pSequence integer,
  pDelta    integer
) RETURNS   void
AS $$
DECLARE
  uId       uuid;
  uReport   uuid;
BEGIN
  IF pDelta <> 0 THEN
    SELECT report INTO uReport FROM db.report_routine WHERE id = pId;
    SELECT id INTO uId
      FROM db.report_routine
     WHERE report IS NOT DISTINCT FROM uReport
       AND sequence = pSequence
       AND id <> pId;

    IF FOUND THEN
      PERFORM SetReportRoutineSequence(uId, pSequence + pDelta, pDelta);
    END IF;
  END IF;

  UPDATE db.report_routine SET sequence = pSequence WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SortReportRoutine --------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Re-number all routines of a given report with consecutive sequence values.
 * @param {uuid} pReport - Report whose routines to re-sort
 * @return {void}
 * @see SetReportRoutineSequence
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SortReportRoutine (
  pReport   uuid
) RETURNS   void
AS $$
DECLARE
  r         record;
BEGIN
  FOR r IN
    SELECT id, (row_number() OVER(order by sequence))::int as newsequence
      FROM db.report_routine
     WHERE report IS NOT DISTINCT FROM pReport
  LOOP
    PERFORM SetReportRoutineSequence(r.id, r.newsequence, 0);
  END LOOP;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
