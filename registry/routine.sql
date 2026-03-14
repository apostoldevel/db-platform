--------------------------------------------------------------------------------
-- FUNCTION reg_key_to_array ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Split a backslash-delimited registry path into an array of key segments.
 * @param {text} pKey - Full registry subkey path (e.g. 'Settings\Locale\Language')
 * @return {text[]} - Array of individual key name segments
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION registry.reg_key_to_array (
  pKey        text
) RETURNS     text[]
AS $$
DECLARE
  i           integer;
  arKey       text[];
  vStr        text;
  vKey        text;
BEGIN
  vKey := pKey;

  IF NULLIF(vKey, '') IS NOT NULL THEN

    i := StrPos(vKey, E'\u005C');
    WHILE i > 0 LOOP
      vStr := SubStr(vKey, 1, i - 1);

      IF NULLIF(vStr, '') IS NOT NULL THEN
        arKey := array_append(arKey, vStr);
      END IF;

      vKey := SubStr(vKey, i + 1);
      i := StrPos(vKey, E'\u005C');
    END LOOP;

    IF NULLIF(vKey, '') IS NOT NULL THEN
      arKey := array_append(arKey, vKey);
    END IF;
  END IF;

  RETURN arKey;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION get_reg_key --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Reconstruct the full backslash-delimited path for a registry key by walking up the tree.
 * @param {uuid} pId - Registry key identifier to resolve
 * @return {text} - Full key path (e.g. 'Settings\Locale\Language')
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION registry.get_reg_key (
  pId        uuid
) RETURNS    text
AS $$
DECLARE
  vKey       text;
  r          record;
BEGIN
  FOR r IN
    WITH RECURSIVE keytree(id, parent, key) AS (
      SELECT id, parent, key FROM registry.key WHERE id = pId
    UNION ALL
      SELECT k.id, k.parent, k.key
        FROM registry.key k INNER JOIN keytree kt ON k.id = kt.parent
       WHERE k.root IS NOT NULL
    )
    SELECT key FROM keytree
  LOOP
    IF vKey IS NULL THEN
      vKey := r.key;
    ELSE
     vKey := r.key || E'\u005C' || vKey;
    END IF;
  END LOOP;

  RETURN vKey;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- get_reg_value ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the typed Variant value for a registry value row by its identifier.
 * @param {uuid} pId - Registry value identifier
 * @return {Variant} - Composite (vtype, vinteger, vnumeric, vdatetime, vstring, vboolean)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION registry.get_reg_value (
  pId        uuid
) RETURNS    Variant
AS $$
  SELECT vtype, vinteger, vnumeric, vdatetime, vstring, vboolean
    FROM registry.value
   WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RegEnumKey ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Enumerate immediate child keys of the given parent key.
 * @param {uuid} pId - Parent registry key identifier
 * @return {SETOF registry.key} - Set of child key rows
 * @see RegEnumValue
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION RegEnumKey (
  pId        uuid
) RETURNS    SETOF registry.key
AS $$
  SELECT * FROM registry.key WHERE parent = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RegEnumValue ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Enumerate all values attached to a registry key, returning Variant data.
 * @param {uuid} pKey - Registry key identifier whose values to list
 * @return {SETOF record} - (id, key, vname, value::Variant) for each value
 * @see RegEnumValueEx, RegEnumKey
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION RegEnumValue (
  pKey       uuid,
  OUT id     uuid,
  OUT key    uuid,
  OUT vname  text,
  OUT value  Variant
) RETURNS    SETOF record
AS $$
  SELECT v.id, v.key, v.vname, registry.get_reg_value(v.id) FROM registry.value v WHERE v.key = pKey
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RegEnumValueEx --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Enumerate all values attached to a registry key with raw typed columns.
 * @param {uuid} pKey - Registry key identifier whose values to list
 * @return {SETOF registry.value} - Full value rows including all typed payload columns
 * @see RegEnumValue
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION RegEnumValueEx (
  pKey       uuid
) RETURNS    SETOF registry.value
AS $$
  SELECT * FROM registry.value WHERE key = pKey
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RegQueryValue ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Look up a single registry value as a Variant by value identifier.
 * @param {uuid} pId - Registry value identifier
 * @return {Variant} - Typed composite value
 * @see RegQueryValueEx
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION RegQueryValue (
  pId        uuid
) RETURNS    Variant
AS $$
  SELECT registry.get_reg_value(id) FROM registry.value WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RegQueryValueEx -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the full registry value row by its identifier.
 * @param {uuid} pId - Registry value identifier
 * @return {registry.value} - Complete value row with all typed columns
 * @see RegQueryValue
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION RegQueryValueEx (
  pId        uuid
) RETURNS    registry.value
AS $$
  SELECT * FROM registry.value WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RegGetValue -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Look up a named value under a registry key and return it as a Variant.
 * @param {uuid} pKey - Registry key identifier
 * @param {text} pValueName - Name of the value to retrieve
 * @return {Variant} - Typed composite value, or NULL if not found
 * @see RegGetValueEx
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION RegGetValue (
  pKey          uuid,
  pValueName    text
) RETURNS       Variant
AS $$
  SELECT registry.get_reg_value(id) FROM registry.value WHERE key = pKey AND vname = pValueName
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RegGetValueEx ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Look up a named value under a registry key and return the full row.
 * @param {uuid} pKey - Registry key identifier
 * @param {text} pValueName - Name of the value to retrieve
 * @return {registry.value} - Complete value row, or NULL if not found
 * @see RegGetValue
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION RegGetValueEx (
  pKey          uuid,
  pValueName    text
) RETURNS       registry.value
AS $$
  SELECT * FROM registry.value WHERE key = pKey AND vname = pValueName
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RegSetValue -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create or update a registry value using a Variant composite (upsert).
 * @param {uuid} pKey - Registry key identifier (or existing value id for direct update)
 * @param {text} pValueName - Name of the value to set
 * @param {Variant} pData - Typed data composite to store
 * @return {uuid} - Identifier of the created or updated value row
 * @see RegSetValueEx
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION RegSetValue (
  pKey           uuid,
  pValueName     text,
  pData          Variant
) RETURNS        uuid
AS $$
DECLARE
  uId            uuid;
