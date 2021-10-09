--------------------------------------------------------------------------------
-- CreateReportRoutine ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт функцию отчёта
 * @param {uuid} pParent - Идентификатор объекта родителя
 * @param {uuid} pType - Идентификатор типа
 * @param {uuid} pReport - Идентификатор отчёта
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {text} pDefinition - Определение
 * @param {text} pDescription - Описание
 * @param {integer} pSequence - Очерёдность
 * @return {uuid}
 */
CREATE OR REPLACE FUNCTION CreateReportRoutine (
  pParent       uuid,
  pType         uuid,
  pReport       uuid,
  pCode         text,
  pName         text,
  pDefinition	text,
  pDescription	text DEFAULT null,
  pSequence     integer default null
) RETURNS       uuid
AS $$
DECLARE
  uReference	uuid;
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
 * Редактирует функцию отчёта
 * @param {uuid} pId - Идентификатор
 * @param {uuid} pParent - Идентификатор объекта родителя
 * @param {uuid} pType - Идентификатор типа
 * @param {uuid} pReport - Идентификатор отчёта
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {text} pDefinition - Определение
 * @param {text} pDescription - Описание
 * @param {integer} pSequence - Очерёдность
 * @return {void}
 */
CREATE OR REPLACE FUNCTION EditReportRoutine (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pReport       uuid default null,
  pCode         text default null,
  pName         text default null,
  pDefinition	text default null,
  pDescription	text DEFAULT null,
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

CREATE OR REPLACE FUNCTION GetReportRoutine (
  pCode		text
) RETURNS 	uuid
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

CREATE OR REPLACE FUNCTION GetReportRoutineDefinition (
  pId		uuid
) RETURNS	text
AS $$
  SELECT definition FROM db.report_routine WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetReportRoutineSequence -------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetReportRoutineSequence (
  pId		uuid,
  pSequence	integer,
  pDelta	integer
) RETURNS 	void
AS $$
DECLARE
  uId		uuid;
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

CREATE OR REPLACE FUNCTION SortReportRoutine (
  pReport   uuid
) RETURNS 	void
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
