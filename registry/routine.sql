--------------------------------------------------------------------------------
-- FUNCTION reg_key_to_array ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION registry.reg_key_to_array (
  pKey		text
) RETURNS 	text[]
AS $$
DECLARE
  i		    integer;
  arKey		text[];
  vStr		text;
  vKey		text;
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

CREATE OR REPLACE FUNCTION registry.get_reg_key (
  pId		uuid
) RETURNS	text
AS $$
DECLARE
  vKey		text;
  r		    record;
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

CREATE OR REPLACE FUNCTION registry.get_reg_value (
  pId		uuid
) RETURNS	Variant
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

CREATE OR REPLACE FUNCTION RegEnumKey (
  pId		uuid
) RETURNS	SETOF registry.key
AS $$
  SELECT * FROM registry.key WHERE parent = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RegEnumValue ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION RegEnumValue (
  pKey		uuid,
  OUT id	uuid,
  OUT key	uuid,
  OUT vname	text,
  OUT value	Variant
) RETURNS	SETOF record
AS $$
  SELECT v.id, v.key, v.vname, registry.get_reg_value(v.id) FROM registry.value v WHERE v.key = pKey
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RegEnumValueEx --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION RegEnumValueEx (
  pKey		uuid
) RETURNS	SETOF registry.value
AS $$
  SELECT * FROM registry.value WHERE key = pKey
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RegQueryValue ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION RegQueryValue (
  pId		uuid
) RETURNS	Variant
AS $$
  SELECT registry.get_reg_value(id) FROM registry.value WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RegQueryValueEx -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION RegQueryValueEx (
  pId		uuid
) RETURNS	registry.value
AS $$
  SELECT * FROM registry.value WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RegGetValue -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION RegGetValue (
  pKey		    uuid,
  pValueName	text
) RETURNS	    Variant
AS $$
  SELECT registry.get_reg_value(id) FROM registry.value WHERE key = pKey AND vname = pValueName
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RegGetValueEx ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION RegGetValueEx (
  pKey		    uuid,
  pValueName	text
) RETURNS	    registry.value
AS $$
  SELECT * FROM registry.value WHERE key = pKey AND vname = pValueName
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RegSetValue -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION RegSetValue (
  pKey		    uuid,
  pValueName	text,
  pData		    Variant
) RETURNS	    uuid
AS $$
DECLARE
  nId		    uuid;
BEGIN
  SELECT id INTO nId FROM registry.value WHERE id = pKey;

  IF not found THEN

    SELECT id INTO nId FROM registry.value WHERE key = pKey AND vname = coalesce(pValueName, 'default');

    IF not found THEN

      INSERT INTO registry.value (key, vname, vtype, vinteger, vnumeric, vdatetime, vstring, vboolean)
      VALUES (pKey, pValueName, pData.vType, pData.vInteger, pData.vNumeric, pData.vDateTime, pData.vString, pData.vBoolean)
      RETURNING id INTO nId;

    ELSE

      UPDATE registry.value
         SET vtype = coalesce(pData.vType, vtype),
             vinteger = coalesce(pData.vInteger, vinteger),
             vnumeric = coalesce(pData.vNumeric, vnumeric),
             vdatetime = coalesce(pData.vDateTime, vdatetime),
             vstring = coalesce(pData.vString, vstring),
             vboolean = coalesce(pData.vBoolean, vboolean)
       WHERE id = nId;

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
     WHERE id = nId;

  END IF;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RegSetValueEx ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION RegSetValueEx (
  pKey		    uuid,
  pValueName	text,
  pType		    integer,
  pInteger	    integer default null,
  pNumeric	    numeric default null,
  pDateTime	    timestamp default null,
  pString	    text default null,
  pBoolean	    boolean default null
) RETURNS	    uuid
AS $$
DECLARE
  nId		    uuid;
