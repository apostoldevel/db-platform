--------------------------------------------------------------------------------
-- CreateReport ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateReport (
  pParent       uuid,
  pType         uuid,
  pTree         uuid,
  pForm         uuid,
  pCode         text,
  pName         text default null,
  pDescription	text default null,
  pInfo         jsonb default null
) RETURNS       uuid
AS $$
DECLARE
  uReference    uuid;
  uClass        uuid;
  uMethod       uuid;
BEGIN
  SELECT class INTO uClass FROM db.type WHERE id = pType;

  IF GetEntityCode(uClass) <> 'report' THEN
    PERFORM IncorrectClassType();
  END IF;

  uReference := CreateReference(pParent, pType, pCode, pName, pDescription);

  INSERT INTO db.report (id, reference, tree, form, info)
  VALUES (uReference, uReference, pTree, pForm, pInfo);

  uMethod := GetMethod(uClass, GetAction('create'));
  PERFORM ExecuteMethod(uReference, uMethod);

  RETURN uReference;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditReport ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditReport (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pTree         uuid default null,
  pForm         uuid default null,
  pCode         text default null,
  pName         text default null,
  pDescription	text default null,
  pInfo         jsonb default null
) RETURNS       void
AS $$
DECLARE
  uClass        uuid;
  uMethod       uuid;
BEGIN
  PERFORM EditReference(pId, pParent, pType, pCode, pName, pDescription, current_locale());

  UPDATE db.report
     SET tree = coalesce(pTree, tree),
         form = CheckNull(coalesce(pForm, form, null_uuid())),
         info = CheckNull(coalesce(pInfo, info, '{}'))
   WHERE id = pId;

  SELECT class INTO uClass FROM db.object WHERE id = pId;

  uMethod := GetMethod(uClass, GetAction('edit'));
  PERFORM ExecuteMethod(pId, uMethod);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetReport -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetReport (
  pCode		text
) RETURNS	uuid
AS $$
BEGIN
  RETURN GetReference(pCode, 'report');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
