--------------------------------------------------------------------------------
-- db.reference ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.reference (
    id              uuid PRIMARY KEY,
    object          uuid NOT NULL REFERENCES db.object(id),
    scope           uuid NOT NULL REFERENCES db.scope(id),
    entity          uuid NOT NULL REFERENCES db.entity(id),
    class           uuid NOT NULL REFERENCES db.class_tree(id),
    type            uuid NOT NULL REFERENCES db.type(id),
    code            text NOT NULL
);

COMMENT ON TABLE db.reference IS 'Reference catalog — abstract base for code + name entities (agents, vendors, versions, etc.).';

COMMENT ON COLUMN db.reference.id IS 'Primary key (same as object.id).';
COMMENT ON COLUMN db.reference.object IS 'Link to the parent db.object row.';
COMMENT ON COLUMN db.reference.scope IS 'Scope that owns this reference.';
COMMENT ON COLUMN db.reference.entity IS 'Entity type this reference belongs to.';
COMMENT ON COLUMN db.reference.class IS 'Class within the entity hierarchy.';
COMMENT ON COLUMN db.reference.type IS 'Concrete type of this reference.';
COMMENT ON COLUMN db.reference.code IS 'Unique business code within scope + entity.';

CREATE INDEX ON db.reference (object);
CREATE INDEX ON db.reference (scope);
CREATE INDEX ON db.reference (entity);
CREATE INDEX ON db.reference (class);
CREATE INDEX ON db.reference (type);

CREATE UNIQUE INDEX ON db.reference (scope, entity, code);

--------------------------------------------------------------------------------

/**
 * @brief Auto-set id, validate area, default scope, and generate code for new reference rows.
 * @return {trigger}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION db.ft_reference_before_insert()
RETURNS trigger AS $$
DECLARE
  vCode    text;
BEGIN
  IF NEW.id IS NULL THEN
    SELECT NEW.object INTO NEW.id;
  END IF;

  IF current_area_type() = '00000000-0000-4002-a000-000000000000'::uuid THEN
    PERFORM RootAreaError();
  END IF;

  IF current_area_type() = '00000000-0000-4002-a000-000000000002'::uuid THEN
    PERFORM GuestAreaError();
  END IF;

  IF NEW.scope IS NULL THEN
    SELECT current_scope() INTO NEW.scope;
  END IF;

  IF NULLIF(NEW.code, '') IS NULL THEN
    vCode := GetEntityCode(NEW.entity);
    IF length(vCode) > 5 THEN
	  vCode := SubStr(vCode, 1, 3);
	END IF;
    NEW.code := concat(vCode, '_', gen_random_code());
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, public, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_reference_before_insert
  BEFORE INSERT ON db.reference
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_reference_before_insert();

--------------------------------------------------------------------------------

/**
 * @brief Recalculate class and entity from the new type and reject cross-entity type changes.
 * @return {trigger}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION db.ft_reference_before_update_type()
RETURNS trigger AS $$
BEGIN
  SELECT class INTO NEW.class FROM db.type WHERE id = NEW.type;
  SELECT entity INTO NEW.entity FROM db.class_tree WHERE id = NEW.class;

  IF OLD.entity <> NEW.entity THEN
    PERFORM IncorrectEntity();
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_reference_before_update_type
  BEFORE UPDATE ON db.reference
  FOR EACH ROW
  WHEN (OLD.type IS DISTINCT FROM NEW.type)
  EXECUTE PROCEDURE db.ft_reference_before_update_type();

--------------------------------------------------------------------------------
-- db.reference_text -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.reference_text (
    reference       uuid NOT NULL REFERENCES db.reference(id) ON DELETE CASCADE,
    locale          uuid NOT NULL REFERENCES db.locale(id) ON DELETE RESTRICT,
    name            text,
    description     text,
    PRIMARY KEY (reference, locale)
);

--------------------------------------------------------------------------------

COMMENT ON TABLE db.reference_text IS 'Localized text (name, description) for a reference catalog entry.';

COMMENT ON COLUMN db.reference_text.reference IS 'Reference this text belongs to.';
COMMENT ON COLUMN db.reference_text.locale IS 'Locale of the translation.';
COMMENT ON COLUMN db.reference_text.name IS 'Display name in the given locale.';
COMMENT ON COLUMN db.reference_text.description IS 'Optional description in the given locale.';

--------------------------------------------------------------------------------

CREATE INDEX ON db.reference_text (reference);
CREATE INDEX ON db.reference_text (locale);

CREATE INDEX ON db.reference_text (name);
CREATE INDEX ON db.reference_text (name text_pattern_ops);

--------------------------------------------------------------------------------

/**
 * @brief Propagate reference name changes to the corresponding object_text label.
 * @return {trigger}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION db.ft_reference_text_update_name()
RETURNS trigger AS $$
BEGIN
  UPDATE db.object_text SET label = NEW.name WHERE object = NEW.reference AND locale = NEW.locale;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_reference_text_update_name
  AFTER UPDATE ON db.reference_text
  FOR EACH ROW
  WHEN (OLD.name IS DISTINCT FROM NEW.name)
  EXECUTE PROCEDURE db.ft_reference_text_update_name();
