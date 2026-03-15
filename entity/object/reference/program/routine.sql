--------------------------------------------------------------------------------
-- CreateProgram ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new executable program and trigger the 'create' workflow method.
 * @param {uuid} pParent - Parent object or NULL
 * @param {uuid} pType - Type (must belong to 'program' entity)
 * @param {text} pCode - Unique business code
 * @param {text} pName - Display name
 * @param {text} pBody - SQL/PL/pgSQL source code to execute
 * @param {text} pDescription - Optional description
 * @return {uuid} - ID of the created program
 * @throws IncorrectClassType - When pType does not belong to program entity
 * @see EditProgram
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CreateProgram (
  pParent       uuid,
  pType         uuid,
  pCode         text,
  pName         text,
  pBody         text,
  pDescription  text default null
) RETURNS       uuid
AS $$
DECLARE
  uReference    uuid;
  uClass        uuid;
  uMethod       uuid;
BEGIN
  SELECT class INTO uClass FROM db.type WHERE id = pType;

  IF GetEntityCode(uClass) <> 'program' THEN
    PERFORM IncorrectClassType();
  END IF;

  uReference := CreateReference(pParent, pType, pCode, pName, pDescription);

  INSERT INTO db.program (reference, body)
  VALUES (uReference, pBody);

  uMethod := GetMethod(uClass, GetAction('create'));
  PERFORM ExecuteMethod(uReference, uMethod);

  RETURN uReference;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditProgram -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update an existing program (NULL params keep current values).
 * @param {uuid} pId - Program to update
 * @param {uuid} pParent - New parent (NULL keeps current)
 * @param {uuid} pType - New type (NULL keeps current)
 * @param {text} pCode - New code (NULL keeps current)
 * @param {text} pName - New name (NULL keeps current)
 * @param {text} pBody - New source code (NULL keeps current)
 * @param {text} pDescription - New description (NULL keeps current)
 * @return {void}
 * @see CreateProgram
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EditProgram (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pCode         text default null,
  pName         text default null,
  pBody         text default null,
  pDescription  text default null
) RETURNS       void
AS $$
DECLARE
  uClass        uuid;
  uMethod       uuid;
BEGIN
  PERFORM EditReference(pId, pParent, pType, pCode, pName, pDescription, current_locale());

  UPDATE db.program
     SET body = coalesce(pBody, body)
   WHERE id = pId;

  SELECT class INTO uClass FROM db.object WHERE id = pId;

  uMethod := GetMethod(uClass, GetAction('edit'));
  PERFORM ExecuteMethod(pId, uMethod);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetProgram ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Look up a program ID by its business code.
 * @param {text} pCode - Program code
 * @return {uuid} - Program ID or NULL
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetProgram (
  pCode        text
) RETURNS     uuid
AS $$
BEGIN
  RETURN GetReference(pCode, 'program');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetProgramBody -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the SQL source body of a program.
 * @param {uuid} pId - Program ID
 * @return {text} - Source code body
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetProgramBody (
  pId       uuid
) RETURNS     text
AS $$
  SELECT body FROM db.program WHERE id = pId;
$$ LANGUAGE SQL STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
