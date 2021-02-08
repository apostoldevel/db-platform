--------------------------------------------------------------------------------
-- Vendor ----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Vendor (Id, Reference, Code, Name, Description)
AS
  SELECT v.id, v.reference, d.code, d.name, d.description
    FROM db.vendor v INNER JOIN db.reference d ON v.reference = d.id;

GRANT SELECT ON Vendor TO administrator;

--------------------------------------------------------------------------------
-- AccessVendor ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW AccessVendor
AS
  WITH access AS (
    SELECT * FROM AccessObjectUser(GetEntity('vendor'), current_userid())
  )
  SELECT v.* FROM Vendor v INNER JOIN access ac ON v.id = ac.object;

GRANT SELECT ON AccessVendor TO administrator;

--------------------------------------------------------------------------------
-- ObjectVendor ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectVendor (Id, Object, Parent,
  Entity, EntityCode, EntityName,
  Class, ClassCode, ClassLabel,
  Type, TypeCode, TypeName, TypeDescription,
  Code, Name, Label, Description,
  StateType, StateTypeCode, StateTypeName,
  State, StateCode, StateLabel, LastUpdate,
  Owner, OwnerCode, OwnerName, Created,
  Oper, OperCode, OperName, OperDate
)
AS
  SELECT v.id, r.object, o.parent,
         o.entity, o.entitycode, o.entityname,
         o.class, o.classcode, o.classlabel,
         o.type, o.typecode, o.typename, o.typedescription,
         r.code, r.name, o.label, r.description,
         o.statetype, o.statetypecode, o.statetypename,
         o.state, o.statecode, o.statelabel, o.lastupdate,
         o.owner, o.ownercode, o.ownername, o.created,
         o.oper, o.opercode, o.opername, o.operdate
    FROM AccessVendor v INNER JOIN Reference r ON v.reference = r.id
                        INNER JOIN Object    o ON v.reference = o.id;

GRANT SELECT ON ObjectVendor TO administrator;
