ALTER TABLE db.document
  ADD scope uuid REFERENCES db.scope(id);

UPDATE db.document d SET scope = a.scope FROM db.area a WHERE a.id = d.area;

ALTER TABLE db.document
    ALTER COLUMN scope SET NOT NULL;

COMMENT ON COLUMN db.document.scope IS 'Область видимости базы данных';

CREATE INDEX ON db.document (scope);

--

ALTER TABLE db.object
  ADD scope uuid REFERENCES db.scope(id);

DROP TRIGGER t_object_before_update ON db.object;

UPDATE db.object o SET scope = d.scope FROM db.document d WHERE o.id = d.object;
UPDATE db.object o SET scope = r.scope FROM db.reference r WHERE o.id = r.object;

CREATE TRIGGER t_object_before_update
  BEFORE UPDATE ON db.object
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_object_before_update();

ALTER TABLE db.object
    ALTER COLUMN scope SET NOT NULL;

COMMENT ON COLUMN db.object.scope IS 'Область видимости базы данных';

CREATE INDEX ON db.object (scope);

DROP VIEW IF EXISTS SafeDocument CASCADE;
DROP VIEW IF EXISTS SafeObject CASCADE;

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

  SELECT current_scope() INTO NEW.scope;

  SELECT type INTO NEW.state_type FROM db.state WHERE id = NEW.state;

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

--

CREATE OR REPLACE FUNCTION db.ft_document_insert()
RETURNS trigger AS $$
BEGIN
  IF NEW.id IS NULL THEN
    SELECT NEW.object INTO NEW.id;
  END IF;

  IF current_area_type() = '00000000-0000-4002-a000-000000000000' THEN
    PERFORM RootAreaError();
  END IF;

  IF NEW.area IS NULL THEN
    SELECT current_area() INTO NEW.area;
  END IF;

  SELECT scope INTO NEW.scope FROM db.area WHERE id = NEW.area;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
