--------------------------------------------------------------------------------
-- DOCUMENT --------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.document ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.document
AS
  SELECT * FROM Document;

GRANT SELECT ON api.document TO administrator;

--------------------------------------------------------------------------------
-- api.add_document ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Добавляет документ.
 * @param {numeric} pParent - Ссылка на родительский объект: api.document | null
 * @param {varchar} pType - Тип
 * @param {text} pLabel - Метка
 * @param {text} pDescription - Описание
 * @return {numeric}
 */
CREATE OR REPLACE FUNCTION api.add_document (
  pParent       numeric,
  pType         varchar,
  pLabel        text default null,
  pDescription  text DEFAULT null
) RETURNS       numeric
AS $$
BEGIN
  RETURN CreateDocument(pParent, GetType(lower(pType)), pLabel, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_document ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Меняет документ.
 * @param {numeric} pParent - Ссылка на родительский объект: Document.Parent | null
 * @param {varchar} pType - Тип
 * @param {text} pLabel - Метка
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.update_document (
  pId		    numeric,
  pParent       numeric default null,
  pType         varchar default null,
  pLabel        text default null,
  pDescription  text DEFAULT null
) RETURNS       void
AS $$
DECLARE
  nType         numeric;
  nDocument       numeric;
BEGIN
  SELECT t.id INTO nDocument FROM db.document t WHERE t.id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('документ', 'id', pId);
  END IF;

  IF pType IS NOT NULL THEN
    nType := GetType(lower(pType));
  ELSE
    SELECT o.type INTO nType FROM db.object o WHERE o.id = pId;
  END IF;

  PERFORM EditDocument(nDocument, pParent, nType,pLabel, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_document ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_document (
  pId		    numeric,
  pParent       numeric default null,
  pType         varchar default null,
  pLabel        text default null,
  pDescription  text DEFAULT null
) RETURNS       SETOF api.document
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_document(pParent, pType, pLabel, pDescription);
  ELSE
    PERFORM api.update_document(pId, pParent, pType, pLabel, pDescription);
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
 * @param {numeric} pId - Идентификатор
 * @return {api.document}
 */
CREATE OR REPLACE FUNCTION api.get_document (
  pId		numeric
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
