--------------------------------------------------------------------------------
-- Model -----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Model (Id, Reference, Code, Name, Description,
    Vendor, VendorCode, VendorName, VendorDescription,
    Category, CategoryCode, CategoryName, CategoryDescription
)
AS
  SELECT m.id, m.reference, r.code, r.name, r.description,
         m.vendor, v.code, v.name, v.description,
         m.category, c.code, c.name, c.description
    FROM db.model m INNER JOIN Reference r ON m.reference = r.id
                    INNER JOIN Reference v ON m.vendor = v.id
                     LEFT JOIN Reference c ON m.category = c.id;

GRANT SELECT ON Model TO administrator;

--------------------------------------------------------------------------------
-- AccessModel -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW AccessModel
AS
  WITH access AS (
    SELECT * FROM AccessObjectUser(GetEntity('model'), current_userid())
  )
  SELECT m.* FROM Model m INNER JOIN access ac ON m.id = ac.object;

GRANT SELECT ON AccessModel TO administrator;

--------------------------------------------------------------------------------
-- ObjectModel -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectModel (Id, Object, Parent,
  Entity, EntityCode, EntityName,
  Class, ClassCode, ClassLabel,
  Type, TypeCode, TypeName, TypeDescription,
  Vendor, VendorCode, VendorName, VendorDescription,
  Category, CategoryCode, CategoryName, CategoryDescription,
  Code, Name, Label, Description,
  StateType, StateTypeCode, StateTypeName,
  State, StateCode, StateLabel, LastUpdate,
  Owner, OwnerCode, OwnerName, Created,
  Oper, OperCode, OperName, OperDate
)
AS
  SELECT m.id, r.object, o.parent,
         o.entity, o.entitycode, o.entityname,
         o.class, o.classcode, o.classlabel,
         o.type, o.typecode, o.typename, o.typedescription,
         m.vendor, m.vendorcode, m.vendorname, m.vendordescription,
         m.category, m.categorycode, m.categoryname, m.categorydescription,
         r.code, r.name, o.label, r.description,
         o.statetype, o.statetypecode, o.statetypename,
         o.state, o.statecode, o.statelabel, o.lastupdate,
         o.owner, o.ownercode, o.ownername, o.created,
         o.oper, o.opercode, o.opername, o.operdate
    FROM AccessModel m INNER JOIN Reference r ON m.reference = r.id
                       INNER JOIN Object    o ON m.reference = o.id;

GRANT SELECT ON ObjectModel TO administrator;
