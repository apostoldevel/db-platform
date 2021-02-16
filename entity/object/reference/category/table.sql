--------------------------------------------------------------------------------
-- CATEGORY --------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.category -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.category (
    id			    uuid PRIMARY KEY,
    reference		uuid NOT NULL REFERENCES db.reference(id) ON DELETE CASCADE
);

COMMENT ON TABLE db.category IS 'Категория.';

COMMENT ON COLUMN db.category.id IS 'Идентификатор.';
COMMENT ON COLUMN db.category.reference IS 'Справочник.';

CREATE INDEX ON db.category (reference);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_category_insert()
RETURNS trigger AS $$
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

CREATE TRIGGER t_category_insert
  BEFORE INSERT ON db.category
  FOR EACH ROW
  EXECUTE PROCEDURE ft_category_insert();

