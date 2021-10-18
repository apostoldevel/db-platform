-- KERNEL

DROP VIEW IF EXISTS Documents CASCADE;

DROP VIEW IF EXISTS CatalogTree CASCADE;
DROP VIEW IF EXISTS LibraryTree CASCADE;
DROP VIEW IF EXISTS SpecificationTree CASCADE;

--

CREATE OR REPLACE FUNCTION db.ft_profile_before()
RETURNS trigger AS $$
BEGIN
  IF NEW.locale IS NULL THEN
    SELECT id INTO NEW.locale FROM db.locale WHERE code = 'ru';
  END IF;

  IF NEW.scope IS NULL THEN
    SELECT current_scope() INTO NEW.scope;
  END IF;

  SELECT id INTO NEW.area FROM db.area WHERE id = NEW.area AND scope = NEW.scope;

  IF NOT IsMemberArea(NEW.area, NEW.userid) THEN
    SELECT GetAreaGuest(NEW.scope) INTO NEW.area; -- guest
  END IF;

  IF NEW.area IS NULL THEN
    SELECT OLD.area INTO NEW.area;
  END IF;

  IF NOT IsMemberInterface(NEW.interface, NEW.userid) THEN
    SELECT '00000000-0000-4004-a000-000000000003' INTO NEW.interface; -- guest
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--

DROP TRIGGER IF EXISTS t_profile_login_state ON db.profile;

CREATE TRIGGER t_profile_login_state
  BEFORE UPDATE ON db.profile
  FOR EACH ROW
  WHEN (OLD.lc_ip IS DISTINCT FROM NEW.lc_ip)
  EXECUTE PROCEDURE ft_profile_login_state();
