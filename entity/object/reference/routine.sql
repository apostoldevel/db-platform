--------------------------------------------------------------------------------
-- CreateReference -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateReference (
  pParent       numeric,
  pType         numeric,
  pCode         text,
  pName         text,
  pDescription  text DEFAULT null
) RETURNS       numeric
AS $$
DECLARE
  nObject       numeric;
  nEntity       numeric;
  nClass        numeric;

--  vCode         text;
BEGIN
  nObject := CreateObject(pParent, pType, pName, pDescription);

  nEntity := GetObjectEntity(nObject);
  nClass := GetObjectClass(nObject);

--  IF StrPos(pCode, '.') = 0 THEN
--    SELECT code INTO vCode FROM db.entity WHERE Id = nEntity;
--    pCode := pCode || '.' || vCode;
--  END IF;

  INSERT INTO db.reference (id, object, entity, class, code, name, description)
  VALUES (nObject, nObject, nEntity, nClass, pCode, pName, pDescription)
  RETURNING id INTO nObject;

  RETURN nObject;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditReference ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditReference (
  pId           numeric,
  pParent       numeric DEFAULT null,
  pType         numeric DEFAULT null,
  pCode         text DEFAULT null,
  pName         text DEFAULT null,
  pDescription  text DEFAULT null
) RETURNS       void
AS $$
BEGIN
  PERFORM EditObject(pId, pParent, pType, pName, pDescription);

  UPDATE db.reference
     SET code = coalesce(pCode, code),
         name = coalesce(pName, name),
         description = CheckNull(coalesce(pDescription, description, '<null>'))
   WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetReference -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetReference (
  pCode         text,
  pEntity       numeric
) RETURNS       numeric
AS $$
DECLARE
  nId           numeric;
--  vCode         text;
BEGIN
--  IF StrPos(pCode, '.') = 0 THEN
--    SELECT code INTO vCode FROM db.entity WHERE Id = pEntity;
--    pCode := pCode || '.' || vCode;
--  END IF;

  SELECT id INTO nId FROM db.reference WHERE entity = pEntity AND code = pCode;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetReference -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetReference (
  pCode         text,
  pEntity       text DEFAULT null
) RETURNS       numeric
AS $$
BEGIN
  RETURN GetReference(pCode, GetEntity(coalesce(pEntity, SubStr(pCode, StrPos(pCode, '.') + 1))));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetReferenceCode ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetReferenceCode (
  pId           numeric
) RETURNS       text
AS $$
DECLARE
  vCode         text;
BEGIN
  SELECT code INTO vCode FROM db.reference WHERE id = pId;
  RETURN vCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetReferenceName ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetReferenceName (
  pId           numeric
) RETURNS       text
AS $$
DECLARE
  vName         text;
BEGIN
  SELECT name INTO vName FROM db.reference WHERE id = pId;
  RETURN vName;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