BEGIN
  SELECT id INTO uId FROM registry.value WHERE id = pKey;

  IF not FOUND THEN

    SELECT id INTO uId FROM registry.value WHERE key = pKey AND vname = coalesce(pValueName, 'default');

    IF not FOUND THEN

      INSERT INTO registry.value (key, vname, vtype, vinteger, vnumeric, vdatetime, vstring, vboolean)
      VALUES (pKey, pValueName, pData.vType, pData.vInteger, pData.vNumeric, pData.vDateTime, pData.vString, pData.vBoolean)
      RETURNING id INTO uId;

    ELSE

      UPDATE registry.value
         SET vtype = coalesce(pData.vType, vtype),
             vinteger = coalesce(pData.vInteger, vinteger),
             vnumeric = coalesce(pData.vNumeric, vnumeric),
             vdatetime = coalesce(pData.vDateTime, vdatetime),
             vstring = coalesce(pData.vString, vstring),
             vboolean = coalesce(pData.vBoolean, vboolean)
       WHERE id = uId;

    END IF;

  ELSE

    UPDATE registry.value
       SET vname = coalesce(pValueName, vname),
           vtype = coalesce(pData.vType, vtype),
           vinteger = coalesce(pData.vInteger, vinteger),
           vnumeric = coalesce(pData.vNumeric, vnumeric),
           vdatetime = coalesce(pData.vDateTime, vdatetime),
           vstring = coalesce(pData.vString, vstring),
           vboolean = coalesce(pData.vBoolean, vboolean)
     WHERE id = uId;

  END IF;

  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RegSetValueEx ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create or update a registry value using explicit typed parameters (upsert).
 * @param {uuid} pKey - Registry key identifier (or existing value id for direct update)
 * @param {text} pValueName - Name of the value to set
 * @param {integer} pType - Data type discriminator: 0=integer, 1=numeric, 2=datetime, 3=text, 4=boolean
 * @param {integer} pInteger - Integer payload (when pType = 0)
 * @param {numeric} pNumeric - Numeric payload (when pType = 1)
 * @param {timestamp} pDateTime - Timestamp payload (when pType = 2)
 * @param {text} pString - Text payload (when pType = 3)
 * @param {boolean} pBoolean - Boolean payload (when pType = 4)
 * @return {uuid} - Identifier of the created or updated value row
 * @see RegSetValue
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION RegSetValueEx (
  pKey          uuid,
  pValueName    text,
  pType         integer,
  pInteger      integer default null,
  pNumeric      numeric default null,
  pDateTime     timestamp default null,
  pString       text default null,
  pBoolean      boolean default null
) RETURNS       uuid
AS $$
DECLARE
  nId           uuid;
