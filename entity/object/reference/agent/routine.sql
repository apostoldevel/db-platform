--------------------------------------------------------------------------------
-- CreateAgent -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new delivery agent and trigger the 'create' workflow method.
 * @param {uuid} pParent - Parent object or NULL
 * @param {uuid} pType - Type (must belong to 'agent' entity)
 * @param {uuid} pVendor - Vendor that provides this agent
 * @param {text} pCode - Unique business code
 * @param {text} pName - Display name
 * @param {text} pDescription - Optional description
 * @return {uuid} - ID of the created agent
 * @throws IncorrectClassType - When pType does not belong to agent entity
 * @see EditAgent
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION CreateAgent (
  pParent       uuid,
  pType         uuid,
  pVendor       uuid,
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

  IF GetEntityCode(uClass) <> 'agent' THEN
    PERFORM IncorrectClassType();
  END IF;

  uReference := CreateReference(pParent, pType, pCode, pName, pDescription);

  INSERT INTO db.agent (id, reference, vendor)
  VALUES (uReference, uReference, pVendor);

  uMethod := GetMethod(uClass, GetAction('create'));
  PERFORM ExecuteMethod(uReference, uMethod);

  RETURN uReference;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditAgent -------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update an existing delivery agent (NULL params keep current values).
 * @param {uuid} pId - Agent to update
 * @param {uuid} pParent - New parent (NULL keeps current)
 * @param {uuid} pType - New type (NULL keeps current)
 * @param {uuid} pVendor - New vendor (NULL keeps current)
 * @param {text} pCode - New code (NULL keeps current)
 * @param {text} pName - New name (NULL keeps current)
 * @param {text} pDescription - New description (NULL keeps current)
 * @return {void}
 * @see CreateAgent
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION EditAgent (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pVendor       uuid default null,
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

  UPDATE db.agent
     SET vendor = coalesce(pVendor, vendor)
   WHERE id = pId;

  SELECT class INTO uClass FROM db.object WHERE id = pId;

  uMethod := GetMethod(uClass, GetAction('edit'));
  PERFORM ExecuteMethod(pId, uMethod);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetAgent -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Look up an agent ID by its business code.
 * @param {text} pCode - Agent code
 * @return {uuid} - Agent ID or NULL
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetAgent (
  pCode       text
) RETURNS     uuid
AS $$
BEGIN
  RETURN GetReference(pCode, 'agent');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   STABLE STRICT
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetAgentCode -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the business code of an agent.
 * @param {uuid} pId - Agent ID
 * @return {text} - Agent code
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetAgentCode (
  pId        uuid
) RETURNS    text
AS $$
BEGIN
  RETURN GetReferenceCode(pId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   STABLE STRICT
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetAgentVendor -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the vendor ID assigned to an agent.
 * @param {uuid} pId - Agent ID
 * @return {uuid} - Vendor ID
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetAgentVendor (
  pId       uuid
) RETURNS   uuid
AS $$
  SELECT vendor FROM db.agent WHERE id = pId;
$$ LANGUAGE SQL STABLE STRICT
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
