--------------------------------------------------------------------------------
-- CreateVendor ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new vendor record and trigger the 'create' workflow method.
 * @param {uuid} pParent - Parent object or NULL
 * @param {uuid} pType - Type (must belong to 'vendor' entity)
 * @param {text} pCode - Unique business code
 * @param {text} pName - Display name
 * @param {text} pDescription - Optional description
 * @return {uuid} - ID of the created vendor
 * @throws IncorrectClassType - When pType does not belong to vendor entity
 * @see EditVendor
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CreateVendor (
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

  IF GetEntityCode(uClass) <> 'vendor' THEN
    PERFORM IncorrectClassType();
  END IF;

  uReference := CreateReference(pParent, pType, pCode, pName, pDescription);

  INSERT INTO db.vendor (id, reference)
  VALUES (uReference, uReference);

  uMethod := GetMethod(uClass, GetAction('create'));
  PERFORM ExecuteMethod(uReference, uMethod);

  RETURN uReference;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditVendor ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update an existing vendor (NULL params keep current values).
 * @param {uuid} pId - Vendor to update
 * @param {uuid} pParent - New parent (NULL keeps current)
 * @param {uuid} pType - New type (NULL keeps current)
 * @param {text} pCode - New code (NULL keeps current)
 * @param {text} pName - New name (NULL keeps current)
 * @param {text} pDescription - New description (NULL keeps current)
 * @return {void}
 * @see CreateVendor
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EditVendor (
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
-- FUNCTION GetVendor ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Look up a vendor ID by its business code.
 * @param {text} pCode - Vendor code
 * @return {uuid} - Vendor ID or NULL
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetVendor (
  pCode       text
) RETURNS     uuid
AS $$
BEGIN
  RETURN GetReference(pCode, 'vendor');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
