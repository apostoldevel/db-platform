--------------------------------------------------------------------------------
-- REPORT ----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.report_routine ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.report_routine
AS
  SELECT * FROM ObjectReportRoutine;

GRANT SELECT ON api.report_routine TO administrator;

--------------------------------------------------------------------------------
-- api.add_report_routine ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Добавляет функцию отчёта.
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
CREATE OR REPLACE FUNCTION api.add_report_routine (
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
BEGIN
  RETURN CreateReportRoutine(pParent, coalesce(pType, GetType('plpgsql.report_routine')), pReport, pCode, pName, pDefinition, pDescription, pSequence);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_report_routine ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Редактирует функцию отчёта.
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
CREATE OR REPLACE FUNCTION api.update_report_routine (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pReport       uuid default null,
  pCode         text default null,
  pName         text default null,
  pDefinition	text default null,
  pDescription	text default null,
  pSequence     integer default null
) RETURNS       void
AS $$
DECLARE
  uRoutine        uuid;
BEGIN
  SELECT id INTO uRoutine FROM db.report_routine WHERE id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('функция отчёта', 'id', pId);
  END IF;

  PERFORM EditReportRoutine(pId, pParent, pType, pReport, pCode, pName, pDefinition, pDescription, pSequence);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_report_routine ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_report_routine (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pReport       uuid default null,
  pCode         text default null,
  pName         text default null,
  pDefinition   text default null,
  pDescription	text default null,
  pSequence     integer default null
) RETURNS       SETOF api.report_routine
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_report_routine(pParent, pType, pReport, pCode, pName, pDefinition, pDescription, pSequence);
  ELSE
    PERFORM api.update_report_routine(pId, pParent, pType, pReport, pCode, pName, pDefinition, pDescription, pSequence);
  END IF;

  RETURN QUERY SELECT * FROM api.report_routine WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_report_routine ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает функцию отчёта
 * @param {uuid} pId - Идентификатор
 * @return {api.report_routine}
 */
CREATE OR REPLACE FUNCTION api.get_report_routine (
  pId		uuid
) RETURNS	api.report_routine
AS $$
  SELECT * FROM api.report_routine WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_report_routine -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список функций отчётов.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.report_routine}
 */
CREATE OR REPLACE FUNCTION api.list_report_routine (
  pSearch	jsonb default null,
  pFilter	jsonb default null,
  pLimit	integer default null,
  pOffSet	integer default null,
  pOrderBy	jsonb default null
) RETURNS	SETOF api.report_routine
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'report_routine', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.call_report_routine -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Вызывает функцию отчёта
 * @param {uuid} pId - Идентификатор функции отчёта
 * @param {json} pForm - Форма отчёта
 * @return {SETOF json}
 */
CREATE OR REPLACE FUNCTION api.call_report_routine (
  pId       uuid,
  pForm     json
) RETURNS	SETOF json
AS $$
BEGIN
  RETURN QUERY SELECT * FROM CallReportRoutine(pId, pForm);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
