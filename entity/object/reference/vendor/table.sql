--------------------------------------------------------------------------------
-- VENDOR ----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.vendor -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.vendor (
    id			    uuid PRIMARY KEY,
    reference		uuid NOT NULL REFERENCES db.reference(id) ON DELETE CASCADE
);

COMMENT ON TABLE db.vendor IS 'Производитель (поставщик).';

COMMENT ON COLUMN db.vendor.id IS 'Идентификатор.';
COMMENT ON COLUMN db.vendor.reference IS 'Справочник.';

CREATE INDEX ON db.vendor (reference);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_vendor_insert()
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

CREATE TRIGGER t_vendor_insert
  BEFORE INSERT ON db.vendor
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_vendor_insert();
