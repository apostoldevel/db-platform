--------------------------------------------------------------------------------
-- DeviceNotification ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW DeviceNotification
AS
  SELECT * FROM db.device_notification;

GRANT SELECT ON DeviceNotification TO administrator;

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
  WITH access AS (
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
