--------------------------------------------------------------------------------
-- NOTIFY ----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.notify -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.notify (
    id			bigserial PRIMARY KEY,
    object		numeric(12) NOT NULL,
    class		numeric(12) NOT NULL,
    method		numeric(12) NOT NULL,
    action		numeric(12) NOT NULL,
    userid      numeric(12) NOT NULL,
    datetime    timestamp NOT NULL DEFAULT Now(),
    CONSTRAINT fk_notify_object FOREIGN KEY (object) REFERENCES db.object(id),
    CONSTRAINT fk_notify_class FOREIGN KEY (class) REFERENCES db.class_tree(id),
    CONSTRAINT fk_notify_method FOREIGN KEY (method) REFERENCES db.method(id),
    CONSTRAINT fk_notify_action FOREIGN KEY (action) REFERENCES db.action(id),
    CONSTRAINT fk_notify_userid FOREIGN KEY (userid) REFERENCES db.user(id)
);

COMMENT ON TABLE db.notify IS 'Уведомления.';

COMMENT ON COLUMN db.notify.id IS 'Идентификатор';
COMMENT ON COLUMN db.notify.object IS 'Объект';
COMMENT ON COLUMN db.notify.class IS 'Класс';
COMMENT ON COLUMN db.notify.method IS 'Метод';
COMMENT ON COLUMN db.notify.action IS 'Действие';
COMMENT ON COLUMN db.notify.userid IS 'Учётная запись пользователя';
COMMENT ON COLUMN db.notify.datetime IS 'Дата и время';

CREATE INDEX ON db.notify (object);
CREATE INDEX ON db.notify (class);
CREATE INDEX ON db.notify (method);
CREATE INDEX ON db.notify (action);
CREATE INDEX ON db.notify (userid);
CREATE INDEX ON db.notify (datetime);

--------------------------------------------------------------------------------
-- VIEW Notify -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Notify (Id, DateTime, UserId, Object,
  Class, ClassCode, Action, ActionCode, Method, MethodCode
)
AS
  SELECT n.id, n.datetime, n.userid, n.object,
         n.class, c.code, n.action, a.code, n.method, m.code
    FROM db.notify n INNER JOIN db.class_tree c ON n.class = c.id
                     INNER JOIN db.action     a ON n.action = a.id
                     INNER JOIN db.method     m ON n.method = m.id;

GRANT SELECT ON Notify TO administrator;

--------------------------------------------------------------------------------
-- FUNCTION AddNotify ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddNotify (
  pObject	numeric,
  pClass	numeric,
  pMethod   numeric,
  pAction	numeric,
  pUserId	numeric DEFAULT current_userid(),
  pDateTime timestamp DEFAULT Now()
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  INSERT INTO db.notify (object, class, method, action, userid, datetime)
  VALUES (pObject, pClass, pMethod, pAction, pUserId, pDateTime)
  RETURNING id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION EditNotify ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditNotify (
  pId       numeric,
  pObject	numeric DEFAULT null,
  pClass	numeric DEFAULT null,
  pMethod   numeric DEFAULT null,
  pAction	numeric DEFAULT null,
  pUserId	numeric DEFAULT null,
  pDateTime timestamp DEFAULT null
) RETURNS	void
AS $$
BEGIN
  UPDATE db.notify
     SET object = coalesce(pObject, object),
         class = coalesce(pClass, class),
         method = coalesce(pMethod, method),
         action = coalesce(pAction, action),
         userid = coalesce(pUserId, userid),
         datetime = coalesce(pDateTime, datetime)
   WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DeleteNotify -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteNotify (
  pId		numeric
) RETURNS 	void
AS $$
BEGIN
  DELETE FROM db.notify WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
