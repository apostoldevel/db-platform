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
