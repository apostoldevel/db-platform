--------------------------------------------------------------------------------
-- CreateNotice ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт новое извещение
 * @param {uuid} pUserId - Идентификатор пользователя
 * @param {uuid} pObject - Идентификатор объекта
 * @param {text} pText - Текст извещения
 * @param {text} pCategory - Категория извещения
 * @param {integer} pStatus - Статус: 0 - создано; 1 - доставлено; 2 - прочитано; 3 - принято; 4 - отказано
 * @param {jsonb} pData - Данные в произвольном формате
 * @return {uuid} - Идентификатор извещения
 */
CREATE OR REPLACE FUNCTION CreateNotice (
  pUserId		uuid,
  pObject		uuid,
  pText			text,
  pCategory		text default null,
  pStatus		integer default null,
  pData         jsonb default null
) RETURNS		uuid
AS $$
DECLARE
  uNotice		uuid;
BEGIN
  INSERT INTO db.notice (userid, object, text, category, status, data)
  VALUES (coalesce(pUserId, current_userid()), pObject, pText, coalesce(pCategory, 'notice'), coalesce(pStatus, 0), pData)
  RETURNING id INTO uNotice;

  RETURN uNotice;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditNotice ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Меняет извещение.
 * @param {uuid} pId - Идентификатор извещения
 * @param {uuid} pUserId - Идентификатор пользователя
 * @param {uuid} pObject - Идентификатор объекта
 * @param {text} pText - Текст извещения
 * @param {text} pCategory - Категория извещения
 * @param {integer} pStatus - Статус: 0 - создано; 1 - доставлено; 2 - прочитано; 3 - принято; 4 - отказано
 * @param {jsonb} pData - Данные в произвольном формате
 * @return {void}
 */
CREATE OR REPLACE FUNCTION EditNotice (
  pId			uuid,
  pUserId		uuid default null,
  pObject		uuid default null,
  pText			text default null,
  pCategory		text default null,
  pStatus		integer default null,
  pData         jsonb default null
) RETURNS		void
AS $$
BEGIN
  pUserId := coalesce(pUserId, current_userid());

  UPDATE db.notice
     SET object = coalesce(pObject, object),
         text = coalesce(pText, text),
         category = coalesce(pCategory, category),
         status = coalesce(pStatus, status),
         updated = Now(),
         data = CheckNull(coalesce(pData, data, '{}'::jsonb))
   WHERE id = pId
     AND userid = pUserId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SetNotice -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetNotice (
  pId			uuid,
  pUserId		uuid default null,
  pObject		uuid default null,
  pText			text default null,
  pCategory		text default null,
  pStatus		integer default null,
  pData         jsonb default null
) RETURNS		uuid
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := CreateNotice(pUserId, pObject, pText, pCategory, pStatus, pData);
  ELSE
    PERFORM EditNotice(pId, pUserId, pObject, pText, pCategory, pStatus, pData);
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
 * @param {uuid} pId - Идентификатор извещения
 * @return {boolean}
 */
CREATE OR REPLACE FUNCTION DeleteNotice (
  pId			uuid
) RETURNS		boolean
AS $$
BEGIN
  DELETE FROM db.notice WHERE id = pId AND userid = current_userid();
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- MarkNotice ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Помечает извещения как прочитанные.
 * @param {uuid} pId - Идентификатор извещения, если null, то для всех не прочитанных.
 * @return {boolean}
 */
CREATE OR REPLACE FUNCTION MarkNotice (
  pId			uuid
) RETURNS		boolean
AS $$
BEGIN
  IF pId IS NOT NULL THEN
    UPDATE db.notice SET status = 2 WHERE id = pId AND userid = current_userid() AND status < 2;
  ELSE
    UPDATE db.notice SET status = 2 WHERE userid = current_userid() AND status < 2;
  END IF;

  RETURN FOUND;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
