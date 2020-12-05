--------------------------------------------------------------------------------
-- DEVICE ----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.device -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.device (
    id                  numeric(12) PRIMARY KEY,
    document            numeric(12) NOT NULL,
    model               numeric(12) NOT NULL,
    client				numeric(12),
    identity            text NOT NULL,
    version             text,
    serial              text,
    address				text,
    iccid               text,
    imsi                text,
    CONSTRAINT fk_device_document FOREIGN KEY (document) REFERENCES db.document(id),
    CONSTRAINT fk_device_client FOREIGN KEY (client) REFERENCES db.client(id)
);

--------------------------------------------------------------------------------

COMMENT ON TABLE db.device IS 'Устройство.';

COMMENT ON COLUMN db.device.id IS 'Идентификатор.';
COMMENT ON COLUMN db.device.document IS 'Документ.';
COMMENT ON COLUMN db.device.model IS 'Идентификатор модели.';
COMMENT ON COLUMN db.device.client IS 'Идентификатор клиента.';
COMMENT ON COLUMN db.device.identity IS 'Строковый идентификатор.';
COMMENT ON COLUMN db.device.version IS 'Версия.';
COMMENT ON COLUMN db.device.serial IS 'Серийный номер.';
COMMENT ON COLUMN db.device.address IS 'Сетевой адрес.';
COMMENT ON COLUMN db.device.iccid IS 'Integrated circuit card identifier (ICCID) — уникальный серийный номер SIM-карты.';
COMMENT ON COLUMN db.device.imsi IS 'International Mobile Subscriber Identity (IMSI) — международный идентификатор мобильного абонента (индивидуальный номер абонента).';

--------------------------------------------------------------------------------

CREATE INDEX ON db.device (document);

CREATE UNIQUE INDEX ON db.device (identity);
CREATE UNIQUE INDEX ON db.device (model, serial);

CREATE INDEX ON db.device (model);
CREATE INDEX ON db.device (client);
CREATE INDEX ON db.device (serial);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_device_before_insert()
RETURNS trigger AS $$
BEGIN
  IF NEW.id IS NULL OR NEW.id = 0 THEN
    SELECT NEW.document INTO NEW.id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_device_before_insert
  BEFORE INSERT ON db.device
  FOR EACH ROW
  EXECUTE PROCEDURE ft_device_before_insert();

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
-- db.status_notification ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.status_notification (
    id              numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_STATUS'),
    device          numeric(12) NOT NULL,
    connectorId     integer NOT NULL,
    status          varchar(50) NOT NULL,
    errorCode       varchar(30) NOT NULL,
    info            text,
    vendorErrorCode	varchar(50),
    validFromDate	timestamp DEFAULT NOW() NOT NULL,
    validToDate		timestamp DEFAULT TO_DATE('4433-12-31', 'YYYY-MM-DD') NOT NULL,
    CONSTRAINT fk_status_notification_device FOREIGN KEY (device) REFERENCES db.device(id)
);

--------------------------------------------------------------------------------

COMMENT ON TABLE db.status_notification IS 'Уведомление о статусе.';

COMMENT ON COLUMN db.status_notification.id IS 'Идентификатор.';
COMMENT ON COLUMN db.status_notification.device IS 'Устройство.';
COMMENT ON COLUMN db.status_notification.connectorId IS 'Required. The id of the connector for which the status is reported. Id "0" (zero) is used if the status is for the Device main controller.';
COMMENT ON COLUMN db.status_notification.status IS 'Required. This contains the current status of the Device.';
COMMENT ON COLUMN db.status_notification.errorCode IS 'Required. This contains the error code reported by the Device.';
COMMENT ON COLUMN db.status_notification.info IS 'Optional. Additional free format information related to the error.';
COMMENT ON COLUMN db.status_notification.vendorErrorCode IS 'Optional. This contains the vendor-specific error code.';
COMMENT ON COLUMN db.status_notification.validFromDate IS 'Дата начала периода действия';
COMMENT ON COLUMN db.status_notification.validToDate IS 'Дата окончания периода действия.';

--------------------------------------------------------------------------------

CREATE INDEX ON db.status_notification (device);
CREATE INDEX ON db.status_notification (connectorId);
CREATE INDEX ON db.status_notification (device, validFromDate, validToDate);

CREATE UNIQUE INDEX ON db.status_notification (device, connectorId, validFromDate, validToDate);

