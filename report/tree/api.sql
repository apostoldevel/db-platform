--------------------------------------------------------------------------------
-- REPORT ----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.report_tree -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.report_tree
AS
  SELECT * FROM ObjectReportTree;

GRANT SELECT ON api.report_tree TO administrator;

--------------------------------------------------------------------------------
-- api.add_report_tree ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Добавляет дерево отчётов.
 * @param {uuid} pParent - Ссылка на родительский объект: api.document | null
 * @param {uuid} pType - Идентификатор типа
 * @param {uuid} pRoot - Идентификатор корневого узла (Передать null_uuid для создания корневого узла)
 * @param {uuid} pNode - Идентификатор узла родителя
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {text} pDescription - Описание
 * @param {integer} pSequence - Очерёдность
 * @return {uuid}
 */
CREATE OR REPLACE FUNCTION api.add_report_tree (
  pParent       uuid,
  pType         uuid,
  pRoot         uuid,
  pNode         uuid,
  pCode         text,
  pName         text,
  pDescription  text default null,
  pSequence     integer default null
) RETURNS       uuid
AS $$
BEGIN
  RETURN CreateReportTree(pParent, coalesce(pType, GetType('report.report_tree')), pRoot, pNode, pCode, pName, pDescription, pSequence);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_report_tree ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Редактирует дерево отчётов.
 * @param {uuid} pParent - Ссылка на родительский объект: Object.Parent | null
 * @param {uuid} pType - Идентификатор типа
 * @param {uuid} pRoot - Идентификатор корневого узла
 * @param {uuid} pNode - Идентификатор узла родителя
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {text} pDescription - Описание
 * @param {integer} pSequence - Очерёдность
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.update_report_tree (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pRoot         uuid default null,
  pNode         uuid default null,
  pCode         text default null,
  pName         text default null,
  pDescription  text default null,
  pSequence     integer default null
) RETURNS       void
AS $$
DECLARE
  uReportTree   uuid;
BEGIN
  SELECT t.id INTO uReportTree FROM db.report_tree t WHERE t.id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('дерево отчётов', 'id', pId);
  END IF;

  PERFORM EditReportTree(uReportTree, pParent, pType,pRoot, pNode, pCode, pName, pDescription, pSequence);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_report_tree ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_report_tree (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pRoot         uuid default null,
  pNode         uuid default null,
  pCode         text default null,
  pName         text default null,
  pDescription  text default null,
  pSequence     integer default null
) RETURNS       SETOF api.report_tree
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_report_tree(pParent, pType, pRoot, pNode, pCode, pName, pDescription, pSequence);
  ELSE
    PERFORM api.update_report_tree(pId, pParent, pType, pRoot, pNode, pCode, pName, pDescription, pSequence);
  END IF;

  RETURN QUERY SELECT * FROM api.report_tree WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_report_tree ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает дерево отчётов
 * @param {uuid} pId - Идентификатор
 * @return {api.report_tree}
 */
CREATE OR REPLACE FUNCTION api.get_report_tree (
  pId        uuid
) RETURNS    api.report_tree
AS $$
  SELECT * FROM api.report_tree WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_report_tree --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает дерево отчётов в виде списка.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.report_tree}
 */
CREATE OR REPLACE FUNCTION api.list_report_tree (
  pSearch   jsonb default null,
  pFilter   jsonb default null,
  pLimit    integer default null,
  pOffSet   integer default null,
  pOrderBy  jsonb default null
) RETURNS   SETOF api.report_tree
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'report_tree', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
