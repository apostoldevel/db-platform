--------------------------------------------------------------------------------
-- NOTIFICATION ----------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.notification -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.notification (
    id			uuid PRIMARY KEY DEFAULT gen_kernel_uuid('8'),
    entity		uuid NOT NULL REFERENCES db.entity(id) ON DELETE CASCADE,
    class		uuid NOT NULL REFERENCES db.class_tree(id) ON DELETE CASCADE,
    action		uuid NOT NULL REFERENCES db.action(id) ON DELETE CASCADE,
    method		uuid NOT NULL REFERENCES db.method(id) ON DELETE CASCADE,
    object		uuid NOT NULL REFERENCES db.object(id) ON DELETE CASCADE,
    userid      uuid NOT NULL REFERENCES db.user(id) ON DELETE CASCADE,
    datetime    timestamptz NOT NULL DEFAULT Now()
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

CREATE OR REPLACE FUNCTION db.ft_notification_after_insert()
RETURNS		trigger
AS $$
BEGIN
  PERFORM pg_notify('notify', row_to_json(NEW)::text);

  IF GetClassCode(NEW.class) = 'outbox' AND GetActionCode(NEW.action) = 'submit' THEN
  	PERFORM pg_notify('outbox', NEW.object::text);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_notification_after_insert
  AFTER INSERT ON db.notification
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_notification_after_insert();
