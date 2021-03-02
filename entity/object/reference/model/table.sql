--------------------------------------------------------------------------------
-- MODEL -----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.model --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.model (
    id			    uuid PRIMARY KEY,
    reference		uuid NOT NULL REFERENCES db.reference(id) ON DELETE CASCADE,
    vendor          uuid NOT NULL REFERENCES db.vendor(id) ON DELETE RESTRICT,
    category		uuid REFERENCES db.category(id) ON DELETE RESTRICT
);

COMMENT ON TABLE db.model IS 'Модель.';

COMMENT ON COLUMN db.model.id IS 'Идентификатор.';
COMMENT ON COLUMN db.model.reference IS 'Справочник.';
COMMENT ON COLUMN db.model.vendor IS 'Производитель (поставщик).';
COMMENT ON COLUMN db.model.category IS 'Категория.';

CREATE INDEX ON db.model (reference);
CREATE INDEX ON db.model (vendor);
CREATE INDEX ON db.model (category);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_model_insert()
RETURNS trigger AS $$
DECLARE
BEGIN
  IF NEW.id IS NULL THEN
    SELECT NEW.reference INTO NEW.id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_model_insert
  BEFORE INSERT ON db.model
  FOR EACH ROW
  EXECUTE PROCEDURE ft_model_insert();

--------------------------------------------------------------------------------
-- db.model_property -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.model_property (
    model		uuid NOT NULL REFERENCES db.model(id) ON DELETE CASCADE,
    property	uuid NOT NULL REFERENCES db.property(id) ON DELETE RESTRICT,
    measure		uuid REFERENCES db.measure(id),
    value		variant,
    format		text,
    sequence	integer NOT NULL,
    PRIMARY KEY (model, property)
);

COMMENT ON TABLE db.model_property IS 'Свойства модели.';

COMMENT ON COLUMN db.model_property.model IS 'Модель.';
COMMENT ON COLUMN db.model_property.property IS 'Свойство.';
COMMENT ON COLUMN db.model_property.measure IS 'Мера.';
COMMENT ON COLUMN db.model_property.value IS 'Значение.';
COMMENT ON COLUMN db.model_property.format IS 'Формат.';
COMMENT ON COLUMN db.model_property.sequence IS 'Очерёдность';

CREATE INDEX ON db.model_property (model);
CREATE INDEX ON db.model_property (property);
CREATE INDEX ON db.model_property (measure);

--------------------------------------------------------------------------------
