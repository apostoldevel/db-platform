--------------------------------------------------------------------------------
-- REGISTRY --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.registry
AS
  SELECT * FROM Registry;

GRANT SELECT ON api.registry TO administrator;

--------------------------------------------------------------------------------
/**
 * @brief Filter registry entries by identifier, root key, and/or subkey.
 * @param {uuid} pId - Entry identifier filter (NULL = any)
 * @param {uuid} pKey - Root key identifier filter (NULL = any)
 * @param {uuid} pSubKey - Subkey identifier filter (NULL = any)
 * @return {SETOF api.registry} - Matching registry entries with Variant values
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.registry (
  pId        uuid,
  pKey       uuid,
  pSubKey    uuid
) RETURNS    SETOF api.registry
AS $$
  SELECT *
    FROM api.registry
   WHERE id = coalesce(pId, id)
     AND key = coalesce(pKey, key)
     AND subkey = coalesce(pSubKey, subkey)
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.registry_ex
AS
  SELECT * FROM RegistryEx;

GRANT SELECT ON api.registry_ex TO administrator;

--------------------------------------------------------------------------------
/**
 * @brief Filter extended registry entries by identifier, root key, and/or subkey.
 * @param {uuid} pId - Entry identifier filter (NULL = any)
 * @param {uuid} pKey - Root key identifier filter (NULL = any)
 * @param {uuid} pSubKey - Subkey identifier filter (NULL = any)
 * @return {SETOF api.registry_ex} - Matching entries with raw typed columns
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.registry_ex (
  pId        uuid,
  pKey       uuid,
  pSubKey    uuid
) RETURNS    SETOF api.registry_ex
AS $$
  SELECT *
    FROM api.registry_ex
   WHERE id = coalesce(pId, id)
     AND key = coalesce(pKey, key)
     AND subkey = coalesce(pSubKey, subkey)
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.registry_key
AS
  SELECT * FROM RegistryKey;

GRANT SELECT ON api.registry_key TO administrator;

--------------------------------------------------------------------------------
/**
 * @brief Filter registry keys by identifier, root, parent, and/or key name.
 * @param {uuid} pId - Key identifier filter (NULL = any)
 * @param {uuid} pRoot - Root key identifier filter (NULL = any)
 * @param {uuid} pParent - Parent key identifier filter (NULL = any)
 * @param {text} pKey - Key name segment filter (NULL = any)
 * @return {SETOF api.registry_key} - Matching registry key rows
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.registry_key (
  pId        uuid,
  pRoot      uuid,
  pParent    uuid,
  pKey       text
) RETURNS    SETOF api.registry_key
AS $$
  SELECT *
    FROM api.registry_key
   WHERE id = coalesce(pId, id)
     AND root = coalesce(pRoot, root)
     AND parent = coalesce(pParent, parent)
     AND key = coalesce(pKey, key)
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.registry_value
AS
  SELECT * FROM RegistryValue;

GRANT SELECT ON api.registry_value TO administrator;

--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.registry_value_ex
AS
  SELECT * FROM RegistryValueEx;

GRANT SELECT ON api.registry_value_ex TO administrator;

--------------------------------------------------------------------------------
/**
 * @brief Filter registry values by identifier and/or parent key.
 * @param {uuid} pId - Value identifier filter (NULL = any)
 * @param {uuid} pKey - Root key identifier filter (NULL = any)
 * @return {SETOF api.registry_value} - Matching value entries with Variant data
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.registry_value (
  pId        uuid,
  pKey       uuid
) RETURNS    SETOF api.registry_value
AS $$
  SELECT *
    FROM api.registry_value
   WHERE id = coalesce(pId, id)
     AND key = coalesce(pKey, key)
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
/**
 * @brief Filter extended registry values by identifier and/or parent key.
 * @param {uuid} pId - Value identifier filter (NULL = any)
 * @param {uuid} pKey - Root key identifier filter (NULL = any)
 * @return {SETOF api.registry_value_ex} - Matching values with raw typed columns
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.registry_value_ex (
  pId        uuid,
  pKey       uuid
) RETURNS    SETOF api.registry_value_ex
AS $$
  SELECT *
    FROM api.registry_value_ex
   WHERE id = coalesce(pId, id)
     AND key = coalesce(pKey, key)
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
/**
 * @brief Resolve the full backslash-delimited path for a registry key identifier.
 * @param {uuid} pKey - Registry key identifier
 * @return {text} - Full key path (e.g. 'Settings\Locale')
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.registry_get_reg_key (
  pKey      uuid
) RETURNS   text
AS $$
BEGIN
  RETURN registry.get_reg_key(pKey);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.registry_enum_key -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Enumerate child subkeys for the specified key/subkey pair.
 * @param {text} pKey - Root key alias: 'CURRENT_CONFIG' or 'CURRENT_USER'
 * @param {text} pSubKey - Backslash-delimited subkey path (must not start or end with '\')
 * @return {TABLE(id uuid, key text, subkey text)} - Child subkey identifiers and their full paths
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.registry_enum_key (
  pKey      text,
  pSubKey   text
) RETURNS TABLE (
  id        uuid,
  key       text,
  subkey    text
)
AS $$
  SELECT R.id, pKey, registry.get_reg_key(R.id) FROM RegEnumKey(RegOpenKey(pKey, pSubKey)) AS R;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.registry_enum_value -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Enumerate all values for the specified key/subkey pair, returning Variant data.
 * @param {text} pKey - Root key alias: 'CURRENT_CONFIG' or 'CURRENT_USER'
 * @param {text} pSubKey - Backslash-delimited subkey path (must not start or end with '\')
 * @return {TABLE(id uuid, key text, subkey text, valuename text, value variant)} - Value names and their typed data
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.registry_enum_value (
  pKey      text,
  pSubKey   text
) RETURNS TABLE (
  id        uuid,
  key       text,
  subkey    text,
  valuename text,
  value     variant
)
AS $$
  SELECT R.id, pKey, pSubKey, R.vname, registry.get_reg_value(R.id) FROM RegEnumValue(RegOpenKey(pKey, pSubKey)) AS R;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.registry_enum_value_ex --------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Enumerate all values for the specified key/subkey pair with raw typed columns.
 * @param {text} pKey - Root key alias: 'CURRENT_CONFIG' or 'CURRENT_USER'
 * @param {text} pSubKey - Backslash-delimited subkey path (must not start or end with '\')
 * @return {TABLE} - Value names with individual typed payload columns (vinteger, vnumeric, vdatetime, vstring, vboolean)
 * @see api.registry_enum_value
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.registry_enum_value_ex (
  pKey        text,
  pSubKey     text
) RETURNS TABLE (
  id          uuid,
  key         text,
  subkey      text,
  valuename   text,
  vtype       integer,
  vinteger    integer,
  vnumeric    numeric,
  vdatetime   timestamp,
  vstring     text,
  vboolean    boolean
)
AS $$
  SELECT R.id, pKey, pSubKey, R.vname, R.vtype, R.vinteger, R.vnumeric, R.vdatetime, R.vstring, R.vboolean FROM RegEnumValueEx(RegOpenKey(pKey, pSubKey)) AS R;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.registry_write ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Write a typed value to the registry, creating the key path if needed.
 * @param {uuid} pId - Existing value identifier for direct update (NULL to resolve by key/subkey)
 * @param {text} pKey - Root key alias: 'CURRENT_CONFIG' or 'CURRENT_USER'
 * @param {text} pSubKey - Backslash-delimited subkey path (must not start or end with '\')
 * @param {text} pValueName - Name of the value to set; created if it does not exist
 * @param {integer} pType - Data type: 0=integer, 1=numeric, 2=datetime, 3=text, 4=boolean
 * @param {anynonarray} pData - Data to store under the specified value name
 * @return {uuid} - Identifier of the created or updated value row
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.registry_write (
  pId         uuid,
  pKey        text,
  pSubKey     text,
  pValueName  text,
  pType       integer,
  pData       anynonarray
) RETURNS     uuid
AS $$
DECLARE
  vData       Variant;
BEGIN
  vData.vType := pType;

  CASE pType
  WHEN 0 THEN vData.vInteger := pData;
  WHEN 1 THEN vData.vNumeric := pData;
  WHEN 2 THEN vData.vDateTime := pData;
  WHEN 3 THEN vData.vString := pData;
  WHEN 4 THEN vData.vBoolean := pData;
  END CASE;

  RETURN RegSetValue(coalesce(pId, RegCreateKey(pKey, pSubKey)), pValueName, vData);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.registry_read -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Read a named value from the registry as a Variant composite.
 * @param {text} pKey - Root key alias: 'CURRENT_CONFIG' or 'CURRENT_USER'
 * @param {text} pSubKey - Backslash-delimited subkey path (must not start or end with '\')
 * @param {text} pValueName - Name of the value to read
 * @return {Variant} - Typed composite value, or NULL if not found
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.registry_read (
  pKey          text,
  pSubKey       text,
  pValueName    text
) RETURNS       Variant
AS $$
BEGIN
  RETURN RegGetValue(RegOpenKey(pKey, pSubKey), pValueName);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.registry_delete_key -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Delete a registry subkey and its values; raise an exception if the subkey is not found.
 * @param {text} pKey - Root key alias: 'CURRENT_CONFIG' or 'CURRENT_USER'
 * @param {text} pSubKey - Backslash-delimited subkey path (must not start or end with '\')
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.registry_delete_key (
  pKey      text,
  pSubKey   text
) RETURNS   void
AS $$
BEGIN
  IF NOT RegDeleteKey(pKey, pSubKey) THEN
    RAISE EXCEPTION '%', GetErrorMessage();
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.registry_delete_value ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Delete a registry value by identifier or by key/subkey/name; raise an exception on failure.
 * @param {uuid} pId - Value identifier for direct deletion (NULL to resolve by key/subkey/name)
 * @param {text} pKey - Root key alias: 'CURRENT_CONFIG' or 'CURRENT_USER'
 * @param {text} pSubKey - Backslash-delimited subkey path (must not start or end with '\')
 * @param {text} pValueName - Name of the value to delete
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.registry_delete_value (
  pId           uuid,
  pKey          text,
  pSubKey       text,
  pValueName    text
) RETURNS       void
AS $$
BEGIN
  IF pId IS NOT NULL THEN
    PERFORM DelRegKeyValue(pId);
  ELSE
    IF NOT RegDeleteKeyValue(pKey, pSubKey, pValueName) THEN
      RAISE EXCEPTION '%', GetErrorMessage();
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.registry_delete_tree ----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Recursively delete a subkey, all its descendants, and their values; raise an exception on failure.
 * @param {text} pKey - Root key alias: 'CURRENT_CONFIG' or 'CURRENT_USER'
 * @param {text} pSubKey - Backslash-delimited subkey path (must not start or end with '\')
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION api.registry_delete_tree (
  pKey      text,
  pSubKey   text
) RETURNS   void
AS $$
BEGIN
  IF NOT RegDeleteTree(pKey, pSubKey) THEN
    RAISE EXCEPTION '%', GetErrorMessage();
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
