--------------------------------------------------------------------------------
-- REPORT ----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- CreateReportReady -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт готовый отчёт
 * @param {uuid} pParent - Ссылка на родительский объект: Object.Parent | null
 * @param {uuid} pType - Идентификатор типа
 * @param {uuid} pReport - Отчёт
 * @param {jsonb} pForm - Форма
 * @param {text} pLabel - Метка
 * @param {text} pDescription - Описание
 * @return {uuid} - Id
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
    PERFORM ObjectNotFound('отчёт', 'id', pReport);
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
 * Редактирует готовый отчёт.
 * @param {uuid} pParent - Ссылка на родительский объект: Object.Parent | null
 * @param {uuid} pType - Идентификатор типа
 * @param {uuid} pReport - Отчёт
 * @param {text} pForm - Код
 * @param {text} pLabel - Метка
 * @param {text} pDescription - Описание
 * @return {void}
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
      PERFORM ObjectNotFound('отчёт', 'id', pReport);
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
