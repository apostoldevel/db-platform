--------------------------------------------------------------------------------
-- PROGRAM ---------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.program -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.program
AS
  SELECT * FROM ObjectProgram;

GRANT SELECT ON api.program TO administrator;

--------------------------------------------------------------------------------
-- api.add_program -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Добавляет программу.
 * @param {uuid} pParent - Ссылка на родительский объект: api.document | null
 * @param {text} pType - Тип
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {text} pBody - Тело
 * @param {text} pDescription - Описание
 * @return {uuid}
 */
CREATE OR REPLACE FUNCTION api.add_program (
  pParent       uuid,
  pType         text,
  pCode         text,
  pName         text,
  pBody         text,
  pDescription	text default null
) RETURNS       uuid
AS $$
BEGIN
  RETURN CreateProgram(pParent, CodeToType(lower(coalesce(pType, 'plpgsql')), 'program'), pCode, pName, pBody, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_program ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Редактирует программу.
 * @param {uuid} pParent - Ссылка на родительский объект: Object.Parent | null
 * @param {text} pType - Тип
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {text} pBody - Тело
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.update_program (
  pId		    uuid,
  pParent       uuid default null,
  pType         text default null,
  pCode         text default null,
  pName         text default null,
  pBody         text default null,
  pDescription	text default null
) RETURNS       void
AS $$
DECLARE
  uType         uuid;
  nProgram      uuid;
BEGIN
  SELECT t.id INTO nProgram FROM db.program t WHERE t.id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('программа', 'id', pId);
  END IF;

  IF pType IS NOT NULL THEN
    uType := CodeToType(lower(pType), 'program');
  ELSE
    SELECT o.type INTO uType FROM db.object o WHERE o.id = pId;
  END IF;

  PERFORM EditProgram(nProgram, pParent, uType, pCode, pName, pBody, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_program -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_program (
  pId           uuid,
  pParent       uuid default null,
  pType         text default null,
  pCode         text default null,
  pName         text default null,
  pBody         text default null,
  pDescription	text default null
) RETURNS       SETOF api.program
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_program(pParent, pType, pCode, pName, pBody, pDescription);
  ELSE
    PERFORM api.update_program(pId, pParent, pType, pCode, pName, pBody, pDescription);
  END IF;

  RETURN QUERY SELECT * FROM api.program WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_program -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает программу
 * @param {uuid} pId - Идентификатор
 * @return {api.program}
 */
CREATE OR REPLACE FUNCTION api.get_program (
  pId		uuid
) RETURNS	api.program
AS $$
  SELECT * FROM api.program WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_program ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список программ.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.program}
 */
CREATE OR REPLACE FUNCTION api.list_program (
  pSearch	jsonb default null,
  pFilter	jsonb default null,
  pLimit	integer default null,
  pOffSet	integer default null,
  pOrderBy	jsonb default null
) RETURNS	SETOF api.program
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'program', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
