DROP INDEX IF EXISTS db.message_agent_code_idx;
CREATE INDEX ON db.message (code);
--
DROP INDEX IF EXISTS db.area_code_idx;
DROP INDEX IF EXISTS db.area_scope_code_idx;
CREATE UNIQUE INDEX ON db.area (scope, code);
--
DROP FUNCTION IF EXISTS GetArea(text);
DROP FUNCTION IF EXISTS GetMessage(uuid, text);
DROP FUNCTION IF EXISTS SendFCM(uuid, text, text, text, text, text, uuid);
DROP FUNCTION IF EXISTS SendM2M(uuid, text, text, text, text, text, uuid);
DROP FUNCTION IF EXISTS SendMail(uuid, text, text, text, text, text, uuid);
DROP FUNCTION IF EXISTS SendMessage(uuid, uuid, text, text, text, text, text, uuid);
DROP FUNCTION IF EXISTS SendPush(uuid, text, text, uuid, jsonb, jsonb, jsonb);
DROP FUNCTION IF EXISTS SendPushData(uuid, text, json, uuid, text, text);
--
DROP VIEW Account CASCADE;
--
DROP FUNCTION IF EXISTS api.send_message(text, text, text, text, text, text);
--

CREATE OR REPLACE FUNCTION db.ft_message_before_insert()
RETURNS trigger AS $$
BEGIN
  IF NEW.id IS NULL THEN
    SELECT NEW.document INTO NEW.id;
  END IF;

  IF NULLIF(NEW.code, '') IS null THEN
    NEW.code := encode(gen_random_bytes(32), 'hex');
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
--

CREATE OR REPLACE FUNCTION db.ft_notification_after_insert()
RETURNS     trigger
AS $$
DECLARE
  vClass    text;
  vAction   text;
BEGIN
  PERFORM pg_notify('notify', row_to_json(NEW)::text);

  IF GetEntityCode(NEW.entity) = 'message' THEN
    vClass := GetClassCode(NEW.class);
    vAction := GetActionCode(NEW.action);
    IF vClass = 'inbox' THEN
      IF vAction = 'create' THEN
        PERFORM pg_notify('inbox', NEW.object::text);
      END IF;
    ELSIF vClass = 'outbox' THEN
      IF vAction = 'submit' THEN
        PERFORM pg_notify('outbox', NEW.object::text);
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

CREATE OR REPLACE FUNCTION db.ft_session_before()
RETURNS TRIGGER
AS $$
DECLARE
  vAgent    text;
BEGIN
  IF (TG_OP = 'DELETE') THEN
    DELETE FROM db.listener WHERE session = OLD.code;
    RETURN OLD;
  ELSIF (TG_OP = 'UPDATE') THEN
    IF OLD.code <> NEW.code THEN
      RAISE DEBUG 'Hacking alert: code (% <> %).', OLD.code, NEW.code;
      RETURN NULL;
    END IF;

    IF OLD.secret <> NEW.secret THEN
      RAISE DEBUG 'Hacking alert: secret (% <> %).', OLD.secret, NEW.secret;
      RETURN NULL;
    END IF;

    IF OLD.pwkey <> NEW.pwkey THEN
      RAISE DEBUG 'Hacking alert: pwkey (% <> %).', OLD.pwkey, NEW.pwkey;
      RETURN NULL;
    END IF;

    IF OLD.suid <> NEW.suid THEN
      RAISE DEBUG 'Hacking alert: suid (% <> %).', OLD.suid, NEW.suid;
      RETURN NULL;
    END IF;

    IF OLD.created <> NEW.created THEN
      RAISE DEBUG 'Hacking alert: created (% <> %).', OLD.created, NEW.created;
      RETURN NULL;
    END IF;

    IF NEW.salt IS NULL THEN
      NEW.salt := OLD.salt;
    END IF;

    IF (NEW.updated - OLD.updated) > INTERVAL '1 hour' THEN
      NEW.salt := gen_salt('md5');
    END IF;

    IF NEW.salt IS DISTINCT FROM OLD.salt THEN
      NEW.token := NewTokenCode(NEW.oauth2, NEW.code, NEW.salt, NEW.agent, NEW.host, NEW.updated);
    END IF;

    IF NEW.area IS DISTINCT FROM OLD.area THEN
      IF NOT IsMemberArea(NEW.area, NEW.userid) THEN
        NEW.area := OLD.area;
      END IF;
    END IF;

    IF OLD.interface IS DISTINCT FROM NEW.interface THEN
      IF NOT IsMemberInterface(NEW.interface, NEW.userid) THEN
        NEW.interface := OLD.interface;
      END IF;
    END IF;

    RETURN NEW;
  ELSIF (TG_OP = 'INSERT') THEN
    IF NEW.suid IS NULL THEN
      NEW.suid := NEW.userid;
    END IF;

    IF NEW.secret IS NULL THEN
      NEW.secret := GenSecretKey();
    END IF;

    IF NEW.agent IS NULL THEN
      SELECT application_name INTO vAgent FROM pg_stat_activity WHERE pid = pg_backend_pid();
      NEW.agent := coalesce(vAgent, current_database());
    END IF;

    NEW.salt := gen_salt('md5');

    IF NEW.pwkey IS NULL THEN
      NEW.pwkey := crypt(StrPwKey(NEW.suid, NEW.secret, NEW.created), NEW.salt);
    END IF;

    NEW.code := SessionKey(NEW.pwkey, GetSecretKey());

    IF NEW.token IS NULL THEN
      NEW.token := NewTokenCode(NEW.oauth2, NEW.code, NEW.salt, NEW.agent, NEW.host, NEW.updated);
    END IF;

    IF NEW.locale IS NULL THEN
      SELECT id INTO NEW.locale FROM db.locale WHERE id = GetDefaultLocale(NEW.userid);
    END IF;

    IF NEW.area IS NULL THEN
      NEW.area := GetDefaultArea(NEW.userid);
    END IF;

    SELECT id INTO NEW.area FROM db.area WHERE id = NEW.area AND scope IN (SELECT GetOAuth2Scopes(NEW.oauth2));
    IF NOT FOUND THEN
      SELECT id INTO NEW.area FROM db.area WHERE scope IN (SELECT GetOAuth2Scopes(NEW.oauth2)) AND type = '00000000-0000-4002-a001-000000000001'; -- main
    END IF;

    IF NOT IsMemberArea(NEW.area, NEW.userid) THEN
      SELECT '00000000-0000-4003-a000-000000000002' INTO NEW.area; -- guest
    END IF;

    IF NEW.interface IS NULL THEN
      NEW.interface := GetDefaultInterface(NEW.userid);
    END IF;

    IF NOT IsMemberInterface(NEW.interface, NEW.userid) THEN
      SELECT '00000000-0000-4004-a000-000000000003' INTO NEW.interface; -- guest
    END IF;

    RETURN NEW;
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = db, kernel, pg_temp;