--------------------------------------------------------------------------------
-- FUNCTION AddStatusNotification ----------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddStatusNotification (
  pDevice           numeric,
  pConnectorId		integer,
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
    FROM db.status_notification
   WHERE device = pDevice
     AND connectorId = pConnectorId
     AND validFromDate <= pTimeStamp
     AND validToDate > pTimeStamp;

  IF coalesce(dtDateFrom, MINDATE()) = pTimeStamp THEN
    -- обновим значение в текущем диапозоне дат
    UPDATE db.status_notification
       SET status = pStatus,
           errorCode = pErrorCode,
           info = pInfo,
           vendorErrorCode = pVendorErrorCode
     WHERE device = pDevice
       AND connectorId = pConnectorId
       AND validFromDate <= pTimeStamp
       AND validToDate > pTimeStamp;
  ELSE
    -- обновим дату значения в текущем диапозоне дат
    UPDATE db.status_notification SET validToDate = pTimeStamp
     WHERE device = pDevice
       AND connectorId = pConnectorId
       AND validFromDate <= pTimeStamp
       AND validToDate > pTimeStamp;

    INSERT INTO db.status_notification (device, connectorId, status, errorCode, info, vendorErrorCode, validfromdate, validtodate)
    VALUES (pDevice, pConnectorId, pStatus, pErrorCode, pInfo, pVendorErrorCode, pTimeStamp, coalesce(dtDateTo, MAXDATE()))
    RETURNING id INTO nId;
  END IF;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- StatusNotification ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW StatusNotification
AS
  SELECT * FROM db.status_notification;

GRANT SELECT ON StatusNotification TO administrator;

--------------------------------------------------------------------------------
-- GetJsonStatusNotification ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetJsonStatusNotification (
  pDevice  numeric,
  pConnectorId  integer default null,
  pDate         timestamp default current_timestamp at time zone 'utc'
) RETURNS	    json
AS $$
DECLARE
  arResult	    json[];
  r		        record;
BEGIN
  FOR r IN
    SELECT *
      FROM StatusNotification
     WHERE device = pDevice
       AND connectorid = coalesce(pConnectorId, connectorid)
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
-- db.device_value -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.device_value (
    id			    numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_STATUS'),
    device          numeric(12) NOT NULL,
    type			integer NOT NULL,
    value			jsonb NOT NULL,
    validFromDate	timestamp DEFAULT NOW() NOT NULL,
    validToDate		timestamp DEFAULT TO_DATE('4433-12-31', 'YYYY-MM-DD') NOT NULL,
    CONSTRAINT fk_device_value_device FOREIGN KEY (device) REFERENCES db.device(id)
);

--------------------------------------------------------------------------------

COMMENT ON TABLE db.device_value IS 'Значения устройства.';

COMMENT ON COLUMN db.device_value.id IS 'Идентификатор.';
COMMENT ON COLUMN db.device_value.device IS 'Устройство.';
COMMENT ON COLUMN db.device_value.type IS 'Тип.';
COMMENT ON COLUMN db.device_value.value IS 'Значение.';
COMMENT ON COLUMN db.device_value.validFromDate IS 'Дата начала периода действия';
COMMENT ON COLUMN db.device_value.validToDate IS 'Дата окончания периода действия.';

--------------------------------------------------------------------------------

CREATE INDEX ON db.device_value (device);
CREATE INDEX ON db.device_value (type);

CREATE UNIQUE INDEX ON db.device_value (device, type, validFromDate, validToDate);

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

  IF FOUND THEN
    -- обновим значение в текущем диапозоне дат
    UPDATE db.device_value
       SET Value = pValue
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

--------------------------------------------------------------------------------
-- VIEW DeviceValue ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW DeviceValue
AS
  SELECT * FROM db.device_value;

GRANT SELECT ON DeviceValue TO administrator;

--------------------------------------------------------------------------------
-- Device ----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Device (Id, Document,
  Vendor, VendorCode, VendorName,
  Model, ModelCode, ModelName,
  Client, ClientCode, ClientName,
  Identity, Version, Serial, Address, iccid, imsi
)
AS
  SELECT d.id, d.document,
         m.vendor, m.vendorcode, m.vendorname,
         d.model, m.code, m.name,
         d.client, c.code, c.fullname,
         d.identity, d.version, d.serial, d.address, d.iccid, d.imsi
    FROM db.device d INNER JOIN Model m ON m.id = d.model
                      LEFT JOIN Client c ON c.id = d.client;

GRANT SELECT ON Device TO administrator;

--------------------------------------------------------------------------------
-- AccessDevice ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW AccessDevice
AS
  WITH RECURSIVE access AS (
    SELECT * FROM AccessObjectUser(GetEntity('device'), current_userid())
  )
  SELECT d.* FROM Device d INNER JOIN access ac ON d.id = ac.object;

GRANT SELECT ON AccessDevice TO administrator;

--------------------------------------------------------------------------------
-- ObjectDevice ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectDevice (Id, Object, Parent,
  Entity, EntityCode, EntityName,
  Class, ClassCode, ClassLabel,
  Type, TypeCode, TypeName, TypeDescription,
  Vendor, VendorCode, VendorName,
  Model, ModelCode, ModelName,
  Client, ClientCode, ClientName,
  Identity, Version, Serial, Address, iccid, imsi,
  Label, Description,
  StateType, StateTypeCode, StateTypeName,
  State, StateCode, StateLabel, LastUpdate,
  Owner, OwnerCode, OwnerName, Created,
  Oper, OperCode, OperName, OperDate,
  Area, AreaCode, AreaName, AreaDescription
)
AS
  SELECT t.id, d.object, o.parent,
         o.entity, o.entitycode, o.entityname,
         o.class, o.classcode, o.classlabel,
         o.type, o.typecode, o.typename, o.typedescription,
         t.vendor, t.vendorcode, t.vendorname,
         t.model, t.modelcode, t.modelname,
         t.client, t.clientcode, t.clientname,
         t.identity, t.version, t.serial, t.address, t.iccid, t.imsi,
         o.label, d.description,
         o.statetype, o.statetypecode, o.statetypename,
         o.state, o.statecode, o.statelabel, o.lastupdate,
         o.owner, o.ownercode, o.ownername, o.created,
         o.oper, o.opercode, o.opername, o.operdate,
         d.area, d.areacode, d.areaname, d.areadescription
    FROM AccessDevice t INNER JOIN Document d ON t.document = d.id
                        INNER JOIN Object   o ON t.document = o.id;

GRANT SELECT ON ObjectDevice TO administrator;
