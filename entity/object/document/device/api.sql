--------------------------------------------------------------------------------
-- DEVICE ----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- VIEW api.device -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.device
AS
  SELECT o.*, g.data::json AS geo
    FROM ObjectDevice o LEFT JOIN db.object_data g ON o.object = g.object AND g.type = 'json' AND g.code = 'geo';

GRANT SELECT ON api.device TO administrator;

--------------------------------------------------------------------------------
-- api.device ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.device (
  pState	uuid
) RETURNS	SETOF api.device
AS $$
  SELECT * FROM api.device WHERE state = pState;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.device ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.device (
  pState	text
) RETURNS	SETOF api.device
AS $$
BEGIN
  RETURN QUERY SELECT * FROM api.device(GetState(GetClass('device'), pState));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION api.add_device -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создает устройтсво.
 * @param {uuid} pParent - Идентификатор родителя | null
 * @param {text} pType - Tип устройства
 * @param {text} pModel - Required. This contains a value that identifies the model of the Device.
 * @param {uuid} pClient - Идентификатор клиента | null
 * @param {text} pIdentity - Строковый идентификатор устройства
 * @param {text} pVersion - Версия.
 * @param {text} pSerial - Серийный номер.
 * @param {text} pAddress - Сетевой адрес.
 * @param {text} piccid - Integrated circuit card identifier (ICCID) — уникальный серийный номер SIM-карты.
 * @param {text} pimsi - International Mobile Subscriber Identity (IMSI) — международный идентификатор мобильного абонента (индивидуальный номер абонента).
 * @param {text} pLabel - Метка
 * @param {text} pDescription - Описание
 * @return {uuid}
 */
CREATE OR REPLACE FUNCTION api.add_device (
  pParent			uuid,
  pType				text,
  pModel			uuid,
  pClient			uuid,
  pIdentity			text,
  pVersion			text default null,
  pSerial			text default null,
  pAddress			text default null,
  piccid			text default null,
  pimsi				text default null,
  pLabel			text default null,
  pDescription		text default null
) RETURNS			uuid
AS $$
BEGIN
  RETURN CreateDevice(pParent, CodeToType(lower(coalesce(pType, 'mobile')), 'device'),
      coalesce(pModel, GetModel('unknown.model')), pClient, coalesce(pIdentity, pSerial), pVersion, pSerial, pAddress, piccid, pimsi, pLabel, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION api.update_device --------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Меняет данные устройства.
 * @param {uuid} pId - Идентификатор зарядной станции (api.get_device)
 * @param {uuid} pParent - Идентификатор родителя | null
 * @param {text} pType - Tип устройства
 * @param {text} pModel - Required. This contains a value that identifies the model of the Device.
 * @param {uuid} pClient - Идентификатор клиента | null
 * @param {text} pIdentity - Строковый идентификатор зарядной станции
 * @param {text} pVersion - Версия.
 * @param {text} pSerial - Серийный номер.
 * @param {text} pAddress - Сетевой адрес.
 * @param {text} piccid - Integrated circuit card identifier (ICCID) — уникальный серийный номер SIM-карты.
 * @param {text} pimsi - International Mobile Subscriber Identity (IMSI) — международный идентификатор мобильного абонента (индивидуальный номер абонента).
 * @param {text} pLabel - Метка
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION api.update_device (
  pId				uuid,
  pParent			uuid default null,
  pType				text default null,
  pModel			uuid default null,
  pClient			uuid default null,
  pIdentity			text default null,
  pVersion			text default null,
  pSerial			text default null,
  pAddress			text default null,
  piccid			text default null,
  pimsi				text default null,
  pLabel			text default null,
  pDescription		text default null
) RETURNS			void
AS $$
DECLARE
  nId				uuid;
  nType				uuid;
BEGIN
  SELECT c.id INTO nId FROM db.device c WHERE c.id = pId;

  IF NOT FOUND THEN
    PERFORM ObjectNotFound('устройство', 'id', pId);
  END IF;

  IF pType IS NOT NULL THEN
    nType := CodeToType(lower(pType), 'device');
  ELSE
    SELECT o.type INTO nType FROM db.object o WHERE o.id = pId;
  END IF;

  PERFORM EditDevice(nId, pParent, nType, pModel, pClient, pIdentity, pVersion, pSerial, pAddress, piccid, pimsi, pLabel, pDescription);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION api.set_device -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.set_device (
  pId				uuid,
  pParent			uuid default null,
  pType				text default null,
  pModel			uuid default null,
  pClient			uuid default null,
  pIdentity			text default null,
  pVersion			text default null,
  pSerial			text default null,
  pAddress			text default null,
  piccid			text default null,
  pimsi				text default null,
  pLabel			text default null,
  pDescription		text default null
) RETURNS			SETOF api.device
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := api.add_device(pParent, pType, pModel, pClient, pIdentity, pVersion, pSerial, pAddress, piccid, pimsi, pLabel, pDescription);
  ELSE
    PERFORM api.update_device(pId, pParent, pType, pModel, pClient, pIdentity, pVersion, pSerial, pAddress, piccid, pimsi, pLabel, pDescription);
  END IF;

  RETURN QUERY SELECT * FROM api.device WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION api.switch_device --------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.switch_device (
  pDevice			uuid,
  pClient			uuid
) RETURNS			void
AS $$
DECLARE
  nClient			uuid;
BEGIN
  SELECT client INTO nClient FROM db.device WHERE id = pDevice;
  IF FOUND AND coalesce(pClient, nClient) <> nClient THEN
    PERFORM SwitchDevice(pDevice, pClient);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION api.init_device ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.init_device (
  pParent			uuid,
  pType				text,
  pModel			text,
  pClient			uuid,
  pIdentity			text,
  pVersion			text default null,
  pSerial			text default null,
  pAddress			text default null,
  piccid			text default null,
  pimsi				text default null,
  pLabel			text default null,
  pDescription		text default null
) RETURNS			SETOF api.device
AS $$
DECLARE
  nId				uuid;
  nModel			uuid;
BEGIN
  pIdentity := coalesce(pIdentity, pSerial);
  nModel := GetModel(pModel);

  SELECT c.id INTO nId FROM db.device c WHERE c.identity = pIdentity;

  IF nId IS NULL THEN
    nId := api.add_device(pParent, pType, nModel, pClient, pIdentity, pVersion, pSerial, pAddress, piccid, pimsi, pLabel, pDescription);
  ELSE
    PERFORM api.switch_device(nId, pClient);
    PERFORM api.update_device(nId, pParent, pType, nModel, pClient, pIdentity, pVersion, pSerial, pAddress, piccid, pimsi, pLabel, pDescription);
  END IF;

  RETURN QUERY SELECT * FROM api.device WHERE id = nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_device --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает устройство по идентификатору
 * @param {uuid} pId - Идентификатор зарядной станции
 * @return {api.device} - Устройство
 */
CREATE OR REPLACE FUNCTION api.get_device (
  pId           uuid
) RETURNS       api.device
AS $$
  SELECT * FROM api.device WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_device --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает устройство по строковому идентификатору
 * @param {uuid} pId - Идентификатор зарядной станции
 * @return {api.device} - Устройство
 */
CREATE OR REPLACE FUNCTION api.get_device (
  pIdentity     text
) RETURNS       api.device
AS $$
  SELECT * FROM api.device WHERE identity = pIdentity
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_device -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список устройств.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.device} - Зарядные станции
 */
