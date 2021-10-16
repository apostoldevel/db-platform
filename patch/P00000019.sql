-- KERNEL

CREATE OR REPLACE FUNCTION db.ft_object_before_update()
RETURNS trigger AS $$
DECLARE
  bSystem   boolean;
BEGIN
  IF lower(session_user) = 'kernel' THEN
    SELECT AccessDeniedForUser(session_user);
  END IF;

  IF OLD.suid <> NEW.suid THEN
	IF current_username() <> 'admin' THEN
	  PERFORM AccessDenied();
	END IF;
  END IF;

  IF NOT CheckObjectAccess(NEW.id, B'010') THEN
    PERFORM AccessDenied();
  END IF;

  IF OLD.type <> NEW.type THEN
    SELECT class INTO NEW.class FROM db.type WHERE id = NEW.type;
    SELECT entity INTO NEW.entity FROM db.class_tree WHERE id = NEW.class;

    IF OLD.entity <> NEW.entity THEN
      PERFORM IncorrectEntity();
    END IF;
  END IF;

  IF OLD.class <> NEW.class THEN
    NEW.state := GetState(NEW.class, OLD.state_type);

    IF OLD.state IS DISTINCT FROM NEW.state THEN
      UPDATE db.object_state SET state = NEW.state
       WHERE object = OLD.id
         AND state = OLD.state;
    END IF;
  END IF;

  IF NEW.state IS NOT NULL THEN
    SELECT type INTO NEW.state_type FROM db.state WHERE id = NEW.state;
  ELSE
    NEW.state_type := NULL;
  END IF;

  IF OLD.owner <> NEW.owner THEN
    SELECT system INTO bSystem FROM users WHERE id = OLD.owner AND scope = current_scope();
    IF NOT bSystem THEN
      DELETE FROM db.aou WHERE object = NEW.id AND userid = OLD.owner AND mask = B'111';
    END IF;
	INSERT INTO db.aou SELECT NEW.id, NEW.owner, B'000', B'111'
	  ON CONFLICT (object, userid) DO UPDATE SET deny = B'000', allow = B'111';
  END IF;

  NEW.oper := current_userid();

  NEW.ldate := now();
  NEW.udate := now();

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--

DROP FUNCTION IF EXISTS AddType(uuid, text, text, text);

-- API
DROP FUNCTION IF EXISTS api.group_member(uuid);

-- ADMIN

DROP VIEW api.session CASCADE;
DROP VIEW Session CASCADE;
DROP VIEW users CASCADE;

--

ALTER TABLE db.profile
  ADD scope uuid REFERENCES db.scope(id) ON DELETE RESTRICT;

UPDATE db.profile p SET scope = (SELECT a.scope FROM db.area a WHERE id = p.area);

ALTER TABLE db.profile DROP CONSTRAINT profile_pkey;

ALTER TABLE db.profile ADD CONSTRAINT profile_pkey PRIMARY KEY (userid, scope);

COMMENT ON COLUMN db.profile.scope IS 'Область видимости базы данных';
