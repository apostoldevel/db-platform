--------------------------------------------------------------------------------
-- CreateComment ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт новый комментарий
 * @param {uuid} pParent - Идентификатор комментария родителя
 * @param {uuid} pObject - Идентификатор объекта
 * @param {uuid} pOwner - Идентификатор владельца (пользователя)
 * @param {text} pPriority - Приоритет
 * @param {text} pText - Текст извещения
 * @param {json} pData - Данные в произвольном формате
 * @return {uuid} - Идентификатор комментария
 */
CREATE OR REPLACE FUNCTION CreateComment (
  pParent		uuid,
  pObject		uuid,
  pOwner		uuid,
  pPriority		integer,
  pText			text,
  pData         jsonb default null
) RETURNS		uuid
AS $$
DECLARE
  uComment		uuid;
BEGIN
  INSERT INTO db.comment (parent, object, owner, priority, text, data)
  VALUES (pParent, pObject, pOwner, coalesce(pPriority, 0), pText, pData)
  RETURNING id INTO uComment;

  RETURN uComment;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditComment -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Меняет комментарий.
 * @param {uuid} pId - Идентификатор комментария
 * @param {text} pPriority - Приоритет
 * @param {text} pText - Текст извещения
 * @param {json} pData - Данные в произвольном формате
 * @return {void}
 */
CREATE OR REPLACE FUNCTION EditComment (
  pId			uuid,
  pPriority		integer default null,
  pText			text default null,
  pData         jsonb default null
) RETURNS		void
AS $$
BEGIN
  UPDATE db.comment
     SET priority = coalesce(pPriority, priority),
         text = coalesce(pText, text),
         data = CheckNull(coalesce(pData, data, '{}'::jsonb))
   WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteComment ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет комментарий.
 * @param {uuid} pId - Идентификатор комментария
 * @return {boolean}
 */
CREATE OR REPLACE FUNCTION DeleteComment (
  pId			uuid
) RETURNS		boolean
AS $$
BEGIN
  DELETE FROM db.comment WHERE id = pId;
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
