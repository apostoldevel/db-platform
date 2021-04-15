DROP FUNCTION IF EXISTS SetObjectParent(uuid, uuid);
DROP FUNCTION IF EXISTS GetObjectParent(uuid);
DROP FUNCTION IF EXISTS GetObjectEntity(uuid);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_message_after_insert()
RETURNS trigger AS $$
DECLARE
  vClass    text;
  vType     text;
  vAgent    text;
BEGIN
  SELECT c.code INTO vClass
    FROM db.object o INNER JOIN db.class_tree c ON c.id = o.class
   WHERE o.id = NEW.id;

  SELECT t.code, a.code INTO vType, vAgent
    FROM db.reference a INNER JOIN db.type t ON t.id = a.type
   WHERE a.id = NEW.agent;

  PERFORM pg_notify('message', json_build_object('id', NEW.id, 'class', vClass, 'type', vType, 'agent', vAgent, 'code', NEW.code, 'profile', NEW.profile, 'address', NEW.address, 'subject', NEW.subject)::text);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_message_after_insert
  AFTER INSERT ON db.message
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_message_after_insert();

--------------------------------------------------------------------------------

SELECT SignIn(CreateSystemOAuth2(), 'admin', 'admin');

SELECT GetErrorMessage();

SELECT CreatePublisher('message', 'Сообщения', 'Уведомления о сообщениях.');

SELECT SignOut();