BEGIN
  SELECT id INTO nId FROM registry.value WHERE id = pKey;

  IF not FOUND THEN

    SELECT id INTO nId FROM registry.value WHERE key = pKey AND vname = coalesce(pValueName, 'default');

    IF not FOUND THEN

      INSERT INTO registry.value (key, vname, vtype, vinteger, vnumeric, vdatetime, vstring, vboolean)
      VALUES (pKey, pValueName, pType, pInteger, pNumeric, pDateTime, pString, pBoolean)
      RETURNING id INTO nId;

    ELSE

      UPDATE registry.value
         SET vtype = coalesce(pType, vtype),
             vinteger = coalesce(pInteger, vinteger),
             vnumeric = coalesce(pNumeric, vnumeric),
             vdatetime = coalesce(pDateTime, vdatetime),
             vstring = coalesce(pString, vstring),
             vboolean = coalesce(pBoolean, vboolean)
       WHERE id = nId;

    END IF;

  ELSE

    UPDATE registry.value
       SET vname = coalesce(pValueName, vname),
           vtype = coalesce(pType, vtype),
           vinteger = coalesce(pInteger, vinteger),
           vnumeric = coalesce(pNumeric, vnumeric),
           vdatetime = coalesce(pDateTime, vdatetime),
           vstring = coalesce(pString, vstring),
           vboolean = coalesce(pBoolean, vboolean)
     WHERE id = nId;

  END IF;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION AddRegKey ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Insert a new registry key node into the tree.
 * @param {uuid} pRoot - Root key of the tree (NULL when creating a root key)
 * @param {uuid} pParent - Direct parent key (falls back to pRoot if NULL)
 * @param {text} pKey - Key name segment to create
 * @return {uuid} - Identifier of the newly created key
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION AddRegKey (
  pRoot     uuid,
  pParent   uuid,
  pKey      text
) RETURNS   uuid
AS $$
DECLARE
  nId       uuid;
  nLevel    integer;
BEGIN
  nLevel := 0;
  pParent := coalesce(pParent, pRoot);

  IF pParent IS NOT NULL THEN
    SELECT level + 1 INTO nLevel FROM registry.key WHERE id = pParent;
  END IF;

  INSERT INTO registry.key (root, parent, key, level)
  VALUES (pRoot, pParent, pKey, nLevel)
  RETURNING id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetRegRoot ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Resolve a top-level root key by its name (e.g. 'kernel' or a username).
 * @param {text} pKey - Root key name to look up
 * @return {uuid} - Root key identifier, or NULL if not found
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetRegRoot (
  pKey       text
) RETURNS    uuid
AS $$
DECLARE
  nId        uuid;
BEGIN
  SELECT id INTO nId FROM registry.key WHERE key = pKey AND level = 0;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetRegKey ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Find a child key by parent and name segment.
 * @param {uuid} pParent - Parent key identifier
 * @param {text} pKey - Child key name to look up
 * @return {uuid} - Child key identifier, or NULL if not found
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetRegKey (
  pParent    uuid,
  pKey       text
) RETURNS    uuid
AS $$
DECLARE
  nId        uuid;
BEGIN
  SELECT id INTO nId FROM registry.key WHERE parent = pParent AND key = pKey;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetRegKeyValue -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Look up a value identifier by key and value name.
 * @param {uuid} pKey - Registry key identifier
 * @param {text} pValueName - Name of the value
 * @return {uuid} - Value identifier, or NULL if not found
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION GetRegKeyValue (
  pKey          uuid,
  pValueName    text
) RETURNS       uuid
AS $$
DECLARE
  nId           uuid;
BEGIN
  SELECT id INTO nId FROM registry.value WHERE key = pKey AND vname = pValueName;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DelRegKey ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Delete a registry key and all its directly attached values.
 * @param {uuid} pKey - Registry key identifier to delete
 * @return {void}
 * @see DelTreeRegKey
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DelRegKey (
  pKey       uuid
) RETURNS    void
AS $$
BEGIN
  DELETE FROM registry.value WHERE key = pKey;
  DELETE FROM registry.key WHERE id = pKey;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DelRegKeyValue -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Delete a single registry value by its identifier.
 * @param {uuid} pId - Registry value identifier to delete
 * @return {void}
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DelRegKeyValue (
  pId        uuid
) RETURNS    void
AS $$
BEGIN
  DELETE FROM registry.value WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DelTreeRegKey ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Recursively delete a registry key, all its child keys, and their values.
 * @param {uuid} pKey - Root key identifier of the subtree to remove
 * @return {void}
 * @see DelRegKey
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION DelTreeRegKey (
  pKey       uuid
) RETURNS    void
AS $$
DECLARE
  r          record;
