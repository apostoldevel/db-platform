--------------------------------------------------------------------------------
-- NOTICE ----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.notice ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.notice
AS
  WITH cu AS (
    SELECT current_userid() AS userid
  )
  SELECT * FROM Notice n INNER JOIN cu USING (userid);

GRANT SELECT ON api.notice TO administrator;

--------------------------------------------------------------------------------
-- FUNCTION api.notice ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.notice (
) RETURNS		SETOF api.notice
AS $$
  SELECT * FROM api.notice
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION api.notice ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.notice (
  pCategory		text
) RETURNS		SETOF api.notice
AS $$
  SELECT * FROM api.notice WHERE category = pCategory;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.add_notice --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Добавляет извещение.
 * @param {uuid} pUserId - Идентификатор пользователя
 * @param {uuid} pObject - Идентификатор объекта
 * @param {text} pText - Текст извещения
 * @param {text} pCategory - Категория извещения
 * @param {integer} pStatus - Статус: 0 - создано; 1 - доставлено; 2 - прочитано; 3 - принято; 4 - отказано
 * @param {json} pData - Данные в произвольном формате
 * @return {uuid} - Идентификатор извещения
 */
CREATE OR REPLACE FUNCTION api.add_notice (
  pUserId		uuid,
  pObject		uuid,
  pText			text,
  pCategory		text default null,
  pStatus		integer default null
) RETURNS		uuid
AS $$
BEGIN
  RETURN CreateNotice(coalesce(pUserId, current_userid()), pObject, pText, pCategory, pStatus);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_notice -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Редактирует извещение.
 * @param {uuid} pId - Идентификатор извещения
 * @param {uuid} pUserId - Идентификатор пользователя
 * @param {uuid} pObject - Идентификатор объекта
 * @param {text} pText - Текст извещения
 * @param {text} pCategory - Категория извещения
 * @param {integer} pStatus - Статус: 0 - создано; 1 - доставлено; 2 - прочитано; 3 - принято; 4 - отказано
 * @param {json} pData - Данные в произвольном формате
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.update_notice (
  pId			uuid,
  pUserId		uuid default null,
  pObject		uuid default null,
  pText			text default null,
  pCategory		text default null,
  pStatus		integer default null
) RETURNS		void
AS $$
BEGIN
  PERFORM EditNotice(pId, pUserId, pObject, pText, pCategory, pStatus);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_notice --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_notice (
  pId			uuid,
  pUserId		uuid default null,
  pObject		uuid default null,
  pText			text default null,
  pCategory		text default null,
  pStatus		integer default null,
  pData         json default null
) RETURNS		SETOF api.notice
AS $$
BEGIN
  pId := SetNotice(pUserId, pObject, pText, pCategory, pStatus, pData);
  RETURN QUERY SELECT * FROM api.notice WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_notice --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает извещение
 * @param {uuid} pId - Идентификатор
 * @return {api.notice} - Счёт
 */
CREATE OR REPLACE FUNCTION api.get_notice (
  pId		uuid
) RETURNS	SETOF api.notice
AS $$
  SELECT * FROM api.notice WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.delete_notice -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.delete_notice (
  pId			uuid
) RETURNS		boolean
AS $$
DECLARE
  r				record;
BEGIN
  FOR r IN SELECT id FROM api.notice WHERE id = pId
  LOOP
  	RETURN DeleteNotice(r.id);
  END LOOP;

  RETURN false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_notice -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает извещение в виде списока.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.notice}
 */
CREATE OR REPLACE FUNCTION api.list_notice (
  pSearch	jsonb default null,
  pFilter	jsonb default null,
  pLimit	integer default null,
  pOffSet	integer default null,
  pOrderBy	jsonb default null
) RETURNS	SETOF api.notice
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'notice', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
