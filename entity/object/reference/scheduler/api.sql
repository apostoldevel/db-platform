--------------------------------------------------------------------------------
-- SCHEDULER -------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.scheduler ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.scheduler
AS
  SELECT * FROM ObjectScheduler;

GRANT SELECT ON api.scheduler TO administrator;

--------------------------------------------------------------------------------
-- api.add_scheduler -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Добавляет планировщик.
 * @param {uuid} pParent - Ссылка на родительский объект: api.document | null
 * @param {uuid} pType - Код типа
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {interval} pPeriod - Период выполнения
 * @param {timestamptz} pDateStart - Дата начала выполнения
 * @param {timestamptz} pDateStop - Дата окончания выполнения
 * @param {text} pDescription - Описание
 * @return {uuid}
 */
CREATE OR REPLACE FUNCTION api.add_scheduler (
  pParent       uuid,
  pType         uuid,
  pCode         text,
  pName         text,
  pPeriod       interval default null,
  pDateStart    timestamptz default null,
  pDateStop     timestamptz default null,
  pDescription	text default null
) RETURNS       uuid
AS $$
BEGIN
  RETURN CreateScheduler(pParent, coalesce(pType, GetType('job.scheduler')), pCode, pName, pPeriod, pDateStart, pDateStop, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_scheduler --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Редактирует планировщик.
 * @param {uuid} pParent - Ссылка на родительский объект: Object.Parent | null
 * @param {text} pType - Код типа
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {interval} pPeriod - Период выполнения
 * @param {timestamptz} pDateStart - Дата начала выполнения
 * @param {timestamptz} pDateStop - Дата окончания выполнения
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.update_scheduler (
  pId		    uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pCode         text default null,
  pName         text default null,
  pPeriod       interval default null,
  pDateStart    timestamptz default null,
  pDateStop     timestamptz default null,
  pDescription	text default null
) RETURNS       void
AS $$
DECLARE
  uScheduler    uuid;
BEGIN
  SELECT t.id INTO uScheduler FROM db.scheduler t WHERE t.id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('планировщик', 'id', pId);
  END IF;

  PERFORM EditScheduler(uScheduler, pParent, pType, pCode, pName, pPeriod, pDateStart, pDateStop, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_scheduler -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_scheduler (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pCode         text default null,
  pName         text default null,
  pPeriod       interval default null,
  pDateStart    timestamptz default null,
  pDateStop     timestamptz default null,
  pDescription	text default null
) RETURNS       SETOF api.scheduler
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_scheduler(pParent, pType, pCode, pName, pPeriod, pDateStart, pDateStop, pDescription);
  ELSE
    PERFORM api.update_scheduler(pId, pParent, pType, pCode, pName, pPeriod, pDateStart, pDateStop, pDescription);
  END IF;

  RETURN QUERY SELECT * FROM api.scheduler WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_scheduler -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает планировщик
 * @param {uuid} pId - Идентификатор
 * @return {api.scheduler}
 */
CREATE OR REPLACE FUNCTION api.get_scheduler (
  pId		uuid
) RETURNS	api.scheduler
AS $$
  SELECT * FROM api.scheduler WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_scheduler ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список планировщиков.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.scheduler}
 */
CREATE OR REPLACE FUNCTION api.list_scheduler (
  pSearch	jsonb default null,
  pFilter	jsonb default null,
  pLimit	integer default null,
  pOffSet	integer default null,
  pOrderBy	jsonb default null
) RETURNS	SETOF api.scheduler
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'scheduler', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_scheduler_id --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает uuid по коду.
 * @param {text} pCode - Код планировщика
 * @return {uuid}
 */
CREATE OR REPLACE FUNCTION api.get_scheduler_id (
  pCode		text
) RETURNS	uuid
AS $$
BEGIN
  IF length(pCode) = 36 AND SubStr(pCode, 1, 15) = '4' THEN
    RETURN pCode;
  END IF;

  RETURN GetScheduler(pCode);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
