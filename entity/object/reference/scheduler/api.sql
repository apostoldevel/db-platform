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
 * @param {numeric} pParent - Ссылка на родительский объект: api.document | null
 * @param {varchar} pType - Код типа
 * @param {varchar} pCode - Код
 * @param {varchar} pName - Наименование
 * @param {timestamptz} pDateStart - Дата начала выполнения
 * @param {timestamptz} pDateStop - Дата окончания выполнения
 * @param {interval} pPeriod - Период выполнения
 * @param {text} pDescription - Описание
 * @return {numeric}
 */
CREATE OR REPLACE FUNCTION api.add_scheduler (
  pParent       numeric,
  pType         varchar,
  pCode         varchar,
  pName         varchar,
  pDateStart    timestamptz default null,
  pDateStop     timestamptz default null,
  pPeriod       interval default null,
  pDescription	text default null
) RETURNS       numeric
AS $$
BEGIN
  RETURN CreateScheduler(pParent, CodeToType(lower(coalesce(pType, 'task')), 'scheduler'), pCode, pName, pDateStart, pDateStop, pPeriod, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_scheduler --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Редактирует планировщик.
 * @param {numeric} pParent - Ссылка на родительский объект: Object.Parent | null
 * @param {varchar} pType - Код типа
 * @param {varchar} pCode - Код
 * @param {varchar} pName - Наименование
 * @param {timestamptz} pDateStart - Дата начала выполнения
 * @param {timestamptz} pDateStop - Дата окончания выполнения
 * @param {interval} pPeriod - Период выполнения
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.update_scheduler (
  pId		    numeric,
  pParent       numeric default null,
  pType         varchar default null,
  pCode         varchar default null,
  pName         varchar default null,
  pDateStart    timestamptz default null,
  pDateStop     timestamptz default null,
  pPeriod       interval default null,
  pDescription	text default null
) RETURNS       void
AS $$
DECLARE
  nType         numeric;
  nScheduler    numeric;
BEGIN
  SELECT t.id INTO nScheduler FROM db.scheduler t WHERE t.id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('планировщик', 'id', pId);
  END IF;

  IF pType IS NOT NULL THEN
    nType := CodeToType(lower(pType), 'scheduler');
  ELSE
    SELECT o.type INTO nType FROM db.object o WHERE o.id = pId;
  END IF;

  PERFORM EditScheduler(nScheduler, pParent, nType, pCode, pName, pDateStart, pDateStop, pPeriod, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_scheduler -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_scheduler (
  pId           numeric,
  pParent       numeric default null,
  pType         varchar default null,
  pCode         varchar default null,
  pName         varchar default null,
  pDateStart    timestamptz default null,
  pDateStop     timestamptz default null,
  pPeriod       interval default null,
  pDescription	text default null
) RETURNS       SETOF api.scheduler
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_scheduler(pParent, pType, pCode, pName, pDateStart, pDateStop, pPeriod, pDescription);
  ELSE
    PERFORM api.update_scheduler(pId, pParent, pType, pCode, pName, pDateStart, pDateStop, pPeriod, pDescription);
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
 * @param {numeric} pId - Идентификатор
 * @return {api.scheduler}
 */
CREATE OR REPLACE FUNCTION api.get_scheduler (
  pId		numeric
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
