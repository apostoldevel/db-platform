--------------------------------------------------------------------------------
-- REPORT ----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.report_form -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.report_form
AS
  SELECT * FROM ObjectReportForm;

GRANT SELECT ON api.report_form TO administrator;

--------------------------------------------------------------------------------
-- api.add_report_form ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Добавляет форму отчёта.
 * @param {uuid} pParent - Идентификатор объекта родителя
 * @param {uuid} pType - Идентификатор типа
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {text} pDefinition - PL/pgSQL код
 * @param {text} pDescription - Описание
 * @return {uuid}
 */
CREATE OR REPLACE FUNCTION api.add_report_form (
  pParent       uuid,
  pType         uuid,
  pCode         text,
  pName         text,
  pDefinition   text,
  pDescription  text default null
) RETURNS       uuid
AS $$
BEGIN
  RETURN CreateReportForm(pParent, coalesce(pType, GetType('json.report_form')), pCode, pName, pDefinition, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_report_form ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Редактирует форму отчёта.
 * @param {uuid} pId - Идентификатор
 * @param {uuid} pParent - Идентификатор объекта родителя
 * @param {uuid} pType - Идентификатор типа
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {text} pDefinition - PL/pgSQL код
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.update_report_form (
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
  uForm        uuid;
BEGIN
  SELECT id INTO uForm FROM db.report_form WHERE id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('форма отчёта', 'id', pId);
  END IF;

  PERFORM EditReportForm(pId, pParent, pType, pCode, pName, pDefinition, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_report_form ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_report_form (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pCode         text default null,
  pName         text default null,
  pDefinition   text default null,
  pDescription  text default null
) RETURNS       SETOF api.report_form
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_report_form(pParent, pType, pCode, pName, pDefinition, pDescription);
  ELSE
    PERFORM api.update_report_form(pId, pParent, pType, pCode, pName, pDefinition, pDescription);
  END IF;

  RETURN QUERY SELECT * FROM api.report_form WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_report_form ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает форму отчёта
 * @param {uuid} pId - Идентификатор
 * @return {api.report_form}
 */
CREATE OR REPLACE FUNCTION api.get_report_form (
  pId		uuid
) RETURNS	api.report_form
AS $$
  SELECT * FROM api.report_form WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_report_form --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список форм отчётов.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.report_form}
 */
CREATE OR REPLACE FUNCTION api.list_report_form (
  pSearch	jsonb default null,
  pFilter	jsonb default null,
  pLimit	integer default null,
  pOffSet	integer default null,
  pOrderBy	jsonb default null
) RETURNS	SETOF api.report_form
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'report_form', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.build_report_form -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт форму отчёта
 * @param {uuid} pId - Идентификатор отчёта
 * @return {SETOF json}
 */
CREATE OR REPLACE FUNCTION api.build_report_form (
  pId       uuid,
  pParams   json
) RETURNS	json
AS $$
DECLARE
  uForm     uuid;
BEGIN
  SELECT id INTO uForm FROM db.report_form WHERE id = pId;

  IF NOT FOUND THEN
    SELECT form INTO uForm FROM db.report WHERE id = pId;
    IF NOT FOUND THEN
	  PERFORM NotFound();
	END IF;
  END IF;

  RETURN BuildReportForm(uForm, pParams);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
