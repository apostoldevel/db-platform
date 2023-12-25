ALTER TABLE db.session
  ADD scope uuid REFERENCES db.scope(id);

UPDATE db.session d SET scope = a.scope FROM db.area a WHERE a.id = d.area;

ALTER TABLE db.session
    ALTER COLUMN scope SET NOT NULL;

COMMENT ON COLUMN db.session.scope IS 'Область видимости базы данных';

CREATE INDEX ON db.session (scope);
CREATE INDEX ON db.session (agent);

--

ALTER TABLE db.job
  ADD scope uuid REFERENCES db.scope(id);

UPDATE db.job j SET scope = d.scope FROM db.document d WHERE j.document = d.id;

ALTER TABLE db.job
    ALTER COLUMN scope SET NOT NULL;

COMMENT ON COLUMN db.job.scope IS 'Область видимости базы данных';

DROP INDEX db.job_code_idx;

CREATE UNIQUE INDEX ON db.job (scope, code);
CREATE INDEX ON db.job (scope);

--

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

    IF OLD.scope IS DISTINCT FROM NEW.scope THEN
      PERFORM FROM db.area WHERE id = NEW.area AND scope = NEW.scope;
      IF NOT FOUND THEN
        NEW.scope := OLD.scope;
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
      NEW.locale := GetDefaultLocale(NEW.userid);
    END IF;

    IF NEW.area IS NULL THEN
      NEW.area := GetDefaultArea(NEW.userid);
    END IF;

    IF NOT IsMemberArea(NEW.area, NEW.userid) THEN
      PERFORM UserNotMemberArea(GetUserName(NEW.userid), GetAreaName(NEW.area));
    END IF;

    IF NEW.interface IS NULL THEN
      NEW.interface := GetDefaultInterface(NEW.userid);
    END IF;

    IF NOT IsMemberInterface(NEW.interface, NEW.userid) THEN
      PERFORM UserNotMemberInterface(GetUserName(NEW.userid), GetInterfaceName(NEW.interface));
    END IF;

    IF NEW.scope IS NULL THEN
      SELECT scope INTO NEW.scope FROM db.area WHERE id = NEW.area;
    ELSE
      PERFORM FROM db.area WHERE id = NEW.area AND scope = NEW.scope;
      IF NOT FOUND THEN
        RAISE EXCEPTION 'ERR-40000: Area "% (%)" not present in scope "% (%)".', NEW.area, GetAreaName(NEW.area), NEW.scope, GetScopeName(NEW.scope);
      END IF;
    END IF;

    RETURN NEW;
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = db, kernel, pg_temp;

--

UPDATE db.document d SET scope = a.scope FROM db.area a WHERE a.id = d.area;

DROP TRIGGER t_object_before_update ON db.object;

UPDATE db.object o SET scope = d.scope FROM db.document d WHERE o.id = d.object;
UPDATE db.object o SET scope = r.scope FROM db.reference r WHERE o.id = r.object;

--

CREATE OR REPLACE FUNCTION db.ft_object_before_insert()
RETURNS trigger AS $$
DECLARE
  bAbstract    boolean;
BEGIN
  IF lower(session_user) = 'kernel' THEN
    PERFORM AccessDeniedForUser(session_user);
  END IF;

  IF NEW.id IS NULL THEN
    SELECT gen_kernel_uuid('8') INTO NEW.id;
  END IF;

  SELECT class INTO NEW.class FROM db.type WHERE id = NEW.type;
  SELECT entity, abstract INTO NEW.entity, bAbstract FROM db.class_tree WHERE id = NEW.class;

  IF bAbstract THEN
    PERFORM AbstractError();
  END IF;

  SELECT type INTO NEW.state_type FROM db.state WHERE id = NEW.state;

  IF NEW.scope IS NULL THEN
    SELECT scope INTO NEW.scope FROM db.area WHERE id = GetSessionArea(current_session());
  ELSE
    PERFORM FROM db.area WHERE id = GetSessionArea(current_session()) AND scope = NEW.scope;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'ERR-40000: Area "%" not present in scope "%".', GetSessionArea(current_session()), GetScopeName(NEW.scope);
    END IF;
  END IF;

  NEW.suid := session_userid();
  NEW.owner := current_userid();
  NEW.oper := current_userid();

  NEW.pdate := now();
  NEW.ldate := now();
  NEW.udate := now();

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

CREATE TRIGGER t_object_before_update
  BEFORE UPDATE ON db.object
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_object_before_update();

--

CREATE OR REPLACE FUNCTION db.ft_object_before_update()
RETURNS trigger AS $$
DECLARE
  bSystem   boolean;
