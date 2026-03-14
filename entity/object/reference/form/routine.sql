--------------------------------------------------------------------------------
-- CreateForm ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new dynamic form definition and trigger the 'create' workflow method.
 * @param {uuid} pParent - Parent object or NULL
 * @param {uuid} pType - Type (must belong to 'form' entity)
 * @param {text} pCode - Unique business code
 * @param {text} pName - Display name
 * @param {text} pDescription - Optional description
 * @return {uuid} - ID of the created form
 * @throws IncorrectClassType - When pType does not belong to form entity
 * @see EditForm
 * @since 1.0.0
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
 * @brief Update an existing form definition (NULL params keep current values).
 * @param {uuid} pId - Form to update
 * @param {uuid} pParent - New parent (NULL keeps current)
 * @param {uuid} pType - New type (NULL keeps current)
 * @param {text} pCode - New code (NULL keeps current)
 * @param {text} pName - New name (NULL keeps current)
 * @param {text} pDescription - New description (NULL keeps current)
 * @return {void}
 * @see CreateForm
 * @since 1.0.0
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
/**
 * @brief Look up a form ID by its business code.
 * @param {text} pCode - Form code
 * @return {uuid} - Form ID or NULL
 * @since 1.0.0
 */
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
/**
 * @brief Assemble a form's field definitions into a JSON array, ordered by sequence.
 * @param {uuid} pForm - Form to build
 * @param {json} pParams - Runtime parameters (reserved for future use)
 * @return {json} - JSON array of field objects
 * @since 1.0.0
 */
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
