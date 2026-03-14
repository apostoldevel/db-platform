--------------------------------------------------------------------------------
-- CreateComment ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new threaded comment on an object.
 * @param {uuid} pParent - Parent comment identifier (NULL for top-level)
 * @param {uuid} pObject - Target object identifier
 * @param {uuid} pOwner - Author user identifier
 * @param {integer} pPriority - Sort priority (defaults to 0)
 * @param {text} pText - Comment body text
 * @param {jsonb} pData - Arbitrary JSON payload
 * @return {uuid} - New comment identifier
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CreateComment (
  pParent       uuid,
  pObject       uuid,
  pOwner        uuid,
  pPriority     integer,
  pText         text,
  pData         jsonb default null
) RETURNS       uuid
AS $$
DECLARE
  uComment      uuid;
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
 * @brief Update an existing comment (NULL parameters keep current values).
 * @param {uuid} pId - Comment identifier
 * @param {integer} pPriority - Sort priority
 * @param {text} pText - Comment body text
 * @param {jsonb} pData - Arbitrary JSON payload
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EditComment (
  pId           uuid,
  pPriority     integer default null,
  pText         text default null,
  pData         jsonb default null
) RETURNS       void
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
 * @brief Delete a comment by identifier.
 * @param {uuid} pId - Comment identifier
 * @return {boolean} - TRUE if a row was deleted
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DeleteComment (
  pId           uuid
) RETURNS    	boolean
AS $$
BEGIN
  DELETE FROM db.comment WHERE id = pId;
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
