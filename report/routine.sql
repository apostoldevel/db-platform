--------------------------------------------------------------------------------
-- CreateReport ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateReport (
  pParent       uuid,
  pType         uuid,
  pTree         uuid,
  pForm         uuid,
  pBinding      uuid,
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

  INSERT INTO db.report (id, reference, tree, form, binding, info)
  VALUES (uReference, uReference, pTree, pForm, pBinding, pInfo);

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
  pBinding      uuid default null,
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
         binding = CheckNull(coalesce(pBinding, binding, null_uuid())),
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
-- InitReport ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION InitReport (
  pParent       uuid,
  pType         uuid,
  pTree         uuid,
  pCode         text,
  pName         text,
  pDescription  text
)
RETURNS     	uuid
AS $$
DECLARE
  uForm         uuid;
  uReport       uuid;
BEGIN
  uForm := CreateReportForm(pParent, GetType('json.report_form'), 'rfc_' || pCode, pName, 'rfc_' || pCode, pDescription);
  uReport := CreateReport(pParent, pType, pTree, uForm, null, pCode, pName, pDescription);
  PERFORM CreateReportRoutine(pParent, GetType('plpgsql.report_routine'), uReport, 'rpc_' || pCode, pName, 'rpc_' || pCode, pDescription);

  RETURN uReport;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- InitObjectReport ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION InitObjectReport (
  pParent       uuid,
  pTree         uuid,
  pForm         uuid,
  pBinding      uuid,
  pCode         text,
  pName         text,
  pDescription  text
)
RETURNS     	uuid
AS $$
DECLARE
  uReport       uuid;
BEGIN
  uReport := CreateReport(pParent, GetType('object.report'), pTree, pForm, pBinding, pCode, pName, pDescription);
  PERFORM CreateReportRoutine(pParent, GetType('plpgsql.report_routine'), uReport, 'rpc_' || pCode, pName, 'rpc_' || pCode, pDescription);

  RETURN uReport;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetForReportDocumentJson ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetForReportDocumentJson (
  pEntity   uuid,
  pClasses  uuid[] DEFAULT null,
  pLimit    integer DEFAULT 500
) RETURNS	json
AS $$
DECLARE
  r			record;
  arResult	json[];
BEGIN
  IF pClasses IS NULL THEN
	FOR r IN
	  SELECT id AS value, label
		FROM ObjectDocument
	   WHERE entity = pEntity
         AND statetype = '00000000-0000-4000-b001-000000000002'::uuid
	   ORDER BY label
	   LIMIT pLimit
	LOOP
	  arResult := array_append(arResult, row_to_json(r));
	END LOOP;
  ELSE
	FOR r IN
	  SELECT id AS value, label
		FROM ObjectDocument
	   WHERE entity = pEntity
	     AND class IN (SELECT unnest(pClasses))
         AND statetype = '00000000-0000-4000-b001-000000000002'::uuid
	   ORDER BY label
	   LIMIT pLimit
	LOOP
	  arResult := array_append(arResult, row_to_json(r));
	END LOOP;
  END IF;

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
  pClasses  uuid[] DEFAULT null,
  pLimit    integer DEFAULT 500
) RETURNS	json
AS $$
DECLARE
  r			record;
  arResult	json[];
BEGIN
  IF pClasses IS NULL THEN
	FOR r IN
	  SELECT id AS value, name AS label
		FROM ObjectReference
	   WHERE entity = pEntity
         AND statetype = '00000000-0000-4000-b001-000000000002'::uuid
	   ORDER BY name
	   LIMIT pLimit
	LOOP
	  arResult := array_append(arResult, row_to_json(r));
	END LOOP;
  ELSE
	FOR r IN
	  SELECT id AS value, label
		FROM ObjectReference
	   WHERE entity = pEntity
	     AND class IN (SELECT unnest(pClasses))
         AND statetype = '00000000-0000-4000-b001-000000000002'::uuid
	   ORDER BY label
	   LIMIT pLimit
	LOOP
	  arResult := array_append(arResult, row_to_json(r));
	END LOOP;
  END IF;

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
-- GetForReportStateJson -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetForReportStateJson (
  pClass    uuid,
  pLimit    integer DEFAULT 500
) RETURNS	json
AS $$
DECLARE
  r			record;
  arResult	json[];
BEGIN
  FOR r IN
    SELECT s.id AS value, st.label
      FROM db.state s INNER JOIN db.state_text st ON s.id = st.state AND st.locale = current_locale()
     WHERE s.class = pClass
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
