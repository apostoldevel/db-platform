--------------------------------------------------------------------------------
-- PROJECT ---------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.project -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.project
AS
  SELECT * FROM ObjectProject;

GRANT SELECT ON api.project TO administrator;

--------------------------------------------------------------------------------
-- api.add_project -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Добавляет проект.
 * @param {uuid} pParent - Ссылка на родительский объект: api.document | null
 * @param {text} pType - Тип
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {text} pDescription - Описание
 * @return {uuid}
 */
CREATE OR REPLACE FUNCTION api.add_project (
  pParent       uuid,
  pType         text,
  pCode         text,
  pName         text,
  pDescription	text default null
) RETURNS       uuid
AS $$
BEGIN
  RETURN CreateProject(pParent, CodeToType(lower(coalesce(pType, 'ship')), 'project'), pCode, pName, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_project ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Редактирует проект.
 * @param {uuid} pParent - Ссылка на родительский объект: Object.Parent | null
 * @param {text} pType - Тип
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.update_project (
  pId		    uuid,
  pParent       uuid default null,
  pType         text default null,
  pCode         text default null,
  pName         text default null,
  pDescription	text default null
) RETURNS       void
AS $$
DECLARE
  nType         uuid;
  nProject       uuid;
BEGIN
  SELECT t.id INTO nProject FROM db.project t WHERE t.id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('проект', 'id', pId);
  END IF;

  IF pType IS NOT NULL THEN
    nType := CodeToType(lower(pType), 'project');
  ELSE
    SELECT o.type INTO nType FROM db.object o WHERE o.id = pId;
  END IF;

  PERFORM EditProject(nProject, pParent, nType, pCode, pName, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_project -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_project (
  pId           uuid,
  pParent       uuid default null,
  pType         text default null,
  pCode         text default null,
  pName         text default null,
  pDescription	text default null
) RETURNS       SETOF api.project
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_project(pParent, pType, pCode, pName, pDescription);
  ELSE
    PERFORM api.update_project(pId, pParent, pType, pCode, pName, pDescription);
  END IF;

  RETURN QUERY SELECT * FROM api.project WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_project -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает проект
 * @param {uuid} pId - Идентификатор
 * @return {api.project}
 */
CREATE OR REPLACE FUNCTION api.get_project (
  pId		uuid
) RETURNS	api.project
AS $$
  SELECT * FROM api.project WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_project ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список проектов.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.project}
 */
CREATE OR REPLACE FUNCTION api.list_project (
  pSearch	jsonb default null,
  pFilter	jsonb default null,
  pLimit	integer default null,
  pOffSet	integer default null,
  pOrderBy	jsonb default null
) RETURNS	SETOF api.project
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'project', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
