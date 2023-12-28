--------------------------------------------------------------------------------
-- FUNCTION SetFormFieldSequence -----------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetFormFieldSequence (
  pForm     uuid,
  pKey      text,
  pSequence integer,
  pDelta    integer
) RETURNS   void
AS $$
DECLARE
  vKey      text;
BEGIN
  IF pDelta <> 0 THEN
    SELECT key INTO vKey
      FROM db.form_field
     WHERE form = pForm
       AND key <> pKey
       AND sequence = pSequence;

    IF FOUND THEN
      PERFORM SetFormFieldSequence(pForm, vKey, pSequence + pDelta, pDelta);
    END IF;
  END IF;

  UPDATE db.form_field SET sequence = pSequence WHERE form = pForm AND key = pKey;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateFormField -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateFormField (
  pForm         uuid,
  pKey          text,
  pType         text,
  pLabel        text,
  pFormat       text default null,
  pValue        text default null,
  pData         jsonb default null,
  pMutable      boolean default null,
  pSequence     integer default null
) RETURNS       void
AS $$
BEGIN
  IF NULLIF(pSequence, 0) IS NULL THEN
    SELECT max(sequence) + 1 INTO pSequence FROM db.form_field WHERE form IS NOT DISTINCT FROM pForm;
  ELSE
    PERFORM SetFormFieldSequence(pForm, pKey, pSequence, 1);
  END IF;

  INSERT INTO db.form_field (form, key, type, label, format, value, data, mutable, sequence)
  VALUES (pForm, pKey, pType, pLabel, pFormat, pValue, pData, pMutable, coalesce(pSequence, 1));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditFormField ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditFormField (
  pForm         uuid,
  pKey          text,
  pType         text default null,
  pLabel        text default null,
  pFormat       text default null,
  pValue        text default null,
  pData         jsonb default null,
  pMutable      boolean default null,
  pSequence     integer default null
) RETURNS       void
AS $$
DECLARE
  nSequence     integer;
BEGIN
  SELECT sequence INTO nSequence FROM db.form_field WHERE form = pForm AND key = pKey;

  pSequence := coalesce(NULLIF(pSequence, 0), nSequence);

  UPDATE db.form_field
     SET type = coalesce(pType, type),
         label = coalesce(pLabel, label),
         format = CheckNull(coalesce(pFormat, format, '')),
         value = CheckNull(coalesce(pValue, value, '')),
         data = CheckNull(coalesce(pData, data, jsonb_build_object())),
         mutable = coalesce(pMutable, mutable),
         sequence = pSequence
   WHERE form = pForm AND key = pKey;

  IF pSequence < nSequence THEN
    PERFORM SetFormFieldSequence(pForm, pKey, pSequence, 1);
  END IF;

  IF pSequence > nSequence THEN
    PERFORM SetFormFieldSequence(pForm, pKey, pSequence, -1);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SetFormField ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetFormField (
  pForm         uuid,
  pKey          text,
  pType         text default null,
  pLabel        text default null,
  pFormat       text default null,
  pValue        text default null,
  pData         jsonb default null,
  pMutable      boolean default null,
  pSequence     integer default null
) RETURNS       void
AS $$
DECLARE
  uMethod       uuid;
BEGIN
  PERFORM FROM db.form_field WHERE form = pForm AND key = pKey;

  IF FOUND THEN
    PERFORM EditFormField(pForm, pKey, pType, pLabel, pFormat, pValue, pData, pMutable, pSequence);
  ELSE
    PERFORM CreateFormField(pForm, pKey, pType, pLabel, pFormat, pValue, pData, pMutable, pSequence);
  END IF;

  uMethod := GetMethod(GetObjectClass(pForm), GetAction('edit'));
  PERFORM ExecuteMethod(pForm, uMethod);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteFormField -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteFormField (
  pForm         uuid,
  pKey          text
) RETURNS       boolean
AS $$
DECLARE
  uMethod       uuid;
BEGIN
  IF pKey IS NULL THEN
    DELETE FROM db.form_field WHERE form = pForm;
  ELSE
    DELETE FROM db.form_field WHERE form = pForm AND key = pKey;
  END IF;

  IF FOUND THEN
    uMethod := GetMethod(GetObjectClass(pForm), GetAction('edit'));
    PERFORM ExecuteMethod(pForm, uMethod);

    RETURN true;
  END IF;

  RETURN false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetFormFieldJson ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetFormFieldJson (
  pForm     uuid
) RETURNS   json
AS $$
DECLARE
  r            record;
  arResult    json[];
BEGIN
  FOR r IN
    SELECT *
      FROM FormField
     WHERE form = pForm
     ORDER BY sequence
  LOOP
    arResult := array_append(arResult, row_to_json(r));
  END LOOP;

  RETURN array_to_json(arResult);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