BEGIN
  FOR r IN SELECT id FROM registry.key WHERE parent = pKey
  LOOP
    PERFORM DelTreeRegKey(r.id);
  END LOOP;

  PERFORM DelRegKey(pKey);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION RegCreateKey -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Create a registry key path, building any missing intermediate keys along the way.
 * @param {text} pKey - Root key alias: 'CURRENT_CONFIG' (global) or 'CURRENT_USER' (per-user)
 * @param {text} pSubKey - Backslash-delimited subkey path to create (e.g. 'Settings\Locale')
 * @param {uuid} pUserId - User identifier (used when pKey = 'CURRENT_USER')
 * @return {uuid} - Identifier of the deepest (leaf) key in the path
 * @throws IncorrectRegistryKey - When pKey is not CURRENT_CONFIG or CURRENT_USER
 * @see RegOpenKey, RegDeleteKey
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION RegCreateKey (
  pKey      text,
  pSubKey   text,
  pUserId   uuid DEFAULT current_userid()
) RETURNS   uuid
AS $$
DECLARE
  nId       uuid;
  nRoot     uuid;
  uParent   uuid;

  arKey     text[];
  i         integer;
BEGIN
  arKey := ARRAY['CURRENT_CONFIG', 'CURRENT_USER'];

  IF array_position(arKey, pKey) IS NULL THEN
    PERFORM IncorrectRegistryKey(pKey, arKey);
  END IF;

  IF pKey = 'CURRENT_CONFIG' THEN
    pKey := 'kernel';
  ELSE
    pKey := GetUserName(pUserId);
  END IF;

  nRoot := GetRegRoot(pKey);

  IF nRoot IS NULL THEN
    nRoot := AddRegKey(null, null, pKey);
  END IF;

  IF pSubKey IS NOT NULL THEN

    arKey := registry.reg_key_to_array(pSubKey);

    FOR i IN 1..array_length(arKey, 1)
    LOOP
      uParent := coalesce(nId, nRoot);
      nId := GetRegKey(uParent, arKey[i]);
      IF nId IS NULL THEN
        nId := AddRegKey(nRoot, uParent, arKey[i]);
      END IF;
    END LOOP;
  END IF;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION RegOpenKey ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Open (navigate to) an existing registry key by its path without creating missing segments.
 * @param {text} pKey - Root key alias: 'CURRENT_CONFIG' or 'CURRENT_USER'
 * @param {text} pSubKey - Backslash-delimited subkey path to open
 * @param {uuid} pUserId - User identifier (used when pKey = 'CURRENT_USER')
 * @return {uuid} - Key identifier if found, NULL otherwise
 * @throws IncorrectRegistryKey - When pKey is not CURRENT_CONFIG or CURRENT_USER
 * @see RegCreateKey
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION RegOpenKey (
  pKey      text,
  pSubKey   text,
  pUserId   uuid DEFAULT current_userid()
) RETURNS   uuid
AS $$
DECLARE
  nId       uuid;
  arKey     text[];
  i         integer;
BEGIN
  arKey := ARRAY['CURRENT_CONFIG', 'CURRENT_USER'];

  IF array_position(arKey, pKey) IS NULL THEN
    PERFORM IncorrectRegistryKey(pKey, arKey);
  END IF;

  IF pKey = 'CURRENT_CONFIG' THEN
    pKey := 'kernel';
  ELSE
    pKey := GetUserName(pUserId);
  END IF;

  nId := GetRegRoot(pKey);

  IF (nId IS NOT NULL) AND (pSubKey IS NOT NULL) THEN

    arKey := registry.reg_key_to_array(pSubKey);

    FOR i IN 1..array_length(arKey, 1)
    LOOP
      nId := GetRegKey(nId, arKey[i]);
    END LOOP;

  END IF;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION RegDeleteKey -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Delete a registry subkey and its values (non-recursive).
 * @param {text} pKey - Root key alias: 'CURRENT_CONFIG' or 'CURRENT_USER'
 * @param {text} pSubKey - Backslash-delimited subkey path to delete
 * @param {uuid} pUserId - User identifier (used when pKey = 'CURRENT_USER')
 * @return {boolean} - TRUE on success, FALSE if the subkey was not found
 * @see RegDeleteTree
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION RegDeleteKey (
  pKey      text,
  pSubKey   text,
  pUserId   uuid DEFAULT current_userid()
) RETURNS   boolean
AS $$
DECLARE
  nKey      uuid;
