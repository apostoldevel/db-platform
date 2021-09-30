--------------------------------------------------------------------------------
-- DOCUMENT --------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.document ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.document
AS
  SELECT * FROM SafeDocument;

GRANT SELECT ON api.document TO administrator;

--------------------------------------------------------------------------------
-- api.add_document ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Добавляет документ.
 * @param {uuid} pParent - Ссылка на родительский объект: api.document | null
 * @param {uuid} pType - Идентификатор типа
 * @param {text} pLabel - Метка
 * @param {text} pDescription - Описание
 * @param {text} pData - Данные
 * @return {uuid}
 */
CREATE OR REPLACE FUNCTION api.add_document (
  pParent       uuid,
  pType         uuid,
  pLabel        text default null,
  pDescription  text DEFAULT null,
  pData			text DEFAULT null
) RETURNS       uuid
AS $$
BEGIN
  RETURN CreateDocument(pParent, pType, pLabel, pDescription, pData);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_document ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Редактирует документ.
 * @param {uuid} pParent - Ссылка на родительский объект: Document.Parent | null
 * @param {uuid} pType - Идентификатор типа
 * @param {text} pLabel - Метка
 * @param {text} pDescription - Описание
 * @param {text} pData - Данные
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.update_document (
  pId		    uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pLabel        text default null,
  pDescription  text DEFAULT null,
  pData			text DEFAULT null
) RETURNS       void
AS $$
DECLARE
  uDocument		uuid;
BEGIN
  SELECT t.id INTO uDocument FROM db.document t WHERE t.id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('документ', 'id', pId);
  END IF;

  PERFORM EditDocument(uDocument, pParent, pType,pLabel, pDescription, pData, current_locale());
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_document ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_document (
  pId		    uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pLabel        text default null,
  pDescription  text DEFAULT null,
  pData			text DEFAULT null
) RETURNS       SETOF api.document
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_document(pParent, pType, pLabel, pDescription, pData);
  ELSE
    PERFORM api.update_document(pId, pParent, pType, pLabel, pDescription, pData);
  END IF;

  RETURN QUERY SELECT * FROM api.document WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_document ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает документ
 * @param {uuid} pId - Идентификатор
 * @return {api.document}
 */
CREATE OR REPLACE FUNCTION api.get_document (
  pId		uuid
) RETURNS	api.document
AS $$
  SELECT * FROM api.document WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_document -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список документов.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.document}
 */
CREATE OR REPLACE FUNCTION api.list_document (
  pSearch	jsonb default null,
  pFilter	jsonb default null,
  pLimit	integer default null,
  pOffSet	integer default null,
  pOrderBy	jsonb default null
) RETURNS	SETOF api.document
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'document', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.change_document_area ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.change_document_area (
  pId		    uuid,
  pArea         uuid
) RETURNS       SETOF api.document
AS $$
BEGIN
  PERFORM ChangeDocumentArea(pId, pArea);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
