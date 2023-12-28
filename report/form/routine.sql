--------------------------------------------------------------------------------
-- CreateReportForm ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт форму отчёта
 * @param {uuid} pParent - Идентификатор объекта родителя
 * @param {uuid} pType - Идентификатор типа
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {text} pDefinition - PL/pgSQL код
 * @param {text} pDescription - Описание
 * @return {uuid}
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
 * Редактирует форму отчёта
 * @param {uuid} pId - Идентификатор
 * @param {uuid} pParent - Идентификатор объекта родителя
 * @param {uuid} pType - Идентификатор типа
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {text} pDefinition - PL/pgSQL код
 * @param {text} pDescription - Описание
 * @return {void}
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
