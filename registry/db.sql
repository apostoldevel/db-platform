--------------------------------------------------------------------------------
-- REGISTRY --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE registry.key (
    id			numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REGISTRY'),
    root		numeric(12),
    parent		numeric(12),
    key			text NOT NULL,
    level		integer NOT NULL,
    CONSTRAINT fk_registry_key_root FOREIGN KEY (root) REFERENCES registry.key(id),
    CONSTRAINT fk_registry_key_parent FOREIGN KEY (parent) REFERENCES registry.key(id)
);

COMMENT ON TABLE registry.key IS 'Реестр (ключ).';

COMMENT ON COLUMN registry.key.id IS 'Идентификатор';
COMMENT ON COLUMN registry.key.root IS 'Идентификатор корневого узла';
COMMENT ON COLUMN registry.key.parent IS 'Идентификатор родительского узла';
COMMENT ON COLUMN registry.key.key IS 'Ключ';
COMMENT ON COLUMN registry.key.level IS 'Уровень вложенности';

CREATE INDEX registry_key_root ON registry.key (root);
CREATE INDEX registry_key_parent ON registry.key (parent);
CREATE INDEX registry_key_key ON registry.key (key);
CREATE INDEX registry_key_level ON registry.key (level);

CREATE UNIQUE INDEX registry_key_unique ON registry.key (root, parent, key);

--------------------------------------------------------------------------------
-- REGISTRY_VALUE --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE registry.value (
    id			numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REGISTRY'),
    key			numeric(12) NOT NULL,
    vname		text NOT NULL,
    vtype		integer NOT NULL,
    vinteger	integer,
    vnumeric	numeric,
    vdatetime	timestamp,
    vstring		text,
    vboolean	boolean,
    CONSTRAINT ch_registry_value_type CHECK (vtype BETWEEN 0 AND 4),
    CONSTRAINT fk_registry_value_key FOREIGN KEY (key) REFERENCES registry.key(id)
);

COMMENT ON TABLE registry.value IS 'Реестр (значение).';

COMMENT ON COLUMN registry.value.id IS 'Идентификатор';
COMMENT ON COLUMN registry.value.key IS 'Идентификатор ключа';
COMMENT ON COLUMN registry.value.vname IS 'Имя значения';
COMMENT ON COLUMN registry.value.vtype IS 'Тип данных';
COMMENT ON COLUMN registry.value.vinteger IS 'Целое число: vtype = 0';
COMMENT ON COLUMN registry.value.vnumeric IS 'Число с произвольной точностью: vtype = 1';
COMMENT ON COLUMN registry.value.vdatetime IS 'Дата и время: vtype = 2';
COMMENT ON COLUMN registry.value.vstring IS 'Строка: vtype = 3';
COMMENT ON COLUMN registry.value.vboolean IS 'Логический: vtype = 4';

--------------------------------------------------------------------------------

CREATE INDEX registry_value_key ON registry.value (key);
CREATE INDEX registry_value_name ON registry.value (vname);

CREATE UNIQUE INDEX registry_value_unique ON registry.value (key, vname);

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
  pKey		numeric
) RETURNS	text
AS $$
DECLARE
  vKey		text;
  r		    record;
BEGIN
  FOR r IN 
    WITH RECURSIVE keytree(id, parent, key) AS (
      SELECT id, parent, key FROM registry.key WHERE id = pKey
    UNION ALL
      SELECT k.id, k.parent, k.key
        FROM registry.key k INNER JOIN keytree kt ON kt.parent = k.id
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
  pId		numeric
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
  pId		numeric
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
  pKey		numeric,
  OUT id	numeric,
  OUT key	numeric,
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
  pKey		numeric
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
  pId		numeric
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
  pId		numeric
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
  pKey		    numeric,
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
  pKey		    numeric,
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
  pKey		    numeric,
  pValueName	text,
  pData		    Variant
) RETURNS	    numeric
AS $$
DECLARE
  nId		    numeric;
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
  pKey		    numeric,
  pValueName	text,
  pType		    integer,
  pInteger	    integer default null,
  pNumeric	    numeric default null,
  pDateTime	    timestamp default null,
  pString	    text default null,
  pBoolean	    boolean default null
) RETURNS	    numeric
AS $$
DECLARE
  nId		    numeric;
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
  pRoot		numeric,
  pParent	numeric,
  pKey		varchar
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
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
  pKey		varchar
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
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
  pParent	numeric,
  pKey		varchar
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
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
  pKey		    numeric,
  pValueName	varchar
) RETURNS	    numeric
AS $$
DECLARE
  nId		    numeric;
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
  pKey		numeric
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
  pId		numeric
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
  pKey		numeric
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
  pSubKey	text
) RETURNS 	numeric
AS $$
DECLARE
  nId		numeric;
  nRoot		numeric;
  nParent	numeric;

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
    pKey := current_username();
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
  pSubKey	text
) RETURNS 	numeric
AS $$
DECLARE
  nId		numeric;
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
    pKey := current_username();
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
  pSubKey	text
) RETURNS 	boolean
AS $$
DECLARE
  nKey		numeric;
