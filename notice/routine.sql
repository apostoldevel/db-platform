--------------------------------------------------------------------------------
-- CreateNotice ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new user notice.
 * @param {uuid} pUserId - Recipient user; defaults to current session user
 * @param {uuid} pObject - Related object identifier (nullable)
 * @param {text} pText - Notice message text
 * @param {text} pCategory - Category tag (defaults to 'notice')
 * @param {integer} pStatus - Delivery status: 0=created, 1=delivered, 2=read, 3=accepted, 4=refused
 * @param {jsonb} pData - Arbitrary JSON payload
 * @return {uuid} - New notice identifier
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CreateNotice (
  pUserId       uuid,
  pObject       uuid,
  pText         text,
  pCategory     text default null,
  pStatus       integer default null,
  pData         jsonb default null
) RETURNS       uuid
AS $$
DECLARE
  uNotice       uuid;
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
 * @brief Update an existing notice (NULL parameters keep current values).
 * @param {uuid} pId - Notice identifier
 * @param {uuid} pUserId - Owner user; defaults to current session user
 * @param {uuid} pObject - Related object identifier
 * @param {text} pText - Notice message text
 * @param {text} pCategory - Category tag
 * @param {integer} pStatus - Delivery status: 0=created, 1=delivered, 2=read, 3=accepted, 4=refused
 * @param {jsonb} pData - Arbitrary JSON payload
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EditNotice (
  pId           uuid,
  pUserId       uuid default null,
  pObject       uuid default null,
  pText         text default null,
  pCategory     text default null,
  pStatus       integer default null,
  pData         jsonb default null
) RETURNS       void
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
/**
 * @brief Upsert a notice: create when pId is NULL, otherwise update.
 * @param {uuid} pId - Notice identifier (NULL to create)
 * @param {uuid} pUserId - Recipient user
 * @param {uuid} pObject - Related object identifier
 * @param {text} pText - Notice message text
 * @param {text} pCategory - Category tag
 * @param {integer} pStatus - Delivery status
 * @param {jsonb} pData - Arbitrary JSON payload
 * @return {uuid} - Notice identifier
 * @see CreateNotice, EditNotice
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION SetNotice (
  pId           uuid,
  pUserId       uuid default null,
  pObject       uuid default null,
  pText         text default null,
  pCategory     text default null,
  pStatus       integer default null,
  pData         jsonb default null
) RETURNS       uuid
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
 * @brief Delete a notice owned by the current user.
 * @param {uuid} pId - Notice identifier
 * @return {boolean} - TRUE if a row was deleted
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DeleteNotice (
  pId    		uuid
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
 * @brief Mark notices as read (status=2) for the current user.
 * @param {uuid} pId - Notice identifier; NULL marks all unread notices
 * @return {boolean} - TRUE if any rows were updated
 * @since 1.0.0
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
