--------------------------------------------------------------------------------
-- Notification ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION Notification (
  pDateFrom     timestamptz,
  pUserId		numeric DEFAULT current_userid()
) RETURNS       SETOF Notification
AS $$
  WITH access AS (
	WITH member_group AS (
		SELECT pUserId AS userid UNION SELECT userid FROM db.member_group WHERE member = pUserId
	)
	SELECT a.object, bit_or(a.mask) AS mask
	  FROM db.notification n INNER JOIN db.aou       a ON n.object = a.object
							 INNER JOIN member_group m ON a.userid = m.userid
     WHERE n.datetime >= pDateFrom
	 GROUP BY a.object
  )
  SELECT n.* FROM Notification n INNER JOIN access a ON n.object = a.object AND a.mask & B'100' = B'100'
   WHERE n.datetime >= pDateFrom
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION CreateNotification -------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateNotification (
  pEntity	numeric,
  pClass	numeric,
  pAction	numeric,
  pMethod   numeric,
  pObject	numeric,
  pUserId	numeric DEFAULT current_userid(),
  pDateTime timestamptz DEFAULT Now()
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  INSERT INTO db.notification (entity, class, action, method, object, userid, datetime)
  VALUES (pEntity, pClass, pAction, pMethod, pObject, pUserId, pDateTime)
  RETURNING id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION EditNotification ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditNotification (
  pId       numeric,
  pEntity	numeric DEFAULT null,
  pClass	numeric DEFAULT null,
  pMethod   numeric DEFAULT null,
  pAction	numeric DEFAULT null,
  pObject	numeric DEFAULT null,
  pUserId	numeric DEFAULT null,
  pDateTime timestamptz DEFAULT null
) RETURNS	void
AS $$
BEGIN
  UPDATE db.notification
     SET entity = coalesce(pEntity, entity),
         class = coalesce(pClass, class),
         action = coalesce(pAction, action),
         method = coalesce(pMethod, method),
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

CREATE OR REPLACE FUNCTION DeleteNotification (
  pId		numeric
) RETURNS 	void
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

CREATE OR REPLACE FUNCTION AddNotification (
  pClass		numeric,
  pAction		numeric,
  pMethod   	numeric,
  pObject		numeric,
  pUserId		numeric DEFAULT current_userid(),
  pDateTime 	timestamptz DEFAULT Now()
) RETURNS		void
AS $$
DECLARE
  nEntity		numeric;
BEGIN
  SELECT entity INTO nEntity FROM db.class_tree WHERE id = pClass;
  PERFORM CreateNotification(nEntity, pClass, pAction, pMethod, pObject, pUserId, pDateTime);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
