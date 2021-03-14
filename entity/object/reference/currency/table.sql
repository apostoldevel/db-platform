--------------------------------------------------------------------------------
-- CURRENCY --------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.currency -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.currency (
    id			    uuid PRIMARY KEY,
    reference		uuid NOT NULL REFERENCES db.reference(id) ON DELETE CASCADE,
    digital			integer,
    decimal			integer DEFAULT 2
);

COMMENT ON TABLE db.currency IS 'Валюта.';

COMMENT ON COLUMN db.currency.id IS 'Идентификатор.';
COMMENT ON COLUMN db.currency.reference IS 'Справочник.';
COMMENT ON COLUMN db.currency.digital IS 'Цифровой код.';
COMMENT ON COLUMN db.currency.decimal IS 'Количество знаков после запятой.';

CREATE INDEX ON db.currency (reference);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_currency_insert()
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

CREATE TRIGGER t_currency_insert
  BEFORE INSERT ON db.currency
  FOR EACH ROW
  EXECUTE PROCEDURE ft_currency_insert();
