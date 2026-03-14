--------------------------------------------------------------------------------
-- CreateVersion ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new version record and trigger the 'create' workflow method.
 * @param {uuid} pParent - Parent object or NULL
 * @param {uuid} pType - Type (must belong to 'version' entity)
 * @param {text} pCode - Unique business code
 * @param {text} pName - Display name (version string)
 * @param {text} pDescription - Optional description
 * @return {uuid} - ID of the created version
 * @throws IncorrectClassType - When pType does not belong to version entity
 * @see EditVersion
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CreateVersion (
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

  IF GetEntityCode(uClass) <> 'version' THEN
    PERFORM IncorrectClassType();
  END IF;

  uReference := CreateReference(pParent, pType, pCode, pName, pDescription);

  INSERT INTO db.version (id, reference)
  VALUES (uReference, uReference);

  uMethod := GetMethod(uClass, GetAction('create'));
  PERFORM ExecuteMethod(uReference, uMethod);

  RETURN uReference;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditVersion -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update an existing version record (NULL params keep current values).
 * @param {uuid} pId - Version to update
 * @param {uuid} pParent - New parent (NULL keeps current)
 * @param {uuid} pType - New type (NULL keeps current)
 * @param {text} pCode - New code (NULL keeps current)
 * @param {text} pName - New name (NULL keeps current)
 * @param {text} pDescription - New description (NULL keeps current)
 * @return {void}
 * @see CreateVersion
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EditVersion (
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
-- FUNCTION GetVersion ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Look up a version ID by its business code.
 * @param {text} pCode - Version code
 * @return {uuid} - Version ID or NULL
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetVersion (
  pCode       text
) RETURNS     uuid
AS $$
BEGIN
  RETURN GetReference(pCode, 'version');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
