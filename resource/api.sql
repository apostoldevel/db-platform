--------------------------------------------------------------------------------
-- RESOURCE --------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.resource ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.resource
AS
  SELECT * FROM Resource;

GRANT SELECT ON api.resource TO administrator;

--------------------------------------------------------------------------------
-- api.resource_tree -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.resource_tree
AS
  SELECT * FROM ResourceTree;

GRANT SELECT ON api.resource_tree TO administrator;

--------------------------------------------------------------------------------
-- api.create_resource ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт ресурс
 * @param {uuid} pId - Идентификатор
 * @param {uuid} pRoot - Идентификатор корневого узла (Передать null для создания корневого узла)
 * @param {uuid} pNode - Идентификатор узла родителя
 * @param {text} pType - MIME тип
 * @param {text} pName - Наименование
 * @param {text} pDescription - Описание
 * @param {text} pEncoding - Кодировка
 * @param {text} pData - Данные
 * @param {integer} pSequence - Очерёдность
 * @param {text} pLocaleCode - Код локали
 * @return {uuid}
 */
CREATE OR REPLACE FUNCTION api.create_resource (
  pId           uuid,
  pRoot         uuid,
  pNode         uuid,
  pType         text,
  pName         text,
  pDescription  text DEFAULT null,
  pEncoding     text DEFAULT null,
  pData         text DEFAULT null,
  pSequence     integer DEFAULT null,
  pLocaleCode   text DEFAULT locale_code()
) RETURNS       uuid
AS $$
DECLARE
  uLocale        uuid;
BEGIN
  SELECT id INTO uLocale FROM db.locale WHERE code = pLocaleCode;

  IF NOT FOUND THEN
    PERFORM IncorrectLocaleCode(pLocaleCode);
  END IF;

  RETURN CreateResource(pId, pRoot, pNode, pType, pName, pDescription, pEncoding, pData, pSequence, uLocale);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_resource ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Обновляет ресурс
 * @param {uuid} pId - Идентификатор
 * @param {uuid} pRoot - Идентификатор корневого узла
 * @param {uuid} pNode - Идентификатор узла родителя
 * @param {text} pType - MIME тип
 * @param {text} pName - Наименование
 * @param {text} pDescription - Описание
 * @param {text} pEncoding - Кодировка
 * @param {text} pData - Данные
 * @param {integer} pSequence - Очерёдность
 * @param {text} pLocaleCode - Код локали
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.update_resource (
  pId           uuid,
  pRoot         uuid DEFAULT null,
  pNode         uuid DEFAULT null,
  pType         text DEFAULT null,
  pName         text DEFAULT null,
  pDescription  text DEFAULT null,
  pEncoding     text DEFAULT null,
  pData         text DEFAULT null,
  pSequence     integer DEFAULT null,
  pLocaleCode   text DEFAULT locale_code()
) RETURNS       void
AS $$
DECLARE
  uLocale       uuid;
BEGIN
  SELECT id INTO uLocale FROM db.locale WHERE code = pLocaleCode;

  IF NOT FOUND THEN
    PERFORM IncorrectLocaleCode(pLocaleCode);
  END IF;

  PERFORM UpdateResource(pId, pRoot, pNode, pType, pName, pDescription, pEncoding, pData, pSequence, uLocale);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_resource ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_resource (
  pId           uuid,
  pRoot         uuid DEFAULT null,
  pNode         uuid DEFAULT null,
  pType         text DEFAULT null,
  pName         text DEFAULT null,
  pDescription  text DEFAULT null,
  pEncoding     text DEFAULT null,
  pData         text DEFAULT null,
  pSequence     integer DEFAULT null,
  pLocaleCode   text DEFAULT locale_code()
) RETURNS       SETOF api.resource
AS $$
DECLARE
  uLocale       uuid;
  uResource     uuid;
BEGIN
  SELECT id INTO uLocale FROM db.locale WHERE code = pLocaleCode;

  IF NOT FOUND THEN
    PERFORM IncorrectLocaleCode(pLocaleCode);
  END IF;

  uResource := SetResource(pId, pRoot, pNode, pType, pName, pDescription, pEncoding, pData, pSequence, uLocale);

  RETURN QUERY SELECT * FROM api.resource WHERE id = uResource;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_resource ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает ресурс
 * @param {uuid} pId - Идентификатор
 * @return {api.resource}
 */
CREATE OR REPLACE FUNCTION api.get_resource (
  pId       uuid
) RETURNS   SETOF api.resource
AS $$
  SELECT * FROM api.resource WHERE id = pId AND CheckObjectAccess(id, B'100')
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.delete_resource ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет ресурс.
 * @param {uuid} pId - Идентификатор
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.delete_resource (
  pId       uuid
) RETURNS   void
AS $$
BEGIN
  PERFORM DeleteResource(pId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_resource -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список ресурсов.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.resource}
 */
CREATE OR REPLACE FUNCTION api.list_resource (
  pSearch   jsonb default null,
  pFilter   jsonb default null,
  pLimit    integer default null,
  pOffSet   integer default null,
  pOrderBy  jsonb default null
) RETURNS   SETOF api.resource
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'resource', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
