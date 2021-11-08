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

--------------------------------------------------------------------------------
-- GetForReportDocumentJson ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetForReportDocumentJson (
  pEntity   uuid,
  pLimit    integer DEFAULT 500
) RETURNS	json
AS $$
DECLARE
  r			record;
  arResult	json[];
BEGIN
  FOR r IN
    SELECT id AS value, label
      FROM ObjectDocument
     WHERE entity = pEntity
     ORDER BY label
     LIMIT pLimit
  LOOP
    arResult := array_append(arResult, row_to_json(r));
  END LOOP;

  RETURN array_to_json(arResult);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetForReportReferenceJson ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetForReportReferenceJson (
  pEntity   uuid,
  pLimit    integer DEFAULT 500
) RETURNS	json
AS $$
DECLARE
  r			record;
  arResult	json[];
BEGIN
  FOR r IN
    SELECT id AS value, name AS label
      FROM ObjectReference
     WHERE entity = pEntity
     ORDER BY name
     LIMIT pLimit
  LOOP
    arResult := array_append(arResult, row_to_json(r));
  END LOOP;

  RETURN array_to_json(arResult);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetForReportTypeJson --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetForReportTypeJson (
  pEntity   uuid,
  pLimit    integer DEFAULT 500
) RETURNS	json
AS $$
DECLARE
  r			record;
  arResult	json[];
BEGIN
  FOR r IN
    SELECT id AS value, name AS label
      FROM Type
     WHERE entity = pEntity
     ORDER BY name
     LIMIT pLimit
  LOOP
    arResult := array_append(arResult, row_to_json(r));
  END LOOP;

  RETURN array_to_json(arResult);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION ReportErrorHTML ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ReportErrorHTML (
  pCode 	integer,
  pMessage 	text,
  pContext 	text,
  pLocale   uuid DEFAULT current_locale()
) RETURNS 	text
AS $$
DECLARE
  l         record;
  vHTML     text;
BEGIN
  FOR l IN SELECT code FROM db.locale WHERE id = pLocale
  LOOP
	vHTML := E'<!DOCTYPE html>\n';

	vHTML := vHTML || format(E'<html lang="%s">\n', l.code);
	vHTML := vHTML || E'<head>\n';
	vHTML := vHTML || E'  <meta charset="UTF-8">\n';
	vHTML := vHTML || E'  <title>Familiarization</title>\n';
	vHTML := vHTML || E'</head>\n';

	vHTML := vHTML || E'<body>\n';
	vHTML := vHTML || E'<div>\n';

	vHTML := vHTML || E'  <pre>';
	vHTML := vHTML || format(E'Exception (%s): %s', pCode, pMessage) || E'\n\n';
	vHTML := vHTML || format(E'Context: %s', pContext);
	vHTML := vHTML || E'</pre>\n';

	vHTML := vHTML || E'</div>\n';
	vHTML := vHTML || E'</body>\n';
	vHTML := vHTML || E'</html>\n';
  END LOOP;

  RETURN vHTML;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
