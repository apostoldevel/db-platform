--------------------------------------------------------------------------------
-- CreateNotice ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт новое извещение
 * @param {numeric} pUserId - Идентификатор пользователя
 * @param {numeric} pObject - Идентификатор объекта
 * @param {text} pText - Текст извещения
 * @param {text} pCategory - Категория извещения
 * @param {integer} pStatus - Статус: 0 - создано; 1 - доставлено; 2 - прочитано; 3 - принято; 4 - отказано
 * @return {numeric} - Идентификатор извещения
 */
CREATE OR REPLACE FUNCTION CreateNotice (
  pUserId		numeric,
  pObject		numeric,
  pText			text,
  pCategory		text default null,
  pStatus		integer default null
) RETURNS		numeric
AS $$
DECLARE
  nNotice		numeric;
BEGIN
  INSERT INTO db.notice (userid, object, text, category, status)
  VALUES (pUserId, pObject, pText, coalesce(pCategory, 'notice'), coalesce(pStatus, 0))
  RETURNING id INTO nNotice;

  RETURN nNotice;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditNotice ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Меняет извещение.
 * @param {numeric} pId - Идентификатор извещения
 * @param {numeric} pUserId - Идентификатор пользователя
 * @param {numeric} pObject - Идентификатор объекта
 * @param {text} pText - Текст извещения
 * @param {text} pCategory - Категория извещения
 * @param {integer} pStatus - Статус: 0 - создано; 1 - доставлено; 2 - прочитано; 3 - принято; 4 - отказано
 * @return {void}
 */
CREATE OR REPLACE FUNCTION EditNotice (
  pId			numeric,
  pUserId		numeric default null,
  pObject		numeric default null,
  pText			text default null,
  pCategory		text default null,
  pStatus		integer default null
) RETURNS		void
AS $$
BEGIN
  UPDATE db.notice
     SET userid = coalesce(pUserId, userid),
         object = coalesce(pObject, object),
         text = coalesce(pText, text),
         category = coalesce(pCategory, category),
         status = coalesce(pStatus, status),
         updated = Now()
   WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SetNotice -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetNotice (
  pId			numeric,
  pUserId		numeric default null,
  pObject		numeric default null,
  pText			text default null,
  pCategory		text default null,
  pStatus		integer default null
) RETURNS		numeric
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := CreateNotice(pUserId, pObject, pText, pCategory, pStatus);
  ELSE
    PERFORM EditNotice(pId, pUserId, pObject, pText, pCategory, pStatus);
  END IF;

  RETURN pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteNotice ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет извещение.
 * @param {numeric} pId - Идентификатор извещения
 * @return {boolean}
 */
CREATE OR REPLACE FUNCTION DeleteNotice (
  pId			numeric
) RETURNS		boolean
AS $$
BEGIN
  DELETE FROM db.notice WHERE id = pId;
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