BEGIN
  nKey := RegOpenKey(pKey, pSubKey, pUserId);
  IF nKey IS NOT NULL THEN

    PERFORM DelRegKey(nKey);

    RETURN true;
  ELSE
    PERFORM SetErrorMessage('Specified subkey not found.');
  END IF;

  RETURN false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION RegDeleteKeyValue --------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Delete a named value from a registry subkey.
 * @param {text} pKey - Root key alias: 'CURRENT_CONFIG' or 'CURRENT_USER'
 * @param {text} pSubKey - Backslash-delimited subkey path
 * @param {text} pValueName - Name of the value to delete
 * @param {uuid} pUserId - User identifier (used when pKey = 'CURRENT_USER')
 * @return {boolean} - TRUE on success, FALSE if the subkey or value was not found
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION RegDeleteKeyValue (
  pKey          text,
  pSubKey       text,
  pValueName    text,
  pUserId       uuid DEFAULT current_userid()
) RETURNS       boolean
AS $$
DECLARE
  nId           uuid;
  nKey          uuid;
BEGIN
  nKey := RegOpenKey(pKey, pSubKey, pUserId);
  IF nKey IS NOT NULL THEN

    nId := GetRegKeyValue(nKey, pValueName);
    IF nId IS NOT NULL THEN

      PERFORM DelRegKeyValue(nId);

      RETURN true;
    ELSE
      PERFORM SetErrorMessage('Specified value not found.');
    END IF;
  ELSE
    PERFORM SetErrorMessage('Specified subkey not found.');
  END IF;

  RETURN false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION RegDeleteTree  -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Recursively delete a subkey, all its descendant keys, and their values.
 * @param {text} pKey - Root key alias: 'CURRENT_CONFIG' or 'CURRENT_USER'
 * @param {text} pSubKey - Backslash-delimited subkey path to delete recursively
 * @param {uuid} pUserId - User identifier (used when pKey = 'CURRENT_USER')
 * @return {boolean} - TRUE on success, FALSE if the subkey was not found
 * @see RegDeleteKey
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION RegDeleteTree (
  pKey       text,
  pSubKey    text,
  pUserId    uuid DEFAULT current_userid()
) RETURNS    boolean
AS $$
DECLARE
  nKey       uuid;
BEGIN
  nKey := RegOpenKey(pKey, pSubKey, pUserId);
  IF nKey IS NOT NULL THEN

    PERFORM DelTreeRegKey(nKey);

    RETURN true;
  ELSE
    PERFORM SetErrorMessage('Specified subkey not found.');
  END IF;

  RETURN false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- VIEW ------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- registry.registry -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW registry.registry (Id, Key, KeyName, Parent, SubKey, SubKeyName, Level,
  ValueName, Value
)
AS
  SELECT coalesce(v.id, k.id), k.root,
         CASE r.key WHEN 'kernel' THEN 'CURRENT_CONFIG' ELSE 'CURRENT_USER' END,
         k.parent, k.id, k.key, k.level,
         v.vname, registry.get_reg_value(v.id)
    FROM registry.key k  LEFT JOIN registry.value v ON k.id = v.key
                        INNER JOIN registry.key   r ON k.root = r.id;

--------------------------------------------------------------------------------
-- registry.registry_ex --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW registry.registry_ex (Id, Key, KeyName, Parent, SubKey, SubKeyName, Level,
  ValueName, vType, vInteger, vNumeric, vDateTime, vString, vBoolean
)
AS
  SELECT coalesce(v.id, k.id), k.root,
         CASE r.key WHEN 'kernel' THEN 'CURRENT_CONFIG' ELSE 'CURRENT_USER' END,
         k.parent, k.id, k.key, k.level,
         v.vname, v.vtype, v.vinteger, v.vnumeric, v.vdatetime, v.vstring, v.vboolean
    FROM registry.key k  LEFT JOIN registry.value v ON v.key = k.id
                        INNER JOIN registry.key   r ON r.id = k.root;

