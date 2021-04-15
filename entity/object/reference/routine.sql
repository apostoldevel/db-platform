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
  uObject       uuid;
  uEntity       uuid;
  uClass        uuid;
BEGIN
  uObject := CreateObject(pParent, pType, pName, pDescription);

  uEntity := GetObjectEntity(uObject);
  uClass := GetObjectClass(uObject);

  INSERT INTO db.reference (id, object, entity, class, type, code)
  VALUES (uObject, uObject, uEntity, uClass, pType, pCode)
  RETURNING id INTO uObject;

  INSERT INTO db.reference_text (reference, locale, name, description)
  VALUES (uObject, pLocale, pName, pDescription);

  RETURN uObject;
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
  pEntity       uuid,
  pCode         text,
  pScope		uuid DEFAULT current_scope()
) RETURNS       uuid
AS $$
  SELECT id FROM db.reference WHERE scope = pScope AND entity = pEntity AND code = pCode;
$$ LANGUAGE sql
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
  RETURN GetReference(GetEntity(coalesce(pEntity, SubStr(pCode, StrPos(pCode, '.') + 1))), pCode);
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
  SELECT code FROM db.reference WHERE id = pId;
$$ LANGUAGE sql
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
  SELECT name FROM db.reference_text WHERE reference = pId AND locale = pLocale;
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
