--------------------------------------------------------------------------------
-- CreateForm ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт форму
 * @param {uuid} pParent - Идентификатор объекта родителя
 * @param {uuid} pType - Идентификатор типа
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {text} pDescription - Описание
 * @return {uuid}
 */
CREATE OR REPLACE FUNCTION CreateForm (
  pParent       uuid,
  pType         uuid,
  pCode         text,
  pName         text,
  pDescription  text default null
) RETURNS       uuid
AS $$
DECLARE
  uReference    uuid;
  uClass        uuid;
  uMethod       uuid;
BEGIN
  SELECT class INTO uClass FROM db.type WHERE id = pType;

  IF GetEntityCode(uClass) <> 'form' THEN
    PERFORM IncorrectClassType();
  END IF;

  uReference := CreateReference(pParent, pType, pCode, pName, pDescription);

  INSERT INTO db.form (id, reference)
  VALUES (uReference, uReference);

  uMethod := GetMethod(uClass, GetAction('create'));
  PERFORM ExecuteMethod(uReference, uMethod);

  RETURN uReference;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditForm --------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Редактирует форму
 * @param {uuid} pId - Идентификатор
 * @param {uuid} pParent - Идентификатор объекта родителя
 * @param {uuid} pType - Идентификатор типа
 * @param {text} pCode - Код
 * @param {text} pName - Наименование
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION EditForm (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pCode         text default null,
  pName         text default null,
  pDescription  text default null
) RETURNS       void
AS $$
DECLARE
  uClass        uuid;
  uMethod       uuid;
BEGIN
  PERFORM EditReference(pId, pParent, pType, pCode, pName, pDescription, current_locale());

  SELECT class INTO uClass FROM db.object WHERE id = pId;

  uMethod := GetMethod(uClass, GetAction('edit'));
  PERFORM ExecuteMethod(pId, uMethod);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetForm ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetForm (
  pCode       text
) RETURNS     uuid
AS $$
BEGIN
  RETURN GetReference(pCode, 'form');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION BuildForm ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION BuildForm (
  pForm     uuid,
  pParams   json
) RETURNS   json
AS $$
DECLARE
  r         record;
  arResult  json[];
BEGIN
  FOR r IN SELECT key, type, label, format, value, data, mutable FROM db.form_field WHERE form = pForm ORDER BY sequence
  LOOP
    arResult := array_append(arResult, row_to_json(r));
  END LOOP;

  RETURN array_to_json(arResult);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
