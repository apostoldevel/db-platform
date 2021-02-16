--------------------------------------------------------------------------------
-- ADDRESS ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.address (
    id			uuid PRIMARY KEY,
    document	uuid NOT NULL REFERENCES db.document(id) ON DELETE CASCADE,
    code		text NOT NULL,
    index		text,
    country		text,
    region		text,
    district	text,
    city		text,
    settlement	text,
    street		text,
    house		text,
    building	text,
    structure	text,
    apartment	text,
    sortnum		integer NOT NULL
);

COMMENT ON TABLE db.address IS 'Адрес объекта.';

COMMENT ON COLUMN db.address.id IS 'Идентификатор';
COMMENT ON COLUMN db.address.document IS 'Ссылка на документ';
COMMENT ON COLUMN db.address.code IS 'Код из справочника адресов в виде дерева';
COMMENT ON COLUMN db.address.index IS 'Почтовый индекс';
COMMENT ON COLUMN db.address.country IS 'Страна';
COMMENT ON COLUMN db.address.region IS 'Регион';
COMMENT ON COLUMN db.address.district IS 'Район';
COMMENT ON COLUMN db.address.city IS 'Город';
COMMENT ON COLUMN db.address.settlement IS 'Населённый пункт';
COMMENT ON COLUMN db.address.street IS 'Улица';
COMMENT ON COLUMN db.address.house IS 'Дом';
COMMENT ON COLUMN db.address.building IS 'Корпус';
COMMENT ON COLUMN db.address.structure IS 'Строение';
COMMENT ON COLUMN db.address.apartment IS 'Квартира';
COMMENT ON COLUMN db.address.sortnum IS 'Номер для сортировки';

CREATE INDEX ON db.address (document);
CREATE INDEX ON db.address (code);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_address_insert()
RETURNS trigger AS $$
BEGIN
  IF NEW.id IS NULL THEN
    SELECT NEW.document INTO NEW.id;
  END IF;

  IF NULLIF(NEW.sortnum, 0) IS NULL THEN
    SELECT NEW.id INTO NEW.sortnum;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_address_insert
  BEFORE INSERT ON db.address
  FOR EACH ROW
  EXECUTE PROCEDURE ft_address_insert();
