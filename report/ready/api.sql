--------------------------------------------------------------------------------
-- REPORT ----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.report_ready ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.report_ready
AS
  SELECT * FROM ObjectReportReady;

GRANT SELECT ON api.report_ready TO administrator;

--------------------------------------------------------------------------------
-- FUNCTION api.report_ready ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.report_ready (
  pStateType    uuid,
  OUT id        uuid,
  OUT typecode  text,
  OUT statecode text,
  OUT created   timestamptz
) RETURNS       SETOF record
AS $$
  SELECT r.id, t.code, s.code, o.pdate
    FROM db.report_ready r INNER JOIN db.object  o ON r.document = o.id
                           INNER JOIN db.type    t ON o.type = t.id
                           INNER JOIN db.state   s ON o.state = s.id
     WHERE o.state_type = pStateType
       AND o.scope = current_scope();
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION api.report_ready ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.report_ready (
  pStateType    text DEFAULT 'enabled',
  OUT id        uuid,
  OUT typecode  text,
  OUT statecode text,
  OUT created   timestamptz
) RETURNS       SETOF record
AS $$
  SELECT * FROM api.report_ready(GetStateType(pStateType));
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.add_report_ready --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Добавляет готовый отчёт.
 * @param {uuid} pParent - Ссылка на родительский объект: api.document | null
 * @param {uuid} pType - Идентификатор типа
 * @param {uuid} pReport - Отчёт
 * @param {jsonb} pForm - Форма
 * @param {text} pLabel - Метка
 * @param {text} pDescription - Описание
 * @return {uuid}
 */
CREATE OR REPLACE FUNCTION api.add_report_ready (
  pParent       uuid,
  pType         uuid,
  pReport       uuid,
  pForm         jsonb default null,
  pLabel        text default null,
  pDescription  text default null
) RETURNS       uuid
AS $$
BEGIN
  RETURN CreateReportReady(pParent, coalesce(pType, GetType('sync.report_ready')), pReport, pForm, pLabel, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_report_ready -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Редактирует готовый отчёт.
 * @param {uuid} pParent - Ссылка на родительский объект: Object.Parent | null
 * @param {uuid} pType - Идентификатор типа
 * @param {uuid} pReport - Отчёт
 * @param {jsonb} pForm - Форма
 * @param {text} pLabel - Метка
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.update_report_ready (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pReport       uuid default null,
  pForm         jsonb default null,
  pLabel        text default null,
  pDescription  text default null
) RETURNS       void
AS $$
DECLARE
  uId           uuid;
BEGIN
  SELECT c.id INTO uId FROM db.report_ready c WHERE c.id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('готовый отчёт', 'id', pId);
  END IF;

  PERFORM EditReportReady(uId, pParent, pType, pReport, pForm, pLabel, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_report_ready --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_report_ready (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pReport       uuid default null,
  pForm         jsonb default null,
  pLabel        text default null,
  pDescription  text default null
) RETURNS       SETOF api.report_ready
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_report_ready(pParent, pType, pReport, pForm, pLabel, pDescription);
  ELSE
    PERFORM api.update_report_ready(pId, pParent, pType, pReport, pForm, pLabel, pDescription);
  END IF;

  RETURN QUERY SELECT * FROM api.report_ready WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_report_ready --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает готовый отчёт
 * @param {uuid} pId - Идентификатор
 * @return {api.report_ready} - Ордер
 */
CREATE OR REPLACE FUNCTION api.get_report_ready (
  pId       uuid
) RETURNS   api.report_ready
AS $$
  SELECT * FROM api.report_ready WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_report_ready -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список готовых отчётов.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.report_ready}
 */
CREATE OR REPLACE FUNCTION api.list_report_ready (
  pSearch   jsonb default null,
  pFilter   jsonb default null,
  pLimit    integer default null,
  pOffSet   integer default null,
  pOrderBy  jsonb default null
) RETURNS   SETOF api.report_ready
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'report_ready', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.build_report ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Построить отчёт
 * @param {uuid} pReport - Идентификатор отчёта
 * @param {jsonb} pForm - Форма отчёта
 * @return {uuid} - Идентификатор готового отчёта (api.report_ready)
 */
CREATE OR REPLACE FUNCTION api.build_report (
  pReport   uuid,
  pForm     jsonb
) RETURNS   SETOF api.report_ready
AS $$
DECLARE
  uId       uuid;
BEGIN
  uId := BuildReport(pReport, GetType('sync.report_ready'), pForm);
  RETURN QUERY SELECT * FROM api.report_ready WHERE id = uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.execute_report_ready ----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Выполнить готовый отчёт
 * @param {uuid} pId - Идентификатор готового отчёта
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.execute_report_ready (
  pId       uuid
) RETURNS   void
AS $$
BEGIN
  PERFORM ExecuteReportReady(pId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

