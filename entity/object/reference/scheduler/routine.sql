--------------------------------------------------------------------------------
-- CreateScheduler -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт планировщик
 * @param {uuid} pParent - Идентификатор объекта родителя
 * @param {uuid} pType - Идентификатор типа
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {interval} pPeriod - Период выполнения
 * @param {timestamptz} pDateStart - Дата начала выполнения
 * @param {timestamptz} pDateStop - Дата окончания выполнения
 * @param {text} pDescription - Описание
 * @return {uuid}
 */
CREATE OR REPLACE FUNCTION CreateScheduler (
  pParent       uuid,
  pType         uuid,
  pCode         text,
  pName         text,
  pPeriod       interval default null,
  pDateStart    timestamptz default null,
  pDateStop     timestamptz default null,
  pDescription  text default null
) RETURNS       uuid
AS $$
DECLARE
  uReference    uuid;
  uClass        uuid;
  uMethod       uuid;
BEGIN
  SELECT class INTO uClass FROM db.type WHERE id = pType;

  IF GetEntityCode(uClass) <> 'scheduler' THEN
    PERFORM IncorrectClassType();
  END IF;

  uReference := CreateReference(pParent, pType, pCode, pName, pDescription);

  INSERT INTO db.scheduler (id, reference, period, dateStart, dateStop)
  VALUES (uReference, uReference, pPeriod, pDateStart, pDateStop);

  uMethod := GetMethod(uClass, GetAction('create'));
  PERFORM ExecuteMethod(uReference, uMethod);

  RETURN uReference;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditScheduler ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Редактирует планировщик
 * @param {uuid} pId - Идентификатор
 * @param {uuid} pParent - Идентификатор объекта родителя
 * @param {uuid} pType - Идентификатор типа
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {interval} pPeriod - Период выполнения
 * @param {timestamptz} pDateStart - Дата начала выполнения
 * @param {timestamptz} pDateStop - Дата окончания выполнения
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION EditScheduler (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pCode         text default null,
  pName         text default null,
  pPeriod       interval default null,
  pDateStart    timestamptz default null,
  pDateStop     timestamptz default null,
  pDescription    text default null
) RETURNS       void
AS $$
DECLARE
  uClass        uuid;
  uMethod       uuid;
BEGIN
  PERFORM EditReference(pId, pParent, pType, pCode, pName, pDescription, current_locale());

  UPDATE db.scheduler
     SET period = coalesce(pPeriod, period),
         dateStart = coalesce(pDateStart, dateStart),
         dateStop = coalesce(pDateStop, dateStop)
   WHERE id = pId;

  SELECT class INTO uClass FROM db.object WHERE id = pId;

  uMethod := GetMethod(uClass, GetAction('edit'));
  PERFORM ExecuteMethod(pId, uMethod);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetScheduler -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetScheduler (
  pCode        text
) RETURNS     uuid
AS $$
BEGIN
  RETURN GetReference(pCode, 'scheduler');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
