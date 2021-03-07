--------------------------------------------------------------------------------
-- db.scope --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.scope (
    id              uuid PRIMARY KEY DEFAULT gen_kernel_uuid('8'),
    code            text NOT NULL,
    name            text NOT NULL,
    description     text
);

COMMENT ON TABLE db.scope IS 'Область видимости объектов.';

COMMENT ON COLUMN db.scope.id IS 'Идентификатор';
COMMENT ON COLUMN db.scope.code IS 'Код';
COMMENT ON COLUMN db.scope.name IS 'Наименование';
COMMENT ON COLUMN db.scope.description IS 'Описание';

CREATE UNIQUE INDEX ON db.scope (code);

--------------------------------------------------------------------------------
-- db.member_scope -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.member_scope (
    scope		uuid NOT NULL REFERENCES db.scope(id),
    member		uuid NOT NULL REFERENCES db.user(id),
    PRIMARY KEY (scope, member)
);

COMMENT ON TABLE db.member_scope IS 'Участники области видимости объектов.';

COMMENT ON COLUMN db.member_scope.scope IS 'Область видимости объектов';
COMMENT ON COLUMN db.member_scope.member IS 'Учётная запись пользователя';

CREATE INDEX ON db.member_scope (scope);
CREATE INDEX ON db.member_scope (member);

--------------------------------------------------------------------------------
-- db.psl ----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.psl (
    provider	integer REFERENCES oauth2.provider(id) ON DELETE CASCADE,
    scope		uuid REFERENCES db.scope(id) ON DELETE CASCADE,
    PRIMARY KEY (provider, scope)
);

COMMENT ON TABLE db.psl IS 'Список областей видимости поставщика OAuth2.';

COMMENT ON COLUMN db.psl.provider IS 'Поставщик OAuth2';
COMMENT ON COLUMN db.psl.scope IS 'Область видимости';

--------------------------------------------------------------------------------

COMMENT ON TABLE db.area IS 'Область видимости документов.';

COMMENT ON TABLE db.member_area IS 'Участники области видимости документов.';

COMMENT ON COLUMN db.member_area.area IS 'Область видимости документов';
COMMENT ON COLUMN db.member_area.member IS 'Учётная запись пользователя';

COMMENT ON COLUMN db.session.area IS 'Область видимости документов';

COMMENT ON COLUMN db.listener.session IS 'Сессия';
--------------------------------------------------------------------------------

\ir '../admin/routine.sql'

--------------------------------------------------------------------------------

\connect :dbname admin

--------------------------------------------------------------------------------

SELECT SignIn(CreateSystemOAuth2(), 'admin', 'admin');

SELECT GetErrorMessage();

SELECT CreateScope(current_database(), current_database(), 'Область видимости текущей базы данных.');

SELECT SetProviderScope(id, GetScope(current_database())) FROM Provider;

SELECT SignOut();

--------------------------------------------------------------------------------

\connect :dbname kernel

--------------------------------------------------------------------------------

ALTER TABLE db.object
	ADD COLUMN scope uuid REFERENCES db.scope(id);

COMMENT ON COLUMN db.object.scope IS 'Облась видимости';

CREATE INDEX ON db.object (scope);

ALTER TABLE db.object DISABLE TRIGGER t_object_before_update;

UPDATE db.object SET scope = GetScope(current_database());

ALTER TABLE db.object ENABLE TRIGGER t_object_before_update;

ALTER TABLE db.object
	ALTER COLUMN scope SET NOT NULL;

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_object_before_insert()
RETURNS trigger AS $$
DECLARE
  bAbstract	boolean;
BEGIN
  IF lower(session_user) = 'kernel' THEN
    PERFORM AccessDeniedForUser(session_user);
  END IF;

  IF NEW.id IS NULL THEN
    SELECT gen_kernel_uuid('8') INTO NEW.id;
  END IF;

  IF NEW.scope IS NULL THEN
    SELECT GetScope(current_database()) INTO NEW.scope;
  END IF;

  SELECT class INTO NEW.class FROM db.type WHERE id = NEW.type;
  SELECT entity, abstract INTO NEW.entity, bAbstract FROM db.class_tree WHERE id = NEW.class;

  IF bAbstract THEN
    PERFORM AbstractError();
  END IF;

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