--------------------------------------------------------------------------------
-- registry.registry_key -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW registry.registry_key
AS
  SELECT * FROM registry.key;

--------------------------------------------------------------------------------
-- registry.registry_value -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW registry.registry_value (Id, Key, KeyName, SubKey, SubKeyName,
  ValueName, Value
)
AS
  SELECT v.id, k.root,
         CASE r.key WHEN 'kernel' THEN 'CURRENT_CONFIG' ELSE 'CURRENT_USER' END,
         k.id, k.key,
         v.vname, registry.get_reg_value(v.id)
    FROM registry.value v, LATERAL (SELECT * FROM registry.key WHERE id = v.key) k,
                           LATERAL (SELECT * FROM registry.key WHERE id = k.root) r;

--------------------------------------------------------------------------------
-- registry.registry_value_ex --------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW registry.registry_value_ex (Id, Key, KeyName, SubKey, SubKeyName,
  ValueName, vType, vInteger, vNumeric, vDateTime, vString, vBoolean
)
AS
  SELECT v.id, k.root,
         CASE r.key WHEN 'kernel' THEN 'CURRENT_CONFIG' ELSE 'CURRENT_USER' END,
         k.id, k.key,
         v.vname, v.vtype, v.vinteger, v.vnumeric, v.vdatetime, v.vstring, v.vboolean
    FROM registry.value v, LATERAL (SELECT * FROM registry.key WHERE id = v.key) k,
                           LATERAL (SELECT * FROM registry.key WHERE id = k.root) r;

