--------------------------------------------------------------------------------
-- COMMENT ---------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.comment -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.comment
AS
  WITH RECURSIVE tree AS (
    SELECT *, ARRAY[row_number() OVER (ORDER BY priority DESC)] AS sortlist FROM Comment WHERE parent IS NULL
     UNION ALL
    SELECT c.*, array_append(t.sortlist, row_number() OVER (ORDER BY c.priority DESC))
      FROM Comment c INNER JOIN tree t ON c.parent = t.id
  ) SELECT t.*, array_to_string(sortlist, '.', '0') AS Index FROM tree t;

GRANT SELECT ON api.comment TO administrator;

--------------------------------------------------------------------------------
-- FUNCTION api.comment --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.comment (
  pObject   uuid
) RETURNS   SETOF api.comment
AS $$
  SELECT * FROM api.comment WHERE object = pObject ORDER BY priority DESC, created DESC
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.add_comment -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Добавляет комментарий.
 * @param {uuid} pParent - Идентификатор комментария родителя
 * @param {uuid} pObject - Идентификатор объекта
 * @param {text} pPriority - Приоритет
 * @param {text} pText - Текст извещения
 * @param {json} pData - Данные в произвольном формате
 * @return {uuid} - Идентификатор комментария
 */
CREATE OR REPLACE FUNCTION api.add_comment (
  pParent       uuid,
  pObject       uuid,
  pPriority     integer,
  pText         text,
  pData         jsonb default null
) RETURNS       uuid
AS $$
BEGIN
  RETURN CreateComment(pParent, pObject, current_userid(), coalesce(pPriority, 0), pText, pData);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_comment ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Обновляет комментарий.
 * @param {uuid} pId - Идентификатор комментария
 * @param {text} pPriority - Приоритет
 * @param {text} pText - Текст извещения
 * @param {json} pData - Данные в произвольном формате
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.update_comment (
  pId           uuid,
  pPriority     integer default null,
  pText         text default null,
  pData         jsonb default null
) RETURNS       void
AS $$
DECLARE
  uOwner        uuid;
BEGIN
  SELECT owner INTO uOwner FROM db.comment WHERE id = pId;

  IF NOT FOUND THEN
    PERFORM NotFound();
  END IF;

  IF uOwner <> current_userid() THEN
    IF NOT IsUserRole(GetGroup('administrator')) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  PERFORM EditComment(pId, pPriority, pText, pData);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_comment -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_comment (
  pId        	uuid,
  pParent		uuid default null,
  pObject		uuid default null,
  pPriority		integer default null,
  pText			text default null,
  pData         jsonb default null
) RETURNS		SETOF api.comment
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_comment(pParent, pObject, coalesce(pPriority, 0), pText, pData);
  ELSE
    PERFORM api.update_comment(pId, coalesce(pPriority, 0), pText, pData);
  END IF;

  RETURN QUERY SELECT * FROM api.comment WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_comment -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает комментарий
 * @param {uuid} pId - Идентификатор
 * @return {api.comment}
 */
CREATE OR REPLACE FUNCTION api.get_comment (
  pId		uuid
) RETURNS	SETOF api.comment
AS $$
  SELECT * FROM api.comment WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.delete_comment ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.delete_comment (
  pId			uuid
) RETURNS		boolean
AS $$
DECLARE
  uOwner        uuid;
BEGIN
  SELECT owner INTO uOwner FROM db.comment WHERE id = pId;

  IF NOT FOUND THEN
	PERFORM NotFound();
  END IF;

  IF uOwner <> current_userid() THEN
    IF NOT IsUserRole(GetGroup('administrator')) THEN
	  PERFORM AccessDenied();
	END IF;
  END IF;

  RETURN DeleteComment(pId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_comment ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает комментарий в виде списка.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.comment}
 */
CREATE OR REPLACE FUNCTION api.list_comment (
  pSearch	jsonb default null,
  pFilter	jsonb default null,
  pLimit	integer default null,
  pOffSet	integer default null,
  pOrderBy	jsonb default null
) RETURNS	SETOF api.comment
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'comment', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
