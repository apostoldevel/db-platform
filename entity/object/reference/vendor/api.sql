--------------------------------------------------------------------------------
-- VENDOR ----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.vendor ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.vendor
AS
  SELECT * FROM ObjectVendor;

GRANT SELECT ON api.vendor TO administrator;

--------------------------------------------------------------------------------
-- api.add_vendor --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a new vendor via the API (defaults to 'device.vendor' type).
 * @param {uuid} pParent - Parent object or NULL
 * @param {uuid} pType - Vendor type (NULL = device.vendor)
 * @param {text} pCode - Unique business code
 * @param {text} pName - Display name
 * @param {text} pDescription - Optional description
 * @return {uuid} - ID of the created vendor
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.add_vendor (
  pParent       uuid,
  pType         uuid,
  pCode         text,
  pName         text,
  pDescription  text default null
) RETURNS       uuid
AS $$
BEGIN
  RETURN CreateVendor(pParent, coalesce(pType, GetType('device.vendor')), pCode, pName, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.update_vendor -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Update an existing vendor via the API.
 * @param {uuid} pId - Vendor to update
 * @param {uuid} pParent - New parent (NULL keeps current)
 * @param {uuid} pType - New type (NULL keeps current)
 * @param {text} pCode - New code (NULL keeps current)
 * @param {text} pName - New name (NULL keeps current)
 * @param {text} pDescription - New description (NULL keeps current)
 * @return {void}
 * @throws ObjectNotFound - When vendor with given ID does not exist
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.update_vendor (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pCode         text default null,
  pName         text default null,
  pDescription  text default null
) RETURNS       void
AS $$
DECLARE
  uVendor       uuid;
BEGIN
  SELECT t.id INTO uVendor FROM db.vendor t WHERE t.id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('vendor', 'id', pId);
  END IF;

  PERFORM EditVendor(uVendor, pParent, pType, pCode, pName, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.set_vendor --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Upsert a vendor: create when pId is NULL, otherwise update. Return the row.
 * @param {uuid} pId - Vendor ID (NULL = create new)
 * @param {uuid} pParent - Parent object or NULL
 * @param {uuid} pType - Vendor type
 * @param {text} pCode - Business code
 * @param {text} pName - Display name
 * @param {text} pDescription - Optional description
 * @return {SETOF api.vendor} - The created or updated vendor row
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.set_vendor (
  pId           uuid,
  pParent       uuid default null,
  pType         uuid default null,
  pCode         text default null,
  pName         text default null,
  pDescription  text default null
) RETURNS       SETOF api.vendor
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_vendor(pParent, pType, pCode, pName, pDescription);
  ELSE
    PERFORM api.update_vendor(pId, pParent, pType, pCode, pName, pDescription);
  END IF;

  RETURN QUERY SELECT * FROM api.vendor WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_vendor --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve a single vendor by ID (with access check).
 * @param {uuid} pId - Vendor ID
 * @return {SETOF api.vendor} - Matching row or empty set
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_vendor (
  pId       uuid
) RETURNS   SETOF api.vendor
AS $$
  SELECT * FROM api.vendor WHERE id = pId AND CheckObjectAccess(id, B'100')
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_vendor -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief List vendors with optional search, filter, and pagination.
 * @param {jsonb} pSearch - Search conditions array
 * @param {jsonb} pFilter - Exact-match filter object
 * @param {integer} pLimit - Maximum rows to return
 * @param {integer} pOffSet - Rows to skip
 * @param {jsonb} pOrderBy - Sort fields array
 * @return {SETOF api.vendor} - Matching rows
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.list_vendor (
  pSearch   jsonb default null,
  pFilter   jsonb default null,
  pLimit    integer default null,
  pOffSet   integer default null,
  pOrderBy  jsonb default null
) RETURNS   SETOF api.vendor
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'vendor', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_vendor_id -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Resolve a vendor ID from a code or UUID string.
 * @param {text} pCode - Vendor code or UUID
 * @return {uuid} - Vendor ID
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.get_vendor_id (
  pCode     text
) RETURNS   uuid
AS $$
BEGIN
  IF length(pCode) = 36 AND SubStr(pCode, 15, 1) = '4' THEN
    RETURN pCode;
  END IF;

  RETURN GetVendor(pCode);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
