--------------------------------------------------------------------------------
-- TASK ------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.task --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.task
AS
  SELECT * FROM ObjectTask;

GRANT SELECT ON api.task TO administrator;

--------------------------------------------------------------------------------
-- api.add_task ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Добавляет задачу.
 * @param {numeric} pParent - Ссылка на родительский объект: api.document | null
 * @param {varchar} pType - Tип
 * @param {varchar} pCode - Код
 * @param {varchar} pLabel - Метка
 * @param {numeric} pCalendar - Календарь
 * @param {numeric} pScheduler - Планировщик
 * @param {numeric} pProgram - Программа
 * @param {numeric} pExecutor - Исполнитель
 * @param {timestamptz} pDateRun - Дата запуска
 * @param {text} pDescription - Описание
 * @return {numeric}
 */
CREATE OR REPLACE FUNCTION api.add_task (
  pParent           numeric,
  pType             varchar,
  pCode             varchar,
  pLabel            varchar,
  pCalendar         numeric default null,
  pScheduler        numeric default null,
  pProgram          numeric default null,
  pExecutor         numeric default null,
  pDateRun          timestamptz default null,
  pDescription      text default null
) RETURNS           numeric
AS $$
BEGIN
  pCalendar := coalesce(pCalendar, GetCalendar('default.calendar'));
  RETURN CreateTask(pParent, CodeToType(lower(coalesce(pType, 'disposable.task')), 'task'), pCode, pLabel, pCalendar, pScheduler, pProgram, pExecutor, pDateRun, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_task -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Редактирует задачу.
 * @param {numeric} pParent - Ссылка на родительский объект: Object.Parent | null
 * @param {varchar} pType - Tип
 * @param {varchar} pCode - Код
 * @param {varchar} pLabel - Метка
 * @param {numeric} pCalendar - Календарь
 * @param {numeric} pScheduler - Планировщик
 * @param {numeric} pProgram - Программа
 * @param {numeric} pExecutor - Исполнитель
 * @param {timestamptz} pDateRun - Дата запуска
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.update_task (
  pId               numeric,
  pParent           numeric default null,
  pType             varchar default null,
  pCode             varchar default null,
  pLabel            varchar default null,
  pCalendar         numeric default null,
  pScheduler        numeric default null,
  pProgram          numeric default null,
  pExecutor         numeric default null,
  pDateRun          timestamptz default null,
  pDescription      text default null
) RETURNS           void
AS $$
DECLARE
  nType             numeric;
  nTask             numeric;
BEGIN
  SELECT c.id INTO nTask FROM db.task c WHERE c.id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('задача', 'id', pId);
  END IF;

  IF pType IS NOT NULL THEN
    nType := CodeToType(lower(pType), 'task');
  ELSE
    SELECT o.type INTO nType FROM db.object o WHERE o.id = pId;
  END IF;

  PERFORM EditTask(nTask, pParent, nType,pCode, pLabel, pCalendar, pScheduler, pProgram, pExecutor, pDateRun, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_task ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_task (
  pId               numeric,
  pParent           numeric default null,
  pType             varchar default null,
  pCode             varchar default null,
  pLabel            varchar default null,
  pCalendar         numeric default null,
  pScheduler        numeric default null,
  pProgram          numeric default null,
  pExecutor         numeric default null,
  pDateRun          timestamptz default null,
  pDescription      text default null
) RETURNS           SETOF api.task
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_task(pParent, pType, pCode, pLabel, pCalendar, pScheduler, pProgram, pExecutor, pDateRun, pDescription);
  ELSE
    PERFORM api.update_task(pId, pParent, pType, pCode, pLabel, pCalendar, pScheduler, pProgram, pExecutor, pDateRun, pDescription);
  END IF;

  RETURN QUERY SELECT * FROM api.task WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_task ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает задачу
 * @param {numeric} pId - Идентификатор
 * @return {api.task} - Счёт
 */
CREATE OR REPLACE FUNCTION api.get_task (
  pId		numeric
) RETURNS	api.task
AS $$
  SELECT * FROM api.task WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_task ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список задач.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.task}
 */
CREATE OR REPLACE FUNCTION api.list_task (
  pSearch	jsonb default null,
  pFilter	jsonb default null,
  pLimit	integer default null,
  pOffSet	integer default null,
  pOrderBy	jsonb default null
) RETURNS	SETOF api.task
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'task', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