BEGIN
  SELECT id INTO nId FROM registry.value WHERE id = pKey;

  IF not found THEN

    SELECT id INTO nId FROM registry.value WHERE key = pKey AND vname = coalesce(pValueName, 'default');

    IF not found THEN

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

CREATE OR REPLACE FUNCTION AddRegKey (
  pRoot		uuid,
  pParent	uuid,
  pKey		text
) RETURNS	uuid
AS $$
DECLARE
  nId		uuid;
  nLevel	integer;
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

CREATE OR REPLACE FUNCTION GetRegRoot (
  pKey		text
) RETURNS	uuid
AS $$
DECLARE
  nId		uuid;
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

CREATE OR REPLACE FUNCTION GetRegKey (
  pParent	uuid,
  pKey		text
) RETURNS	uuid
AS $$
DECLARE
  nId		uuid;
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

CREATE OR REPLACE FUNCTION GetRegKeyValue (
  pKey		    uuid,
  pValueName	text
) RETURNS	    uuid
AS $$
DECLARE
  nId		    uuid;
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

CREATE OR REPLACE FUNCTION DelRegKey (
  pKey		uuid
) RETURNS	void
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

CREATE OR REPLACE FUNCTION DelRegKeyValue (
  pId		uuid
) RETURNS	void
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

CREATE OR REPLACE FUNCTION DelTreeRegKey (
  pKey		uuid
) RETURNS	void
AS $$
DECLARE
  r		    record;
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

CREATE OR REPLACE FUNCTION RegCreateKey (
  pKey		text,
  pSubKey	text,
  pUserId   uuid DEFAULT current_userid()
) RETURNS 	uuid
AS $$
DECLARE
  nId		uuid;
  nRoot		uuid;
  nParent	uuid;

  arKey		text[];
  i		    integer;
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
      nParent := coalesce(nId, nRoot);
      nId := GetRegKey(nParent, arKey[i]);
      IF nId IS NULL THEN
        nId := AddRegKey(nRoot, nParent, arKey[i]);
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

CREATE OR REPLACE FUNCTION RegOpenKey (
  pKey		text,
  pSubKey	text,
  pUserId   uuid DEFAULT current_userid()
) RETURNS 	uuid
AS $$
DECLARE
  nId		uuid;
  arKey		text[];
  i		    integer;
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

CREATE OR REPLACE FUNCTION RegDeleteKey (
  pKey		text,
  pSubKey	text,
  pUserId   uuid DEFAULT current_userid()
) RETURNS 	boolean
AS $$
DECLARE
  nKey		uuid;
