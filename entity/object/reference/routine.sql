--------------------------------------------------------------------------------
-- NewReferenceText ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION NewReferenceText (
  pReference    uuid,
  pName         text,
  pDescription  text DEFAULT null,
  pLocale       uuid DEFAULT current_locale()
) RETURNS       void
AS $$
BEGIN
  INSERT INTO db.reference_text (reference, locale, name, description)
  VALUES (pReference, pLocale, pName, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditReferenceText -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditReferenceText (
  pReference    uuid,
  pName         text,
  pDescription  text DEFAULT null,
  pLocale       uuid DEFAULT null
) RETURNS       void
AS $$
BEGIN
  UPDATE db.reference_text
     SET name = CheckNull(coalesce(pName, name, '')),
         description = CheckNull(coalesce(pDescription, description, ''))
   WHERE reference = pReference AND locale = pLocale;

  IF NOT FOUND THEN
    PERFORM NewReferenceText(pReference, pName, pDescription, pLocale);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateReference -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateReference (
  pParent       uuid,
  pType         uuid,
  pCode         text,
  pName         text,
  pDescription  text DEFAULT null,
  pLocale       uuid DEFAULT null
) RETURNS       uuid
AS $$
DECLARE
  l             record;

  uObject       uuid;
  uEntity       uuid;
  uClass        uuid;
BEGIN
  uObject := CreateObject(pParent, pType, pName, pDescription);

  uEntity := GetObjectEntity(uObject);
  uClass := GetObjectClass(uObject);

  INSERT INTO db.reference (id, object, scope, entity, class, type, code)
  VALUES (uObject, uObject, current_scope(), uEntity, uClass, pType, pCode)
  RETURNING id INTO uObject;

  IF pLocale IS NULL THEN
    FOR l IN SELECT id FROM db.locale
    LOOP
      PERFORM NewReferenceText(uObject, pName, pDescription, l.id);
    END LOOP;
  ELSE
    PERFORM NewReferenceText(uObject, pName, pDescription, pLocale);
  END IF;

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
  pLocale       uuid DEFAULT null
) RETURNS       void
AS $$
DECLARE
  l             record;
BEGIN
  PERFORM EditObject(pId, pParent, pType, pName, pDescription, pLocale);

  UPDATE db.reference
     SET type = coalesce(pType, type),
         code = coalesce(pCode, code)
   WHERE id = pId;

  IF pLocale IS NULL THEN
    FOR l IN SELECT id FROM db.locale
    LOOP
      PERFORM EditReferenceText(pId, pName, pDescription, l.id);
    END LOOP;
  ELSE
    PERFORM EditReferenceText(pId, pName, pDescription, pLocale);
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
  pScope        uuid DEFAULT current_scope()
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
  pLocale       uuid DEFAULT current_locale()
) RETURNS       text
AS $$
  SELECT name FROM db.reference_text WHERE reference = pId AND locale = pLocale;
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetReferenceDescription --------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetReferenceDescription (
  pId           uuid,
  pLocale       uuid DEFAULT current_locale()
) RETURNS       text
AS $$
  SELECT description FROM db.reference_text WHERE reference = pId AND locale = pLocale;
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