BEGIN
  IF lower(session_user) = 'kernel' THEN
    SELECT AccessDeniedForUser(session_user);
  END IF;

  IF OLD.suid IS DISTINCT FROM NEW.suid THEN
    IF current_username() IS DISTINCT FROM 'admin' THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  IF NOT CheckObjectAccess(NEW.id, B'010') THEN
    PERFORM AccessDenied();
  END IF;

  IF OLD.type IS DISTINCT FROM NEW.type THEN
    SELECT class INTO NEW.class FROM db.type WHERE id = NEW.type;
    SELECT entity INTO NEW.entity FROM db.class_tree WHERE id = NEW.class;

    IF OLD.entity IS DISTINCT FROM NEW.entity THEN
      PERFORM IncorrectEntity();
    END IF;
  END IF;

  IF OLD.class IS DISTINCT FROM NEW.class THEN
    NEW.state := GetState(NEW.class, OLD.state_type);

    IF OLD.state IS DISTINCT FROM NEW.state THEN
      UPDATE db.object_state SET state = NEW.state
       WHERE object = OLD.id
         AND state = OLD.state;
    END IF;
  END IF;

  IF OLD.state IS DISTINCT FROM NEW.state THEN
    IF NEW.state IS NOT NULL THEN
      SELECT type INTO NEW.state_type FROM db.state WHERE id = NEW.state;
    ELSE
      NEW.state_type := NULL;
    END IF;
  END IF;

  IF OLD.scope IS DISTINCT FROM NEW.scope THEN
    PERFORM FROM db.area WHERE id = GetSessionArea(current_session()) AND scope = NEW.scope;
    IF NOT FOUND THEN
      NEW.scope := OLD.scope;
    END IF;
  END IF;

  IF OLD.owner IS DISTINCT FROM NEW.owner THEN
    SELECT system INTO bSystem FROM users WHERE id = OLD.owner AND scope = NEW.scope;
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

CREATE OR REPLACE FUNCTION db.ft_profile_before()
RETURNS trigger AS $$
BEGIN
  IF (TG_OP = 'UPDATE') THEN

    IF NEW.area IS DISTINCT FROM OLD.area THEN
      IF NOT IsMemberArea(NEW.area, NEW.userid) THEN
        PERFORM UserNotMemberArea(GetUserName(NEW.userid), GetAreaName(NEW.area));
      END IF;
    END IF;

    IF OLD.interface IS DISTINCT FROM NEW.interface THEN
      IF NOT IsMemberInterface(NEW.interface, NEW.userid) THEN
        PERFORM UserNotMemberInterface(GetUserName(NEW.userid), GetInterfaceName(NEW.interface));
      END IF;
    END IF;

    IF OLD.scope IS DISTINCT FROM NEW.scope THEN
      SELECT scope INTO NEW.scope FROM db.area WHERE id = NEW.area;
    END IF;

  ELSE

	IF NEW.locale IS NULL THEN
	  SELECT id INTO NEW.locale FROM db.locale WHERE code = locale_code();
	END IF;

    IF NOT IsMemberArea(NEW.area, NEW.userid) THEN
      INSERT INTO db.member_area (area, member) VALUES (NEW.area, NEW.userid) ON CONFLICT DO NOTHING;
    END IF;

    IF NOT IsMemberInterface(NEW.interface, NEW.userid) THEN
      INSERT INTO db.member_interface (interface, member) VALUES (NEW.interface, NEW.userid) ON CONFLICT DO NOTHING;
    END IF;

    IF NEW.scope IS NULL THEN
      SELECT scope INTO NEW.scope FROM db.area WHERE id = NEW.area;
    ELSE
      PERFORM FROM db.area WHERE id = NEW.area AND scope = NEW.scope;
      IF NOT FOUND THEN
        RAISE EXCEPTION 'ERR-40000: Area "% (%)" not present in scope "% (%)".', NEW.area, GetAreaName(NEW.area), NEW.scope, GetScopeName(NEW.scope);
      END IF;
    END IF;

  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--

CREATE OR REPLACE FUNCTION db.ft_job_insert()
RETURNS trigger AS $$
DECLARE
  iPeriod		interval;
BEGIN
  IF NEW.id IS NULL THEN
    SELECT NEW.document INTO NEW.id;
  END IF;

  IF NULLIF(NEW.code, '') IS NULL THEN
    NEW.code := encode(gen_random_bytes(12), 'hex');
  END IF;

  IF NEW.scheduler IS NOT NULL THEN
    SELECT period INTO iPeriod FROM db.scheduler WHERE id = NEW.scheduler;
    NEW.dateRun := Now() + coalesce(iPeriod, '0 seconds'::interval);
  END IF;

  IF NEW.dateRun IS NULL THEN
    NEW.dateRun := Now();
  END IF;

  IF NEW.scope IS NULL THEN
    NEW.scope := current_scope();
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--

SELECT AddMemberToArea(userid, GetAreaGuest(p.scope)) FROM db.profile p WHERE NOT EXISTS (SELECT id FROM db.area WHERE id = p.area AND scope = p.scope);

UPDATE db.profile p SET area = GetAreaGuest(p.scope) WHERE NOT EXISTS (SELECT id FROM db.area WHERE id = p.area AND scope = p.scope);
UPDATE db.profile p SET scope = null WHERE NOT EXISTS (SELECT id FROM db.area WHERE id = p.area AND scope = p.scope);
