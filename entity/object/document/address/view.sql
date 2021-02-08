--------------------------------------------------------------------------------
-- Address ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Address
AS
  SELECT * FROM db.address;

GRANT SELECT ON Address TO administrator;

--------------------------------------------------------------------------------
-- AccessAddress ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW AccessAddress
AS
  WITH access AS (
    SELECT * FROM AccessObjectUser(GetEntity('address'), current_userid())
  )
  SELECT a.* FROM Address a INNER JOIN access ac ON a.id = ac.object;

GRANT SELECT ON AccessAddress TO administrator;

--------------------------------------------------------------------------------
-- ObjectAddress ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectAddress (Id, Object, Parent,
  Entity, EntityCode, EntityName,
  Class, ClassCode, ClassLabel,
  Type, TypeCode, TypeName, TypeDescription,
  Code, Index, Country, Region, District, City, Settlement, Street, House, Building, Structure, Apartment, SortNum,
  Label, Description,
  StateType, StateTypeCode, StateTypeName,
  State, StateCode, StateLabel, LastUpdate,
  Owner, OwnerCode, OwnerName, Created,
  Oper, OperCode, OperName, OperDate,
  Area, AreaCode, AreaName, AreaDescription
) AS
  SELECT a.id, d.object, o.parent,
         o.entity, o.entitycode, o.entityname,
         o.class, o.classcode, o.classlabel,
         o.type, o.typecode, o.typename, o.typedescription,
         a.code, a.index, a.country, a.region, a.district, a.city, a.settlement, a.street, a.house, a.building, a.structure, a.apartment, a.sortnum,
         o.label, d.description,
         o.statetype, o.statetypecode, o.statetypename,
         o.state, o.statecode, o.statelabel, o.lastupdate,
         o.owner, o.ownercode, o.ownername, o.created,
         o.oper, o.opercode, o.opername, o.operdate,
         d.area, d.areacode, d.areaname, d.areadescription
    FROM AccessAddress a INNER JOIN Document d ON a.document = d.id
                         INNER JOIN Object   o ON a.document = o.id;

GRANT SELECT ON ObjectAddress TO administrator;

--------------------------------------------------------------------------------
-- ObjectAddresses -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectAddresses (Id, Object, Address, TypeCode,
    Code, Index, Country, Region, District, City, Settlement, Street, House,
    Building, Structure, Apartment, SortNum,
    ValidFromDate, ValidToDate
)
AS
  SELECT ol.id, ol.object, ol.linked, ol.key,
         a.code, a.index, a.country, a.region, a.district, a.city, a.settlement, a.street, a.house,
         a.building, a.structure, a.apartment, a.sortnum,
         ol.validFromDate, ol.validToDate
    FROM db.object_link ol INNER JOIN db.address a ON ol.linked = a.id;

GRANT SELECT ON ObjectAddresses TO administrator;
