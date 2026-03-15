--------------------------------------------------------------------------------
-- Notification ----------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Retrieve notifications since a given date, filtered by object-level access control.
 * @param {timestamptz} pDateFrom - Start timestamp (inclusive)
 * @param {uuid} pUserId - User whose permissions are checked; defaults to current session user
 * @return {SETOF Notification} - Accessible notification rows
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION Notification (
  pDateFrom     timestamptz,
  pUserId       uuid DEFAULT current_userid()
) RETURNS       SETOF Notification
AS $$
  WITH access AS (
    WITH member_group AS (
        SELECT pUserId AS userid UNION SELECT userid FROM db.member_group WHERE member = pUserId
    )
    SELECT a.object, bit_or(a.allow) & ~bit_or(a.deny) AS mask
      FROM db.notification n INNER JOIN db.aou       a ON n.object = a.object
                             INNER JOIN member_group m ON a.userid = m.userid
     WHERE n.datetime >= pDateFrom
     GROUP BY a.object
  )
  SELECT n.* FROM Notification n INNER JOIN access a ON n.object = a.object AND a.mask & B'100' = B'100'
   WHERE n.datetime >= pDateFrom
$$ LANGUAGE SQL STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION CreateNotification -------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Insert a new notification record into the audit trail.
 * @param {uuid} pEntity - Entity type identifier
 * @param {uuid} pClass - Class identifier
 * @param {uuid} pAction - Workflow action identifier
 * @param {uuid} pMethod - Workflow method identifier
 * @param {uuid} pStateOld - Previous state identifier (nullable)
 * @param {uuid} pStateNew - New state identifier (nullable)
 * @param {uuid} pObject - Affected object identifier
 * @param {uuid} pUserId - User who triggered the action; defaults to current session user
 * @param {timestamptz} pDateTime - Event timestamp; defaults to now
 * @return {uuid} - New notification identifier
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CreateNotification (
  pEntity       uuid,
  pClass        uuid,
  pAction       uuid,
  pMethod       uuid,
  pStateOld     uuid,
  pStateNew     uuid,
  pObject       uuid,
  pUserId       uuid DEFAULT current_userid(),
  pDateTime     timestamptz DEFAULT Now()
) RETURNS       uuid
AS $$
DECLARE
  uId           uuid;
BEGIN
  INSERT INTO db.notification (entity, class, action, method, state_old, state_new, object, userid, datetime)
  VALUES (pEntity, pClass, pAction, pMethod, pStateOld, pStateNew, pObject, pUserId, pDateTime)
  RETURNING id INTO uId;

  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION EditNotification ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update an existing notification record (NULL parameters keep current values).
 * @param {uuid} pId - Notification identifier
 * @param {uuid} pEntity - Entity type identifier
 * @param {uuid} pClass - Class identifier
 * @param {uuid} pAction - Workflow action identifier
 * @param {uuid} pMethod - Workflow method identifier
 * @param {uuid} pStateOld - Previous state identifier
 * @param {uuid} pStateNew - New state identifier
 * @param {uuid} pObject - Affected object identifier
 * @param {uuid} pUserId - User identifier
 * @param {timestamptz} pDateTime - Event timestamp
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EditNotification (
  pId           uuid,
  pEntity       uuid DEFAULT null,
  pClass        uuid DEFAULT null,
  pAction       uuid DEFAULT null,
  pMethod       uuid DEFAULT null,
  pStateOld     uuid DEFAULT null,
  pStateNew     uuid DEFAULT null,
  pObject       uuid DEFAULT null,
  pUserId       uuid DEFAULT null,
  pDateTime     timestamptz DEFAULT null
) RETURNS       void
AS $$
BEGIN
  UPDATE db.notification
     SET entity = coalesce(pEntity, entity),
         class = coalesce(pClass, class),
         action = coalesce(pAction, action),
         method = coalesce(pMethod, method),
         state_old = coalesce(pStateOld, state_old),
         state_new = coalesce(pStateNew, state_new),
         object = coalesce(pObject, object),
         userid = coalesce(pUserId, userid),
         datetime = coalesce(pDateTime, datetime)
   WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DeleteNotification -------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Delete a notification record by identifier.
 * @param {uuid} pId - Notification identifier
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DeleteNotification (
  pId            uuid
) RETURNS        void
AS $$
BEGIN
  DELETE FROM db.notification WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION AddNotification ----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Add a notification, resolving the entity from the class tree automatically.
 * @param {uuid} pClass - Class identifier (entity is derived from it)
 * @param {uuid} pAction - Workflow action identifier
 * @param {uuid} pMethod - Workflow method identifier
 * @param {uuid} pStateOld - Previous state identifier (nullable)
 * @param {uuid} pStateNew - New state identifier (nullable)
 * @param {uuid} pObject - Affected object identifier
 * @param {uuid} pUserId - User who triggered the action; defaults to current session user
 * @param {timestamptz} pDateTime - Event timestamp; defaults to now
 * @return {void}
 * @see CreateNotification
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION AddNotification (
  pClass        uuid,
  pAction       uuid,
  pMethod       uuid,
  pStateOld     uuid,
  pStateNew     uuid,
  pObject       uuid,
  pUserId       uuid DEFAULT current_userid(),
  pDateTime     timestamptz DEFAULT Now()
) RETURNS       void
AS $$
DECLARE
  uEntity        uuid;
BEGIN
  SELECT entity INTO uEntity FROM db.class_tree WHERE id = pClass;
  PERFORM CreateNotification(uEntity, pClass, pAction, pMethod, pStateOld, pStateNew, pObject, pUserId, pDateTime);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
