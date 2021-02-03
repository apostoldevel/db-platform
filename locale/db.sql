--------------------------------------------------------------------------------
-- db.locale -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.locale (
    id		    numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    code	    text NOT NULL,
    name	    text NOT NULL,
    description	text
);

COMMENT ON TABLE db.locale IS 'Локаль.';

COMMENT ON COLUMN db.locale.id IS 'Идентификатор';
COMMENT ON COLUMN db.locale.code IS 'Код';
COMMENT ON COLUMN db.locale.name IS 'Наименование';
COMMENT ON COLUMN db.locale.description IS 'Описание';

CREATE UNIQUE INDEX ON db.locale(code);

--------------------------------------------------------------------------------

INSERT INTO db.locale (code, name, description) VALUES ('ru', 'Русский', 'Русский язык');
INSERT INTO db.locale (code, name, description) VALUES ('en', 'English', 'English');

--------------------------------------------------------------------------------
-- FUNCTION GetLocale ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetLocale (
  pCode		text
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM db.locale WHERE code = pCode;
  RETURN nId;
END;
$$ LANGUAGE plpgsql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetLocaleCode ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetLocaleCode (
  pId		numeric
) RETURNS	text
AS $$
DECLARE
  vCode		text;
BEGIN
  SELECT code INTO vCode FROM db.locale WHERE id = pId;
  return vCode;
END;
$$ LANGUAGE plpgsql STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- Locale ----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Locale
as
  SELECT * FROM db.locale;

GRANT SELECT ON Locale TO administrator;
