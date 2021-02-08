--------------------------------------------------------------------------------
-- CreateDevice ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateDevice (
  pParent			numeric,
  pType				numeric,
  pModel			numeric,
  pClient			numeric,
  pIdentity			text,
  pVersion			text,
  pSerial			text default null,
  pAddress			text default null,
  piccid			text default null,
  pimsi				text default null,
  pLabel			text default null,
  pDescription		text default null
) RETURNS			numeric
AS $$
DECLARE
  nDocument			numeric;
  nClass			numeric;
  nMethod			numeric;
BEGIN
  SELECT class INTO nClass FROM db.type WHERE id = pType;

  IF GetEntityCode(nClass) <> 'device' THEN
    PERFORM IncorrectClassType();
  END IF;

  SELECT id INTO nDocument FROM db.device WHERE identity = pIdentity;

  IF found THEN
    PERFORM DeviceExists(pIdentity);
  END IF;

  nDocument := CreateDocument(pParent, pType, coalesce(pLabel, pIdentity), pDescription);

  INSERT INTO db.device (id, document, model, client, identity, version, serial, address, iccid, imsi)
  VALUES (nDocument, nDocument, pModel, pClient, pIdentity, pVersion, pSerial, pAddress, piccid, pimsi);

  nMethod := GetMethod(nClass, null, GetAction('create'));
  PERFORM ExecuteMethod(nDocument, nMethod);

  RETURN nDocument;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditDevice ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditDevice (
  pId				numeric,
  pParent			numeric default null,
  pType				numeric default null,
  pModel			numeric default null,
  pClient			numeric default null,
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
  nDocument			numeric;
  vIdentity			text;

  nClass			numeric;
  nMethod			numeric;
BEGIN
  SELECT identity INTO vIdentity FROM db.device WHERE id = pId;
  IF vIdentity <> coalesce(pIdentity, vIdentity) THEN
    SELECT id INTO nDocument FROM db.device WHERE identity = pIdentity;
    IF found THEN
      PERFORM DeviceExists(pIdentity);
    END IF;
  END IF;

  PERFORM EditDocument(pId, pParent, pType, pLabel, pDescription);

  UPDATE db.device
     SET model = coalesce(pModel, model),
         client = CheckNull(coalesce(pClient, client, 0)),
         identity = coalesce(pIdentity, identity),
         version = CheckNull(coalesce(pVersion, version, '<null>')),
         serial = CheckNull(coalesce(pSerial, serial, '<null>')),
         address = CheckNull(coalesce(pAddress, address, '<null>')),
         iccid = CheckNull(coalesce(piccid, iccid, '<null>')),
         imsi = CheckNull(coalesce(pimsi, imsi, '<null>'))
   WHERE id = pId;

  SELECT class INTO nClass FROM db.type WHERE id = pType;

  nMethod := GetMethod(nClass, null, GetAction('edit'));
  PERFORM ExecuteMethod(pId, nMethod);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetDevice -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetDevice (
  pIdentity text
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM db.device WHERE identity = pIdentity;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SwitchDevice ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SwitchDevice (
  pDevice	numeric,
  pClient	numeric
) RETURNS	void
AS $$
DECLARE
  nUserId	numeric;
BEGIN
  nUserId := GetClientUserId(pClient);
  IF nUserId IS NOT NULL THEN
    UPDATE db.device SET client = pClient WHERE id = pDevice;
    PERFORM SetObjectOwner(pDevice, nUserId);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION AddDeviceNotification ----------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddDeviceNotification (
  pDevice           numeric,
  pInterfaceId		integer,
  pStatus		    text,
  pErrorCode		text,
  pInfo			    text,
  pVendorErrorCode	text,
  pTimeStamp		timestamp
) RETURNS 		    numeric
AS $$
DECLARE
  nId			    numeric;

  dtDateFrom 		timestamp;
  dtDateTo 		    timestamp;
BEGIN
  -- получим дату значения в текущем диапозоне дат
  SELECT validFromDate, validToDate INTO dtDateFrom, dtDateTo
    FROM db.device_notification
   WHERE device = pDevice
     AND interfaceId = pInterfaceId
     AND validFromDate <= pTimeStamp
     AND validToDate > pTimeStamp;

  IF coalesce(dtDateFrom, MINDATE()) = pTimeStamp THEN
    -- обновим значение в текущем диапозоне дат
    UPDATE db.device_notification
       SET status = pStatus,
           errorCode = pErrorCode,
           info = pInfo,
           vendorErrorCode = pVendorErrorCode
     WHERE device = pDevice
       AND interfaceId = pInterfaceId
       AND validFromDate <= pTimeStamp
       AND validToDate > pTimeStamp;
  ELSE
    -- обновим дату значения в текущем диапозоне дат
    UPDATE db.device_notification SET validToDate = pTimeStamp
     WHERE device = pDevice
       AND interfaceId = pInterfaceId
       AND validFromDate <= pTimeStamp
       AND validToDate > pTimeStamp;

    INSERT INTO db.device_notification (device, interfaceId, status, errorCode, info, vendorErrorCode, validfromdate, validtodate)
    VALUES (pDevice, pInterfaceId, pStatus, pErrorCode, pInfo, pVendorErrorCode, pTimeStamp, coalesce(dtDateTo, MAXDATE()))
    RETURNING id INTO nId;
  END IF;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetJsonDeviceNotification ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetJsonDeviceNotification (
  pDevice		numeric,
  pInterfaceId  integer default null,
  pDate         timestamp default current_timestamp at time zone 'utc'
) RETURNS	    json
AS $$
DECLARE
  arResult	    json[];
  r		        record;
BEGIN
  FOR r IN
    SELECT *
      FROM DeviceNotification
     WHERE device = pDevice
       AND interfaceId = coalesce(pInterfaceId, interfaceId)
       AND validFromDate <= pDate
       AND validToDate > pDate
  LOOP
    arResult := array_append(arResult, row_to_json(r));
  END LOOP;

  RETURN array_to_json(arResult);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION AddDeviceValue -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddDeviceValue (
  pDevice           numeric,
  pType				integer,
  pValue			jsonb,
  pTimeStamp		timestamp default now()
) RETURNS 		    numeric
AS $$
DECLARE
  nId			    numeric;

  dtDateFrom 		timestamp;
  dtDateTo 		    timestamp;
BEGIN
  -- получим дату значения в текущем диапозоне дат
  SELECT validFromDate, validToDate INTO dtDateFrom, dtDateTo
    FROM db.device_value
   WHERE device = pDevice
     AND type = pType
     AND validFromDate <= pTimeStamp
     AND validToDate > pTimeStamp;

  IF coalesce(dtDateFrom, MINDATE()) = pTimeStamp THEN
    -- обновим значение в текущем диапозоне дат
    UPDATE db.device_value
       SET value = pValue
     WHERE device = pDevice
       AND type = pType
       AND validFromDate <= pTimeStamp
       AND validToDate > pTimeStamp;
  ELSE
    -- обновим дату значения в текущем диапозоне дат
    UPDATE db.device_value SET validToDate = pTimeStamp
     WHERE device = pDevice
       AND type = pType
       AND validFromDate <= pTimeStamp
       AND validToDate > pTimeStamp;

    INSERT INTO db.device_value (device, type, value, validfromdate, validtodate)
    VALUES (pDevice, pType, pValue, pTimeStamp, coalesce(dtDateTo, MAXDATE()))
    RETURNING id INTO nId;
  END IF;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
