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

CREATE OR REPLACE FUNCTION db.ft_notification_after_insert()
RETURNS		trigger
AS $$
BEGIN
  PERFORM pg_notify('notify', row_to_json(NEW)::text);

  IF GetClassCode(NEW.class) = 'outbox' AND GetActionCode(NEW.action) = 'submit' THEN
  	PERFORM pg_notify('outbox', IntToStr(NEW.object));
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