--------------------------------------------------------------------------------
-- registry --------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Filter the registry view by root key identifier.
 * @param {uuid} pKey - Root key identifier to filter on
 * @return {SETOF registry.registry} - Matching registry entries with Variant values
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION registry.registry (
  pKey       uuid
) RETURNS    SETOF registry.registry
AS $$
  SELECT * FROM registry.registry WHERE key = pKey
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- registry_ex -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Filter the extended registry view by root key identifier.
 * @param {uuid} pKey - Root key identifier to filter on
 * @return {SETOF registry.registry_ex} - Matching entries with raw typed columns
 * @see registry.registry
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION registry.registry_ex (
  pKey       uuid
) RETURNS    SETOF registry.registry_ex
AS $$
  SELECT * FROM registry.registry_ex WHERE key = pKey
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION registry_key -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Filter the registry key view by root key identifier.
 * @param {uuid} pKey - Root key identifier to filter on
 * @return {SETOF registry.registry_key} - All keys belonging to the specified root
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION registry.registry_key (
  pKey       uuid
) RETURNS    SETOF registry.registry_key
AS $$
  SELECT * FROM registry.registry_key WHERE root = pKey
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION registry_value -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Filter the registry value view by root key identifier.
 * @param {uuid} pKey - Root key identifier to filter on
 * @return {SETOF registry.registry_value} - Values under the specified root with Variant data
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION registry.registry_value (
  pKey       uuid
) RETURNS    SETOF registry.registry_value
AS $$
  SELECT * FROM registry.registry_value WHERE key = pKey
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION registry_value_ex --------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Filter the extended registry value view by root key identifier.
 * @param {uuid} pKey - Root key identifier to filter on
 * @return {SETOF registry.registry_value_ex} - Values with raw typed columns
 * @see registry.registry_value
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION registry.registry_value_ex (
  pKey       uuid
) RETURNS    SETOF registry.registry_value_ex
AS $$
  SELECT * FROM registry.registry_value_ex WHERE key = pKey
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RegSetValueInteger ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Store an integer value in the registry, creating the key path if needed.
 * @param {text} pKey - Root key alias: 'CURRENT_CONFIG' or 'CURRENT_USER'
 * @param {text} pSubKey - Backslash-delimited subkey path
 * @param {text} pValueName - Name of the value to set
 * @param {integer} pValue - Integer data to store
 * @param {uuid} pUserId - User identifier (used when pKey = 'CURRENT_USER')
 * @return {uuid} - Identifier of the created or updated value row
 * @see RegGetValueInteger
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION RegSetValueInteger (
  pKey          text,
  pSubKey       text,
  pValueName    text,
  pValue        integer,
  pUserId       uuid DEFAULT current_userid()
) RETURNS       uuid
AS $$
BEGIN
  RETURN RegSetValueEx(RegCreateKey(pKey, pSubKey, pUserId), pValueName, 0, pInteger => pValue);
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RegSetValueNumeric ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Store a numeric value in the registry, creating the key path if needed.
 * @param {text} pKey - Root key alias: 'CURRENT_CONFIG' or 'CURRENT_USER'
 * @param {text} pSubKey - Backslash-delimited subkey path
 * @param {text} pValueName - Name of the value to set
 * @param {numeric} pValue - Numeric data to store
 * @param {uuid} pUserId - User identifier (used when pKey = 'CURRENT_USER')
 * @return {uuid} - Identifier of the created or updated value row
 * @see RegGetValueNumeric
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION RegSetValueNumeric (
  pKey          text,
  pSubKey       text,
  pValueName    text,
  pValue        numeric,
  pUserId       uuid DEFAULT current_userid()
) RETURNS       uuid
AS $$
BEGIN
  RETURN RegSetValueEx(RegCreateKey(pKey, pSubKey, pUserId), pValueName, 1, pNumeric => pValue);
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RegSetValueDate -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Store a timestamp value in the registry, creating the key path if needed.
 * @param {text} pKey - Root key alias: 'CURRENT_CONFIG' or 'CURRENT_USER'
 * @param {text} pSubKey - Backslash-delimited subkey path
 * @param {text} pValueName - Name of the value to set
 * @param {timestamp} pValue - Timestamp data to store
 * @param {uuid} pUserId - User identifier (used when pKey = 'CURRENT_USER')
 * @return {timestamp} - The stored timestamp value
 * @see RegGetValueDate
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION RegSetValueDate (
  pKey          text,
  pSubKey       text,
  pValueName    text,
  pValue        timestamp,
  pUserId       uuid DEFAULT current_userid()
) RETURNS       timestamp
AS $$
BEGIN
  RETURN RegSetValueEx(RegCreateKey(pKey, pSubKey, pUserId), pValueName, 2, pDateTime => pValue);
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RegSetValueString -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Store a text value in the registry, creating the key path if needed.
 * @param {text} pKey - Root key alias: 'CURRENT_CONFIG' or 'CURRENT_USER'
 * @param {text} pSubKey - Backslash-delimited subkey path
 * @param {text} pValueName - Name of the value to set
 * @param {text} pValue - Text data to store
 * @param {uuid} pUserId - User identifier (used when pKey = 'CURRENT_USER')
 * @return {text} - The stored text value
 * @see RegGetValueString
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION RegSetValueString (
  pKey          text,
  pSubKey       text,
  pValueName    text,
  pValue        text,
  pUserId       uuid DEFAULT current_userid()
) RETURNS       text
AS $$
BEGIN
  RETURN RegSetValueEx(RegCreateKey(pKey, pSubKey, pUserId), pValueName, 3, pString => pValue);
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RegSetValueBoolean ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Store a boolean value in the registry, creating the key path if needed.
 * @param {text} pKey - Root key alias: 'CURRENT_CONFIG' or 'CURRENT_USER'
 * @param {text} pSubKey - Backslash-delimited subkey path
 * @param {text} pValueName - Name of the value to set
 * @param {boolean} pValue - Boolean data to store
 * @param {uuid} pUserId - User identifier (used when pKey = 'CURRENT_USER')
 * @return {boolean} - The stored boolean value
 * @see RegGetValueBoolean
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION RegSetValueBoolean (
  pKey          text,
  pSubKey       text,
  pValueName    text,
  pValue        boolean,
  pUserId       uuid DEFAULT current_userid()
) RETURNS       boolean
AS $$
BEGIN
  RETURN RegSetValueEx(RegCreateKey(pKey, pSubKey, pUserId), pValueName, 4, pBoolean => pValue);
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RegGetValueType -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve the data type discriminator for a named registry value.
 * @param {text} pKey - Root key alias: 'CURRENT_CONFIG' or 'CURRENT_USER'
 * @param {text} pSubKey - Backslash-delimited subkey path
 * @param {text} pValueName - Name of the value to inspect
 * @param {uuid} pUserId - User identifier (used when pKey = 'CURRENT_USER')
 * @return {integer} - Type code: 0=integer, 1=numeric, 2=datetime, 3=text, 4=boolean
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION RegGetValueType (
  pKey          text,
  pSubKey       text,
  pValueName    text,
  pUserId       uuid DEFAULT current_userid()
) RETURNS       integer
AS $$
BEGIN
  RETURN (RegGetValue(RegOpenKey(pKey, pSubKey, pUserId), pValueName)).vtype;
