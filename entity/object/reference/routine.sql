--------------------------------------------------------------------------------
-- CreateReference -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateReference (
  pParent       uuid,
  pType         uuid,
  pCode         text,
  pName         text,
  pDescription  text DEFAULT null,
  pLocale		uuid DEFAULT current_locale()
) RETURNS       uuid
AS $$
DECLARE
  nObject       uuid;
  nEntity       uuid;
  uClass        uuid;
BEGIN
  nObject := CreateObject(pParent, pType, pName, pDescription);

  nEntity := GetObjectEntity(nObject);
  uClass := GetObjectClass(nObject);

  INSERT INTO db.reference (id, object, entity, class, type, code)
  VALUES (nObject, nObject, nEntity, uClass, pType, pCode)
  RETURNING id INTO nObject;

  INSERT INTO db.reference_text (reference, locale, name, description)
  VALUES (nObject, pLocale, pName, pDescription);

  RETURN nObject;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditReference ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditReference (
  pId           uuid,
  pParent       uuid DEFAULT null,
  pType         uuid DEFAULT null,
  pCode         text DEFAULT null,
  pName         text DEFAULT null,
  pDescription  text DEFAULT null,
  pLocale		uuid DEFAULT current_locale()
) RETURNS       void
AS $$
BEGIN
  PERFORM EditObject(pId, pParent, pType, pName, pDescription);

  UPDATE db.reference
     SET type = coalesce(pType, type),
         code = coalesce(pCode, code)
   WHERE id = pId;

  UPDATE db.reference_text
     SET name = CheckNull(coalesce(pName, name, '<null>')),
         description = CheckNull(coalesce(pDescription, description, '<null>'))
   WHERE reference = pId AND locale = pLocale;

  IF NOT FOUND THEN
	INSERT INTO db.reference_text (reference, locale, name, description)
	VALUES (pId, pLocale, pName, pDescription);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetReference -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetReference (
  pCode         text,
  pEntity       uuid
) RETURNS       uuid
AS $$
DECLARE
  uId           uuid;
  uScope		uuid;
BEGIN
  uScope := current_scope();
  SELECT id INTO uId FROM db.reference WHERE scope = uScope AND entity = pEntity AND code = pCode;
  RETURN uId;
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
) RETURNS       uuid
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
  pId           uuid
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
  pId           uuid,
  pLocale		uuid DEFAULT current_locale()
) RETURNS       text
AS $$
DECLARE
  vName         text;
BEGIN
  SELECT name INTO vName FROM db.reference_text WHERE reference = pId AND locale = pLocale;
  RETURN vName;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
