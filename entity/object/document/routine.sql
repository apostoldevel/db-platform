--------------------------------------------------------------------------------
-- CreateDocument --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateDocument (
  pParent	    uuid,
  pType		    uuid,
  pLabel	    text DEFAULT null,
  pDescription  text DEFAULT null,
  pText			text DEFAULT null,
  pLocale		uuid DEFAULT current_locale()
) RETURNS 	    uuid
AS $$
DECLARE
  uObject	    uuid;
  uEntity		uuid;
  uClass        uuid;
BEGIN
  uObject := CreateObject(pParent, pType, pLabel, coalesce(pText, pDescription));

  uEntity := GetObjectEntity(uObject);
  uClass := GetObjectClass(uObject);

  INSERT INTO db.document (id, object, entity, class, type, area)
  VALUES (uObject, uObject, uEntity, uClass, pType, current_area())
  RETURNING id INTO uObject;

  INSERT INTO db.document_text (document, locale, description)
  VALUES (uObject, pLocale, pDescription);

  RETURN uObject;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditDocument ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditDocument (
  pId           uuid,
  pParent       uuid DEFAULT null,
  pType         uuid DEFAULT null,
  pLabel        text DEFAULT null,
  pDescription  text DEFAULT null,
  pText			text DEFAULT null,
  pLocale		uuid DEFAULT current_locale()
) RETURNS       void
AS $$
BEGIN
  PERFORM EditObject(pId, pParent, pType, pLabel, coalesce(pText, pDescription));

  UPDATE db.document
     SET type = coalesce(pType, type)
   WHERE id = pId;

  UPDATE db.document_text
     SET description = CheckNull(coalesce(pDescription, description, '<null>'))
   WHERE document = pId AND locale = pLocale;

  IF NOT FOUND THEN
	INSERT INTO db.document_text (document, locale, description)
	VALUES (pId, pLocale, pDescription);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