BEGIN
  nKey := RegOpenKey(pKey, pSubKey);
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
  pKey		text,
  pSubKey	text,
  pValueName	text
) RETURNS 	boolean
AS $$
DECLARE
  nId		numeric;
  nKey		numeric;
BEGIN
  nKey := RegOpenKey(pKey, pSubKey);
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
  pSubKey	text
) RETURNS 	boolean
AS $$
DECLARE
  nKey		numeric;
BEGIN
  nKey := RegOpenKey(pKey, pSubKey);
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
-- REGISTRY --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW registry.registry (Id, Key, KeyName, Parent, SubKey, SubKeyName, Level,
  ValueName, Value
) 
AS
  SELECT coalesce(v.id, k.id), k.root, 
         CASE r.key WHEN 'kernel' THEN 'CURRENT_CONFIG' ELSE 'CURRENT_USER' END, 
         k.parent, k.id, k.key, k.level, 
         v.vname, registry.get_reg_value(v.id)
    FROM registry.key k  LEFT JOIN registry.value v ON v.key = k.id
                        INNER JOIN (SELECT * FROM registry.key) r ON r.id = k.root;

--------------------------------------------------------------------------------
-- REGISTRY_EX -----------------------------------------------------------------
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
-- registry --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION registry.registry (
  pKey		numeric
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
  pKey		numeric
) RETURNS	SETOF registry.registry_ex
AS $$
  SELECT * FROM registry.registry_ex WHERE key = pKey
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- Registry --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Registry
AS
  SELECT * FROM registry.registry(GetRegRoot('kernel'))
   UNION ALL
  SELECT * FROM registry.registry(GetRegRoot(current_username()));

GRANT ALL ON Registry TO administrator;

--------------------------------------------------------------------------------
-- RegistryEx ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW RegistryEx
AS
  SELECT * FROM registry.registry_ex(GetRegRoot('kernel'))
   UNION ALL
  SELECT * FROM registry.registry_ex(GetRegRoot(current_username()));

GRANT ALL ON RegistryEx TO administrator;

--------------------------------------------------------------------------------
-- registry_key ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW registry.registry_key
AS
  SELECT * FROM registry.key;

--------------------------------------------------------------------------------
-- FUNCTION registry_key -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION registry.registry_key (
  pKey		numeric
) RETURNS	SETOF registry.registry_key
AS $$
  SELECT * FROM registry.registry_key WHERE root = pKey
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RegistryKey -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW RegistryKey
AS
  SELECT * FROM registry.registry_key(GetRegRoot('kernel'))
   UNION ALL
  SELECT * FROM registry.registry_key(GetRegRoot(current_username()));

GRANT ALL ON RegistryKey TO administrator;

--------------------------------------------------------------------------------
-- registry_value --------------------------------------------------------------
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
-- registry_value_ex -----------------------------------------------------------
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
-- FUNCTION registry_value -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION registry.registry_value (
  pKey		numeric
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
  pKey		numeric
) RETURNS	SETOF registry.registry_value_ex
AS $$
  SELECT * FROM registry.registry_value_ex WHERE key = pKey
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- RegistryValue ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW RegistryValue
AS
  SELECT * FROM registry.registry_value(GetRegRoot('kernel'))
   UNION ALL
  SELECT * FROM registry.registry_value(GetRegRoot(current_username()));

GRANT ALL ON RegistryValue TO administrator;

--------------------------------------------------------------------------------
-- RegistryValueEx -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW RegistryValueEx
AS
  SELECT * FROM registry.registry_value_ex(GetRegRoot('kernel'))
   UNION ALL
  SELECT * FROM registry.registry_value_ex(GetRegRoot(current_username()));

GRANT ALL ON RegistryValueEx TO administrator;
