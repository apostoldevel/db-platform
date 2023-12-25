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

COMMENT ON TABLE db.area IS 'Область видимости документов.';

COMMENT ON TABLE db.member_area IS 'Участники области видимости документов.';

COMMENT ON COLUMN db.member_area.area IS 'Область видимости документов';
COMMENT ON COLUMN db.member_area.member IS 'Учётная запись пользователя';

COMMENT ON COLUMN db.session.area IS 'Область видимости документов';

COMMENT ON COLUMN db.listener.session IS 'Сессия';
--------------------------------------------------------------------------------

INSERT INTO db.scope (code, name, description)
VALUES (current_database(), current_database(), 'Область видимости текущей базы данных.');

--------------------------------------------------------------------------------

DROP FUNCTION CreateSystemOAuth2() CASCADE;

\ir '../admin/routine.sql'

--------------------------------------------------------------------------------

DROP VIEW api.whoami CASCADE;
DROP VIEW Area CASCADE;

DROP FUNCTION api.add_area (uuid, uuid, text, text, text);
DROP FUNCTION api.update_area (uuid, uuid, uuid, text, text, text, timestamp, timestamp);

DROP FUNCTION CreateArea (uuid, uuid, text, text, text, uuid);
DROP FUNCTION EditArea (uuid, uuid, uuid, text, text, text, timestamp, timestamp);

ALTER TABLE db.area
  ADD COLUMN scope uuid REFERENCES db.scope(id);

UPDATE db.area SET scope = GetScope(current_database());

ALTER TABLE db.area
    ALTER COLUMN scope SET NOT NULL;

COMMENT ON COLUMN db.area.scope IS 'Область видимости базы данных';

CREATE INDEX ON db.area (scope);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_area_before_insert()
RETURNS trigger AS $$
DECLARE
BEGIN
  IF NEW.id IS NULL THEN
    NEW.id := gen_kernel_uuid('8');
  END IF;

  IF NEW.id = NEW.parent THEN
    NEW.parent := GetArea('all');
  END IF;

  IF NEW.scope IS NULL THEN
    NEW.scope := GetScope(current_database());
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

ALTER TABLE db.reference
    ADD COLUMN scope uuid REFERENCES db.scope(id);

COMMENT ON COLUMN db.reference.scope IS 'Облась видимости';

CREATE INDEX ON db.reference (scope);

UPDATE db.reference SET scope = GetScope(current_database());

ALTER TABLE db.reference
	ALTER COLUMN scope SET NOT NULL;

DROP INDEX IF EXISTS db.reference_entity_code_idx;

CREATE UNIQUE INDEX ON db.reference (scope, entity, code);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_reference_before_insert()
RETURNS trigger AS $$
DECLARE
  vCode		text;
BEGIN
  IF NEW.id IS NULL THEN
    SELECT NEW.object INTO NEW.id;
  END IF;

  IF NEW.scope IS NULL THEN
    SELECT current_scope() INTO NEW.scope;
  END IF;

  IF NULLIF(NEW.code, '') IS NULL THEN
    SELECT code INTO vCode FROM db.class_tree WHERE id = NEW.class;
    NEW.code := concat(encode(gen_random_bytes(12), 'hex'), '.', vCode);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
