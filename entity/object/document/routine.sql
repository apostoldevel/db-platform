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
  nObject	    uuid;
  nEntity		uuid;
  uClass        uuid;
BEGIN
  nObject := CreateObject(pParent, pType, pLabel, coalesce(pText, pDescription));

  nEntity := GetObjectEntity(nObject);
  uClass := GetObjectClass(nObject);

  INSERT INTO db.document (id, object, entity, class, type, area)
  VALUES (nObject, nObject, nEntity, uClass, pType, current_area())
  RETURNING id INTO nObject;

  INSERT INTO db.document_text (document, locale, description)
  VALUES (nObject, pLocale, pDescription);

  RETURN nObject;
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