CREATE OR REPLACE FUNCTION api.list_device (
  pSearch       jsonb default null,
  pFilter       jsonb default null,
  pLimit        integer default null,
  pOffSet       integer default null,
  pOrderBy      jsonb default null
) RETURNS       SETOF api.device
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'device', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- STATUS NOTIFICATION ---------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- VIEW api.device_notification ------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.device_notification
AS
  SELECT * FROM DeviceNotification;

GRANT SELECT ON api.device_notification TO administrator;

--------------------------------------------------------------------------------
-- api.device_notification -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает уведомления о статусе устройства
 * @param {uuid} pDevice - Идентификатор зарядной станции
 * @param {integer} pInterfaceId - Идентификатор разъёма зарядной станции
 * @param {timestamptz} pDate - Дата и время
 * @return {SETOF api.device_notification}
 */
CREATE OR REPLACE FUNCTION api.device_notification (
  pDevice       uuid,
  pInterfaceId  integer default null,
  pDate         timestamptz default current_timestamp at time zone 'utc'
) RETURNS	    SETOF api.device_notification
AS $$
  SELECT *
    FROM api.device_notification
   WHERE device = pDevice
     AND interfaceId = coalesce(pInterfaceId, interfaceId)
     AND pDate BETWEEN validfromdate AND validtodate
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_device_notification -------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает уведомление о статусе устройства.
 * @param {uuid} pId - Идентификатор
 * @return {api.device_notification}
 */
CREATE OR REPLACE FUNCTION api.get_device_notification (
  pId		uuid
) RETURNS	api.device_notification
AS $$
  SELECT * FROM api.device_notification WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_device_notification ------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает уведомления о статусе устройств.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.device_notification}
 */
CREATE OR REPLACE FUNCTION api.list_device_notification (
  pSearch       jsonb default null,
  pFilter       jsonb default null,
  pLimit        integer default null,
  pOffSet       integer default null,
  pOrderBy      jsonb default null
) RETURNS       SETOF api.device_notification
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'device_notification', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- METER VALUE -----------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- VIEW api.device_value -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.device_value
AS
  SELECT * FROM DeviceValue;

GRANT SELECT ON api.device_value TO administrator;

--------------------------------------------------------------------------------
-- api.get_device_value --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает значение устройства.
 * @param {uuid} pId - Идентификатор
 * @return {api.device_value}
 */
CREATE OR REPLACE FUNCTION api.get_device_value (
  pId		uuid
) RETURNS	api.device_value
AS $$
  SELECT * FROM api.device_value WHERE id = pId
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_device_value -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает значения устройств.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.device_value}
 */
CREATE OR REPLACE FUNCTION api.list_device_value (
  pSearch	jsonb default null,
  pFilter	jsonb default null,
  pLimit	integer default null,
  pOffSet	integer default null,
  pOrderBy	jsonb default null
) RETURNS	SETOF api.device_value
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'device_value', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
