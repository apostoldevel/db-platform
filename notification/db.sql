--------------------------------------------------------------------------------
-- NOTIFICATION ----------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.notification -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.notification (
    id			bigserial PRIMARY KEY,
    entity		numeric(12) NOT NULL,
    class		numeric(12) NOT NULL,
    action		numeric(12) NOT NULL,
    method		numeric(12) NOT NULL,
    object		numeric(12) NOT NULL,
    userid      numeric(12) NOT NULL,
    datetime    timestamptz NOT NULL DEFAULT Now(),
    CONSTRAINT fk_notification_entity FOREIGN KEY (entity) REFERENCES db.entity(id),
    CONSTRAINT fk_notification_class FOREIGN KEY (class) REFERENCES db.class_tree(id),
    CONSTRAINT fk_notification_action FOREIGN KEY (action) REFERENCES db.action(id),
    CONSTRAINT fk_notification_method FOREIGN KEY (method) REFERENCES db.method(id),
    CONSTRAINT fk_notification_userid FOREIGN KEY (userid) REFERENCES db.user(id)
);

COMMENT ON TABLE db.notification IS 'Уведомления.';

COMMENT ON COLUMN db.notification.id IS 'Идентификатор';
COMMENT ON COLUMN db.notification.entity IS 'Сущность';
COMMENT ON COLUMN db.notification.class IS 'Класс';
COMMENT ON COLUMN db.notification.action IS 'Действие';
COMMENT ON COLUMN db.notification.method IS 'Метод';
COMMENT ON COLUMN db.notification.object IS 'Объект';
COMMENT ON COLUMN db.notification.userid IS 'Учётная запись пользователя';
COMMENT ON COLUMN db.notification.datetime IS 'Дата и время';

CREATE INDEX ON db.notification (entity);
CREATE INDEX ON db.notification (class);
CREATE INDEX ON db.notification (action);
CREATE INDEX ON db.notification (method);
CREATE INDEX ON db.notification (object);
CREATE INDEX ON db.notification (userid);
CREATE INDEX ON db.notification (datetime);

--------------------------------------------------------------------------------
-- VIEW Notification -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Notification (Id, DateTime, UserId, Object,
  Entity, EntityCode, Class, ClassCode, Action, ActionCode, Method, MethodCode
)
AS
  SELECT n.id, n.datetime, n.userid, n.object,
         n.entity, e.code, n.class, c.code, n.action, a.code, n.method, m.code
    FROM db.notification n INNER JOIN db.entity     e ON n.entity = e.id
                           INNER JOIN db.class_tree c ON n.class = c.id
                           INNER JOIN db.action     a ON n.action = a.id
                           INNER JOIN db.method     m ON n.method = m.id;

GRANT SELECT ON Notification TO administrator;

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
