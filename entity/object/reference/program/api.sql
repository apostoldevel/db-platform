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
 * @param {numeric} pParent - Ссылка на родительский объект: api.document | null
 * @param {varchar} pType - Тип
 * @param {varchar} pCode - Код
 * @param {varchar} pName - Наименование
 * @param {text} pBody - Тело
 * @param {text} pDescription - Описание
 * @return {numeric}
 */
CREATE OR REPLACE FUNCTION api.add_program (
  pParent       numeric,
  pType         varchar,
  pCode         varchar,
  pName         varchar,
  pBody         text,
  pDescription	text default null
) RETURNS       numeric
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
 * @param {numeric} pParent - Ссылка на родительский объект: Object.Parent | null
 * @param {varchar} pType - Тип
 * @param {varchar} pCode - Код
 * @param {varchar} pName - Наименование
 * @param {text} pBody - Тело
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.update_program (
  pId		    numeric,
  pParent       numeric default null,
  pType         varchar default null,
  pCode         varchar default null,
  pName         varchar default null,
  pBody         text default null,
  pDescription	text default null
) RETURNS       void
AS $$
DECLARE
  nType         numeric;
  nProgram      numeric;
BEGIN
  SELECT t.id INTO nProgram FROM db.program t WHERE t.id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('программа', 'id', pId);
  END IF;

  IF pType IS NOT NULL THEN
    nType := CodeToType(lower(pType), 'program');
  ELSE
    SELECT o.type INTO nType FROM db.object o WHERE o.id = pId;
  END IF;

  PERFORM EditProgram(nProgram, pParent, nType, pCode, pName, pBody, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_program -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_program (
  pId           numeric,
  pParent       numeric default null,
  pType         varchar default null,
  pCode         varchar default null,
  pName         varchar default null,
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
 * @param {numeric} pId - Идентификатор
 * @return {api.program}
 */
CREATE OR REPLACE FUNCTION api.get_program (
  pId		numeric
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
