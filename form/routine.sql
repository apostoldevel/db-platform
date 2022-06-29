--------------------------------------------------------------------------------
-- NewFormText -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION NewFormText (
  pForm         uuid,
  pName         text,
  pDescription  text DEFAULT null,
  pLocale		uuid DEFAULT current_locale()
) RETURNS       void
AS $$
BEGIN
  INSERT INTO db.form_text (form, locale, name, description)
  VALUES (pForm, pLocale, pName, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditFormText ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditFormText (
  pForm         uuid,
  pName         text,
  pDescription  text DEFAULT null,
  pLocale		uuid DEFAULT null
) RETURNS       void
AS $$
BEGIN
  UPDATE db.form_text
     SET name = CheckNull(coalesce(pName, name, '')),
         description = CheckNull(coalesce(pDescription, description, ''))
   WHERE form = pForm AND locale = pLocale;

  IF NOT FOUND THEN
    PERFORM NewFormText(pForm, pName, pDescription, pLocale);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateForm ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateForm (
  pId           uuid,
  pEntity       uuid,
  pCode         text,
  pName         text,
  pDescription  text DEFAULT null,
  pLocale		uuid DEFAULT null
) RETURNS       uuid
AS $$
DECLARE
  l				record;

  uForm         uuid;
BEGIN
  INSERT INTO db.form (id, entity, code)
  VALUES (coalesce(pId, gen_kernel_uuid('8')), pEntity, pCode)
  RETURNING id INTO uForm;

  IF pLocale IS NULL THEN
	FOR l IN SELECT id FROM db.locale
	LOOP
	  PERFORM NewFormText(uForm, pName, pDescription, l.id);
	END LOOP;
  ELSE
    PERFORM NewFormText(uForm, pName, pDescription, pLocale);
  END IF;

  RETURN uForm;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditForm --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditForm (
  pId           uuid,
  pEntity       uuid DEFAULT null,
  pCode         text DEFAULT null,
  pName         text DEFAULT null,
  pDescription  text DEFAULT null,
  pLocale		uuid DEFAULT null
) RETURNS       void
AS $$
DECLARE
  l				record;
BEGIN
  UPDATE db.form
     SET entity = coalesce(pEntity, entity),
         code = coalesce(pCode, code)
   WHERE id = pId;

  IF pLocale IS NULL THEN
	FOR l IN SELECT id FROM db.locale
	LOOP
	  PERFORM EditFormText(pId, pName, pDescription, l.id);
	END LOOP;
  ELSE
    PERFORM EditFormText(pId, pName, pDescription, pLocale);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetForm ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetForm (
  pEntity       uuid,
  pCode         text
) RETURNS       uuid
AS $$
  SELECT id FROM db.form WHERE entity = pEntity AND code = pCode;
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetFormCode --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetFormCode (
  pId           uuid
) RETURNS       text
AS $$
  SELECT code FROM db.form WHERE id = pId;
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetFormName --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetFormName (
  pId           uuid,
  pLocale		uuid DEFAULT current_locale()
) RETURNS       text
AS $$
  SELECT name FROM db.form_text WHERE form = pId AND locale = pLocale;
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION BuildForm ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION BuildForm (
  pForm     uuid,
  pParams   json
) RETURNS 	json
AS $$
DECLARE
  r         record;
  arResult	json[];
BEGIN
  FOR r IN SELECT key, type, label, format, value, data, mutable FROM db.form_field WHERE form = pForm AND locale = current_locale() ORDER BY sequence
  LOOP
    arResult := array_append(arResult, row_to_json(r));
  END LOOP;

  RETURN array_to_json(arResult);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
