--------------------------------------------------------------------------------
-- REGISTRY --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.registry
AS
  SELECT * FROM Registry;

GRANT SELECT ON api.registry TO administrator;

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.registry (
  pId		uuid,
  pKey		uuid,
  pSubKey	uuid
) RETURNS	SETOF api.registry
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

CREATE OR REPLACE FUNCTION api.registry_ex (
  pId		uuid,
  pKey		uuid,
  pSubKey	uuid
) RETURNS	SETOF api.registry_ex
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

CREATE OR REPLACE FUNCTION api.registry_key (
  pId		uuid,
  pRoot		uuid,
  pParent	uuid,
  pKey		text
) RETURNS	SETOF api.registry_key
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

CREATE OR REPLACE FUNCTION api.registry_value (
  pId		uuid,
  pKey		uuid
) RETURNS	SETOF api.registry_value
AS $$
  SELECT *
    FROM api.registry_value
   WHERE id = coalesce(pId, id)
     AND key = coalesce(pKey, key)
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.registry_value_ex (
  pId		uuid,
  pKey		uuid
) RETURNS	SETOF api.registry_value_ex
AS $$
  SELECT *
    FROM api.registry_value_ex
   WHERE id = coalesce(pId, id)
     AND key = coalesce(pKey, key)
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

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
 * Перечисляет подключи указанной пары ключ/подключ реестра.
 * @param {text} pKey - Ключ: CURRENT_CONFIG | CURRENT_USER
 * @param {text} pSubKey - Подключ: Указанный подключ должен быть подключем ключа, указанного в параметре pKey.
                                    Этот подключ не должен начинатся и заканчиваться знаком обратной черты ('\').
 * @out param {uuid} id - Идентификатор подключа
 * @out param {text} key - Ключ
 * @out param {text} subkey - Подключ
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.registry_enum_key (
  pKey      text,
  pSubKey   text
) RETURNS TABLE (
  id	    uuid,
  key	    text,
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
 * Перечисляет значения для указанной пары ключ/подключ реестра.
 * @param {text} pKey - Ключ: CURRENT_CONFIG | CURRENT_USER
 * @param {text} pSubKey - Подключ: Указанный подключ должен быть подключем ключа, указанного в параметре pKey.
                                    Этот подключ не должен начинатся и заканчиваться знаком обратной черты ('\').
 * @out param {uuid} id - Идентификатор значения
 * @out param {text} key - Ключ
 * @out param {text} subkey - Подключ
 * @out param {text} valuename - Имя значения
 * @out param {variant} data - Данные
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.registry_enum_value (
  pKey      text,
  pSubKey   text
) RETURNS TABLE (
  id	    uuid,
  key	    text,
  subkey    text,
  valuename text,
  value	    variant
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
 * Перечисляет значения для указанной пары ключ/подключ реестра.
 * @param {text} pKey - Ключ: CURRENT_CONFIG | CURRENT_USER
 * @param {text} pSubKey - Подключ: Указанный подключ должен быть подключем ключа, указанного в параметре pKey.
                                    Этот подключ не должен начинатся и заканчиваться знаком обратной черты ('\').
 * @out param {uuid} id - Идентификатор значения
 * @out param {text} key - Ключ
 * @out param {text} subkey - Подключ
 * @out param {text} valuename - Имя значения
 * @out param {integer} vtype - Тип данных: 0..4
 * @out param {integer} vinteger - Целое число
 * @out param {numeric} vnumeric - Число с произвольной точностью
 * @out param {timestamp} vdatetime - Дата и время
 * @out param {text} vstring - Строка
 * @out param {boolean} vboolean - Логический
 * @return {record}
 */
CREATE OR REPLACE FUNCTION api.registry_enum_value_ex (
  pKey        text,
  pSubKey     text
) RETURNS TABLE (
  id	      uuid,
  key	      text,
  subkey      text,
  valuename   text,
  vtype	      integer,
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
 * Запись в реестр.
 * @param {text} pKey - Ключ: CURRENT_CONFIG | CURRENT_USER
 * @param {text} pSubKey - Подключ: Указанный подключ должен быть подключем ключа, указанного в параметре pKey.
                                    Этот подключ не должен начинатся и заканчиваться знаком обратной черты ('\').
 * @param {text} pValueName - Имя устанавливаемого значения. Если значение с таким именем не существует в ключе реестра, функция его создает.
 * @param {integer} pType - Определяет тип сохраняемых данных значения. Где: 0 - Целое число;
                                                                             1 - Число с произвольной точностью;
                                                                             2 - Дата и время;
                                                                             3 - Строка;
                                                                             4 - Логический.
 * @param {anynonarray} pData - Данные для установки их по указанному имени значения.
 * @return {uuid}
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
 * Чтение из реестра.
 * @param {text} pKey - Ключ: CURRENT_CONFIG | CURRENT_USER
 * @param {text} pSubKey - Подключ: Указанный подключ должен быть подключем ключа, указанного в параметре pKey.
                                    Этот подключ не должен начинатся и заканчиваться знаком обратной черты ('\').
 * @param {text} pValueName - Имя устанавливаемого значения. Если значение с таким именем не существует в ключе реестра, функция его создает.
 * @return {Variant}
 */
CREATE OR REPLACE FUNCTION api.registry_read (
  pKey          text,
  pSubKey       text,
  pValueName	text
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
 * Удаляет подключ и его значения.
 * @param {text} pKey - Ключ: CURRENT_CONFIG | CURRENT_USER
 * @param {text} pSubKey - Подключ: Указанный подключ должен быть подключем ключа, указанного в параметре pKey.
                                    Этот подключ не должен начинатся и заканчиваться знаком обратной черты ('\').
 * @out param {void} result - Результат
 * @out param {text} message - Текст ошибки
 * @return {void}
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
 * Удаляет указанное значение из указанного ключа реестра и подключа.
 * @param {text} pKey - Ключ: CURRENT_CONFIG | CURRENT_USER
 * @param {text} pSubKey - Подключ: Указанный подключ должен быть подключем ключа, указанного в параметре pKey.
                                    Этот подключ не должен начинатся и заканчиваться знаком обратной черты ('\').
 * @param {text} pValueName - Имя удаляемого значения.
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.registry_delete_value (
  pId           uuid,
  pKey          text,
  pSubKey       text,
  pValueName	text
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
 * Удаляет подключи и значения указанного ключа рекурсивно.
 * @param {text} pKey - Ключ: CURRENT_CONFIG | CURRENT_USER
 * @param {text} pSubKey - Подключ: Указанный подключ должен быть подключем ключа, указанного в параметре pKey.
                                    Этот подключ не должен начинатся и заканчиваться знаком обратной черты ('\').
 * @return {void}
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