CREATE OR REPLACE FUNCTION db.ft_profile_before()
RETURNS trigger AS $$
BEGIN
  IF NEW.locale IS NULL THEN
    SELECT id INTO NEW.locale FROM db.locale WHERE code = 'ru';
  END IF;

  IF NOT IsMemberArea(NEW.area, NEW.userid) THEN
    SELECT '00000000-0000-4003-a000-000000000002' INTO NEW.area; -- guest
  END IF;

  IF NOT IsMemberInterface(NEW.interface, NEW.userid) THEN
    SELECT '00000000-0000-4004-a000-000000000003' INTO NEW.interface; -- guest
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

CREATE OR REPLACE FUNCTION db.ft_class_tree_after_insert()
RETURNS trigger AS $$
BEGIN
  IF NEW.parent IS NULL THEN
    INSERT INTO db.acu SELECT NEW.id, '00000000-0000-4000-a000-000000000001', B'00000', B'11111'; -- administrator group
    INSERT INTO db.acu SELECT NEW.id, '00000000-0000-4000-a002-000000000001', B'00000', B'01110'; -- apibot
  ELSE
    INSERT INTO db.acu SELECT NEW.id, userid, deny, allow FROM db.acu WHERE class = NEW.parent;

    IF NEW.code = 'document' THEN
      INSERT INTO db.acu SELECT NEW.id, '00000000-0000-4000-a000-000000000002', B'00000', B'11000'; -- user group
    ELSIF NEW.code = 'reference' THEN
      INSERT INTO db.acu SELECT NEW.id, '00000000-0000-4000-a000-000000000002', B'00000', B'10100'; -- user group
    ELSIF NEW.code = 'message' THEN
      INSERT INTO db.acu SELECT NEW.id, '00000000-0000-4000-a002-000000000002', B'00000', B'01110'; -- mailbot
    ELSIF NEW.code = 'agent' THEN
      INSERT INTO db.acu SELECT NEW.id, '00000000-0000-4000-a002-000000000002', B'00000', B'01100'; -- mailbot
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

CREATE OR REPLACE FUNCTION db.ft_agent_after_insert()
RETURNS trigger AS $$
BEGIN
  UPDATE db.aou SET deny = B'000', allow = B'100' WHERE object = NEW.id AND userid = '00000000-0000-4000-a002-000000000002'; -- mailbot
  IF not FOUND THEN
    INSERT INTO db.aou SELECT NEW.id, '00000000-0000-4000-a002-000000000002', B'000', B'100'; -- mailbot
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

CREATE OR REPLACE FUNCTION db.ft_area_before_insert()
RETURNS    trigger AS $$
BEGIN
  IF NEW.id IS NULL THEN
    NEW.id := gen_kernel_uuid('8');
  END IF;

  IF NEW.scope IS NULL THEN
    NEW.scope := current_scope();
  END IF;

  IF NEW.id = NEW.parent THEN
    NEW.parent := GetAreaRoot(NEW.scope);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

CREATE OR REPLACE FUNCTION db.ft_document_insert()
RETURNS trigger AS $$
BEGIN
  IF NEW.id IS NULL THEN
    SELECT NEW.object INTO NEW.id;
  END IF;

  IF current_area_type() = '00000000-0000-4002-a000-000000000000' THEN
    PERFORM RootAreaError();
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
