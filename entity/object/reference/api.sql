--------------------------------------------------------------------------------
-- REFERENCE -------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.reference ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.reference
AS
  SELECT * FROM ObjectReference;

GRANT SELECT ON api.reference TO administrator;

--------------------------------------------------------------------------------
-- api.add_reference -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Добавляет справочник.
 * @param {uuid} pParent - Ссылка на родительский объект: api.reference | null
 * @param {text} pType - Тип
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {text} pDescription - Описание
 * @return {uuid}
 */
CREATE OR REPLACE FUNCTION api.add_reference (
  pParent       uuid,
  pType         text,
  pCode			text,
  pName			text,
  pDescription  text DEFAULT null
) RETURNS       uuid
AS $$
BEGIN
  RETURN CreateReference(pParent, GetType(lower(pType)), pCode, pName, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_reference --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Редактирует справочник.
 * @param {uuid} pParent - Ссылка на родительский объект: Reference.Parent | null
 * @param {text} pType - Тип
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.update_reference (
  pId           uuid,
  pParent       uuid DEFAULT null,
  pType         text DEFAULT null,
  pCode         text DEFAULT null,
  pName         text DEFAULT null,
  pDescription  text DEFAULT null
) RETURNS       void
AS $$
DECLARE
  uType         uuid;
  uReference    uuid;
BEGIN
  SELECT t.id INTO uReference FROM db.reference t WHERE t.id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('справочник', 'id', pId);
  END IF;

  IF pType IS NOT NULL THEN
    uType := GetType(lower(pType));
  ELSE
    SELECT o.type INTO uType FROM db.object o WHERE o.id = pId;
  END IF;

  PERFORM EditReference(uReference, pParent, uType, pCode, pName, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_reference -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_reference (
  pId           uuid,
  pParent       uuid DEFAULT null,
  pType         text DEFAULT null,
  pCode         text DEFAULT null,
  pName         text DEFAULT null,
  pDescription  text DEFAULT null
) RETURNS       SETOF api.reference
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_reference(pParent, pType, pCode, pName, pDescription);
  ELSE
    PERFORM api.update_reference(pId, pParent, pType, pCode, pName, pDescription);
  END IF;

  RETURN QUERY SELECT * FROM api.reference WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_reference -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает справочник
 * @param {uuid} pId - Идентификатор
 * @return {api.reference}
 */
CREATE OR REPLACE FUNCTION api.get_reference (
  pId        uuid
) RETURNS    api.reference
AS $$
  SELECT * FROM api.reference WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_reference ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список справочников.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.reference}
 */
CREATE OR REPLACE FUNCTION api.list_reference (
  pSearch    jsonb DEFAULT null,
  pFilter    jsonb DEFAULT null,
  pLimit     integer DEFAULT null,
  pOffSet    integer DEFAULT null,
  pOrderBy   jsonb DEFAULT null
) RETURNS    SETOF api.reference
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'reference', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
