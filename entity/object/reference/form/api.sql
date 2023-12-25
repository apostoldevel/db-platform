--------------------------------------------------------------------------------
-- FORM ------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.form --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.form
AS
  SELECT * FROM ObjectForm;

GRANT SELECT ON api.form TO administrator;

--------------------------------------------------------------------------------
-- api.add_form ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Добавляет форму.
 * @param {uuid} pParent - Идентификатор объекта родителя
 * @param {uuid} pType - Идентификатор типа
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {text} pDescription - Описание
 * @return {uuid}
 */
CREATE OR REPLACE FUNCTION api.add_form (
  pParent       uuid,
  pType         uuid,
  pCode         text,
  pName         text,
  pDescription  text default null
) RETURNS       uuid
AS $$
BEGIN
  RETURN CreateForm(pParent, coalesce(pType, GetType('none.form')), pCode, pName, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_form -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Редактирует форму.
 * @param {uuid} pId - Идентификатор
 * @param {uuid} pParent - Идентификатор объекта родителя
 * @param {uuid} pType - Идентификатор типа
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.update_form (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pCode         text default null,
  pName         text default null,
  pDescription  text default null
) RETURNS       void
AS $$
DECLARE
  uForm        uuid;
BEGIN
  SELECT id INTO uForm FROM db.form WHERE id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('форма', 'id', pId);
  END IF;

  PERFORM EditForm(pId, pParent, pType, pCode, pName, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_form ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_form (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pCode         text default null,
  pName         text default null,
  pDescription  text default null
) RETURNS       SETOF api.form
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_form(pParent, pType, pCode, pName, pDescription);
  ELSE
    PERFORM api.update_form(pId, pParent, pType, pCode, pName, pDescription);
  END IF;

  RETURN QUERY SELECT * FROM api.form WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_form ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает форму
 * @param {uuid} pId - Идентификатор
 * @return {api.form}
 */
CREATE OR REPLACE FUNCTION api.get_form (
  pId        uuid
) RETURNS    api.form
AS $$
  SELECT * FROM api.form WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_form ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список форм отчётов.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.form}
 */
CREATE OR REPLACE FUNCTION api.list_form (
  pSearch   jsonb default null,
  pFilter   jsonb default null,
  pLimit    integer default null,
  pOffSet   integer default null,
  pOrderBy  jsonb default null
) RETURNS   SETOF api.form
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'form', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.build_form --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт форму
 * @param {uuid} pId - Идентификатор
 * @return {SETOF json}
 */
CREATE OR REPLACE FUNCTION api.build_form (
  pId       uuid,
  pParams   json
) RETURNS   json
AS $$
DECLARE
  uForm     uuid;
BEGIN
  SELECT id INTO uForm FROM db.form WHERE id = pId;

  IF NOT FOUND THEN
    PERFORM NotFound();
  END IF;

  RETURN json_build_object('form', uForm, 'fields', BuildForm(uForm, pParams));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