BEGIN
  nKey := RegOpenKey(pKey, pSubKey, pUserId);
  IF nKey IS NOT NULL THEN

    PERFORM DelRegKey(nKey);

    RETURN true;
  ELSE
    PERFORM SetErrorMessage('Указанный подключ не найден.');
  END IF;

  RETURN false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION RegDeleteKeyValue --------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION RegDeleteKeyValue (
  pKey          text,
  pSubKey       text,
  pValueName    text,
  pUserId		uuid DEFAULT current_userid()
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
      PERFORM SetErrorMessage('Указанное значение не найдено.');
    END IF;
  ELSE
    PERFORM SetErrorMessage('Указанный подключ не найден.');
  END IF;

  RETURN false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION RegDeleteTree  -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION RegDeleteTree (
  pKey		text,
  pSubKey	text,
  pUserId	uuid DEFAULT current_userid()
) RETURNS 	boolean
AS $$
DECLARE
  nKey		uuid;
BEGIN
  nKey := RegOpenKey(pKey, pSubKey, pUserId);
  IF nKey IS NOT NULL THEN

    PERFORM DelTreeRegKey(nKey);

    RETURN true;
  ELSE
    PERFORM SetErrorMessage('Указанный подключ не найден.');
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
                        INNER JOIN (SELECT * FROM registry.key) r ON k.root = r.id ;

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
                        INNER JOIN (SELECT * FROM registry.key) r ON r.id = k.root;

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

CREATE OR REPLACE FUNCTION registry.registry (
  pKey		uuid
) RETURNS	SETOF registry.registry
AS $$
  SELECT * FROM registry.registry WHERE key = pKey
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- registry_ex -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION registry.registry_ex (
  pKey		uuid
) RETURNS	SETOF registry.registry_ex
AS $$
  SELECT * FROM registry.registry_ex WHERE key = pKey
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION registry_key -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION registry.registry_key (
  pKey		uuid
) RETURNS	SETOF registry.registry_key
AS $$
  SELECT * FROM registry.registry_key WHERE root = pKey
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION registry_value -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION registry.registry_value (
  pKey		uuid
) RETURNS	SETOF registry.registry_value
AS $$
  SELECT * FROM registry.registry_value WHERE key = pKey
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION registry_value_ex --------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION registry.registry_value_ex (
  pKey		uuid
) RETURNS	SETOF registry.registry_value_ex
AS $$
  SELECT * FROM registry.registry_value_ex WHERE key = pKey
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RegSetValueInteger ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION RegSetValueInteger (
  pKey		    text,
  pSubKey		text,
  pValueName	text,
  pValue		integer,
  pUserId		uuid DEFAULT current_userid()
) RETURNS	    uuid
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

CREATE OR REPLACE FUNCTION RegSetValueNumeric (
  pKey		    text,
  pSubKey		text,
  pValueName	text,
  pValue		numeric,
  pUserId		uuid DEFAULT current_userid()
) RETURNS	    uuid
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

CREATE OR REPLACE FUNCTION RegSetValueDate (
  pKey		    text,
  pSubKey		text,
  pValueName	text,
  pValue		timestamp,
  pUserId		uuid DEFAULT current_userid()
) RETURNS	    timestamp
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

CREATE OR REPLACE FUNCTION RegSetValueString (
  pKey		    text,
  pSubKey		text,
  pValueName	text,
  pValue		text,
  pUserId		uuid DEFAULT current_userid()
) RETURNS	    text
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

CREATE OR REPLACE FUNCTION RegSetValueBoolean (
  pKey		    text,
  pSubKey		text,
  pValueName	text,
  pValue		boolean,
  pUserId		uuid DEFAULT current_userid()
) RETURNS	    boolean
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

CREATE OR REPLACE FUNCTION RegGetValueType (
  pKey		    text,
  pSubKey		text,
  pValueName	text,
  pUserId		uuid DEFAULT current_userid()
) RETURNS	    integer
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

CREATE OR REPLACE FUNCTION RegGetValueInteger (
  pKey		    text,
  pSubKey		text,
  pValueName	text,
  pUserId		uuid DEFAULT current_userid()
) RETURNS	    integer
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

CREATE OR REPLACE FUNCTION RegGetValueNumeric (
  pKey		    text,
  pSubKey		text,
  pValueName	text,
  pUserId		uuid DEFAULT current_userid()
) RETURNS	    numeric
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

CREATE OR REPLACE FUNCTION RegGetValueDate (
  pKey		    text,
  pSubKey		text,
  pValueName	text,
  pUserId		uuid DEFAULT current_userid()
) RETURNS	    timestamp
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

CREATE OR REPLACE FUNCTION RegGetValueString (
  pKey		    text,
  pSubKey		text,
  pValueName	text,
  pUserId		uuid DEFAULT current_userid()
) RETURNS	    text
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

CREATE OR REPLACE FUNCTION RegGetValueBoolean (
  pKey		    text,
  pSubKey		text,
  pValueName	text,
  pUserId		uuid DEFAULT current_userid()
) RETURNS	    boolean
AS $$
BEGIN
  RETURN (RegGetValue(RegOpenKey(pKey, pSubKey, pUserId), pValueName)).vBoolean;
END
$$ LANGUAGE plpgsql STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

