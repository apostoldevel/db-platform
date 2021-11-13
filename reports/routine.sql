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
  uReport := CreateReport(pParent, pType, pTree, uForm, pCode, pName, pDescription);
  PERFORM CreateReportRoutine(pParent, GetType('plpgsql.report_routine'), uReport, 'rpc_' || pCode, pName, 'rpc_' || pCode, pDescription);

  RETURN uReport;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- InitSyncReport --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION InitSyncReport (
  pParent       uuid,
  pTree         uuid,
  pCode         text,
  pName         text,
  pDescription  text
)
RETURNS     	uuid
AS $$
BEGIN
  RETURN InitReport(pParent, GetType('sync.report'), pTree, pCode, pName, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- InitAsyncReport -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION InitAsyncReport (
  pParent       uuid,
  pTree         uuid,
  pCode         text,
  pName         text,
  pDescription  text
)
RETURNS     	uuid
AS $$
BEGIN
  RETURN InitReport(pParent, GetType('async.report'), pTree, pCode, pName, pDescription);
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
