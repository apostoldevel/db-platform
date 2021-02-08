--------------------------------------------------------------------------------
-- CreateDocument --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateDocument (
  pParent	    numeric,
  pType		    numeric,
  pLabel	    text DEFAULT null,
  pDescription  text DEFAULT null,
  pData			text DEFAULT null
) RETURNS 	    numeric
AS $$
DECLARE
  nObject	    numeric;
  nEntity		numeric;
  nClass        numeric;
BEGIN
  nObject := CreateObject(pParent, pType, pLabel, coalesce(pData, pDescription));

  nEntity := GetObjectEntity(nObject);
  nClass := GetObjectClass(nObject);

  INSERT INTO db.document (id, object, entity, class, area, description)
  VALUES (nObject, nObject, nEntity, nClass, current_area(), pDescription)
  RETURNING id INTO nObject;

  RETURN nObject;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditDocument ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditDocument (
  pId           numeric,
  pParent       numeric DEFAULT null,
  pType         numeric DEFAULT null,
  pLabel        text DEFAULT null,
  pDescription  text DEFAULT null,
  pData			text DEFAULT null
) RETURNS       void
AS $$
BEGIN
  PERFORM EditObject(pId, pParent, pType, pLabel, coalesce(pData, pDescription));

  UPDATE db.document
     SET description = CheckNull(coalesce(pDescription, description, '<null>'))
   WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