END
$$ LANGUAGE plpgsql STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RegGetValueInteger ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve an integer value from the registry by key path and value name.
 * @param {text} pKey - Root key alias: 'CURRENT_CONFIG' or 'CURRENT_USER'
 * @param {text} pSubKey - Backslash-delimited subkey path
 * @param {text} pValueName - Name of the value to read
 * @param {uuid} pUserId - User identifier (used when pKey = 'CURRENT_USER')
 * @return {integer} - Stored integer, or NULL if not found
 * @see RegSetValueInteger
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION RegGetValueInteger (
  pKey          text,
  pSubKey       text,
  pValueName    text,
  pUserId       uuid DEFAULT current_userid()
) RETURNS       integer
AS $$
BEGIN
  RETURN (RegGetValue(RegOpenKey(pKey, pSubKey, pUserId), pValueName)).vInteger;
END
$$ LANGUAGE plpgsql STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RegGetValueNumeric ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve a numeric value from the registry by key path and value name.
 * @param {text} pKey - Root key alias: 'CURRENT_CONFIG' or 'CURRENT_USER'
 * @param {text} pSubKey - Backslash-delimited subkey path
 * @param {text} pValueName - Name of the value to read
 * @param {uuid} pUserId - User identifier (used when pKey = 'CURRENT_USER')
 * @return {numeric} - Stored numeric, or NULL if not found
 * @see RegSetValueNumeric
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION RegGetValueNumeric (
  pKey          text,
  pSubKey       text,
  pValueName    text,
  pUserId       uuid DEFAULT current_userid()
) RETURNS       numeric
AS $$
BEGIN
  RETURN (RegGetValue(RegOpenKey(pKey, pSubKey, pUserId), pValueName)).vNumeric;
END
$$ LANGUAGE plpgsql STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RegGetValueDate -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve a timestamp value from the registry by key path and value name.
 * @param {text} pKey - Root key alias: 'CURRENT_CONFIG' or 'CURRENT_USER'
 * @param {text} pSubKey - Backslash-delimited subkey path
 * @param {text} pValueName - Name of the value to read
 * @param {uuid} pUserId - User identifier (used when pKey = 'CURRENT_USER')
 * @return {timestamp} - Stored timestamp, or NULL if not found
 * @see RegSetValueDate
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION RegGetValueDate (
  pKey          text,
  pSubKey       text,
  pValueName    text,
  pUserId       uuid DEFAULT current_userid()
) RETURNS       timestamp
AS $$
BEGIN
  RETURN (RegGetValue(RegOpenKey(pKey, pSubKey, pUserId), pValueName)).vDateTime;
END
$$ LANGUAGE plpgsql STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RegGetValueString -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve a text value from the registry by key path and value name.
 * @param {text} pKey - Root key alias: 'CURRENT_CONFIG' or 'CURRENT_USER'
 * @param {text} pSubKey - Backslash-delimited subkey path
 * @param {text} pValueName - Name of the value to read
 * @param {uuid} pUserId - User identifier (used when pKey = 'CURRENT_USER')
 * @return {text} - Stored text, or NULL if not found
 * @see RegSetValueString
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION RegGetValueString (
  pKey          text,
  pSubKey       text,
  pValueName    text,
  pUserId       uuid DEFAULT current_userid()
) RETURNS       text
AS $$
BEGIN
  RETURN (RegGetValue(RegOpenKey(pKey, pSubKey, pUserId), pValueName)).vString;
END
$$ LANGUAGE plpgsql STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RegGetValueBoolean ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Retrieve a boolean value from the registry by key path and value name.
 * @param {text} pKey - Root key alias: 'CURRENT_CONFIG' or 'CURRENT_USER'
 * @param {text} pSubKey - Backslash-delimited subkey path
 * @param {text} pValueName - Name of the value to read
 * @param {uuid} pUserId - User identifier (used when pKey = 'CURRENT_USER')
 * @return {boolean} - Stored boolean, or NULL if not found
 * @see RegSetValueBoolean
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION RegGetValueBoolean (
  pKey          text,
  pSubKey       text,
  pValueName    text,
  pUserId       uuid DEFAULT current_userid()
) RETURNS       boolean
AS $$
BEGIN
  RETURN (RegGetValue(RegOpenKey(pKey, pSubKey, pUserId), pValueName)).vBoolean;
END
$$ LANGUAGE plpgsql STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
