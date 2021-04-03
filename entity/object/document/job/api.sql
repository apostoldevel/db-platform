--------------------------------------------------------------------------------
-- JOB -------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.job ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.job
AS
  SELECT * FROM ObjectJob;

GRANT SELECT ON api.job TO administrator;

--------------------------------------------------------------------------------
-- FUNCTION api.job ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.job (
  pStateType	uuid,
  pDateRun		timestamptz DEFAULT Now()
) RETURNS		SETOF api.job
AS $$
  SELECT * FROM api.job WHERE statetype = pStateType AND dateRun <= pDateRun;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION api.job ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.job (
  pStateType	text DEFAULT 'enabled',
  pDateFrom		double precision DEFAULT null
) RETURNS		SETOF api.job
AS $$
  SELECT * FROM api.job(GetStateType(pStateType), coalesce(to_timestamp(pDateFrom), Now()));
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.add_job -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Добавляет задание.
 * @param {uuid} pParent - Ссылка на родительский объект: api.document | null
 * @param {text} pType - Tип
 * @param {uuid} pScheduler - Планировщик
 * @param {uuid} pProgram - Программа
 * @param {timestamptz} pDateRun - Дата запуска
 * @param {text} pCode - Код
 * @param {text} pLabel - Метка
 * @param {text} pDescription - Описание
 * @return {uuid}
 */
CREATE OR REPLACE FUNCTION api.add_job (
  pParent           uuid,
  pType             text,
  pScheduler        uuid,
  pProgram          uuid,
  pDateRun          timestamptz default null,
  pCode             text default null,
  pLabel            text default null,
  pDescription      text default null
) RETURNS           uuid
AS $$
BEGIN
  RETURN CreateJob(pParent, CodeToType(lower(coalesce(pType, 'periodic.job')), 'job'), pScheduler, pProgram, pDateRun, pCode, pLabel, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_job --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Редактирует задание.
 * @param {uuid} pParent - Ссылка на родительский объект: Object.Parent | null
 * @param {text} pType - Tип
 * @param {uuid} pScheduler - Планировщик
 * @param {uuid} pProgram - Программа
 * @param {timestamptz} pDateRun - Дата запуска
 * @param {text} pCode - Код
 * @param {text} pLabel - Метка
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.update_job (
  pId               uuid,
  pParent           uuid default null,
  pType             text default null,
  pScheduler        uuid default null,
  pProgram          uuid default null,
  pDateRun          timestamptz default null,
  pCode             text default null,
  pLabel            text default null,
  pDescription      text default null
) RETURNS           void
AS $$
DECLARE
  uType             uuid;
  nJob				uuid;
BEGIN
  SELECT c.id INTO nJob FROM db.job c WHERE c.id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('задание', 'id', pId);
  END IF;

  IF pType IS NOT NULL THEN
    uType := CodeToType(lower(pType), 'job');
  ELSE
    SELECT o.type INTO uType FROM db.object o WHERE o.id = pId;
  END IF;

  PERFORM EditJob(nJob, pParent, uType, pScheduler, pProgram, pDateRun, pCode, pLabel, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_job -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_job (
  pId               uuid,
  pParent           uuid default null,
  pType             text default null,
  pScheduler        uuid default null,
  pProgram          uuid default null,
  pDateRun          timestamptz default null,
  pCode             text default null,
  pLabel            text default null,
  pDescription      text default null
) RETURNS           SETOF api.job
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_job(pParent, pType, pScheduler, pProgram, pDateRun, pCode, pLabel, pDescription);
  ELSE
    PERFORM api.update_job(pId, pParent, pType, pScheduler, pProgram, pDateRun, pCode, pLabel, pDescription);
  END IF;

  RETURN QUERY SELECT * FROM api.job WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_job -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает задание
 * @param {uuid} pId - Идентификатор
 * @return {api.job} - Счёт
 */
CREATE OR REPLACE FUNCTION api.get_job (
  pId		uuid
) RETURNS	api.job
AS $$
  SELECT * FROM api.job WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_job ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает задание в виде списока.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.job}
 */
CREATE OR REPLACE FUNCTION api.list_job (
  pSearch	jsonb default null,
  pFilter	jsonb default null,
  pLimit	integer default null,
  pOffSet	integer default null,
  pOrderBy	jsonb default null
) RETURNS	SETOF api.job
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'job', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
