--------------------------------------------------------------------------------
-- Agent -----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Agent (Id, Reference, Code, Name, Description,
    Vendor, VendorCode, VendorName, VendorDescription
)
AS
  SELECT a.id, a.reference, mr.code, mr.name, mr.description, a.vendor,
         vr.code, vr.name, vr.description
    FROM db.agent a INNER JOIN db.reference mr ON a.reference = mr.id
                    INNER JOIN db.reference vr ON a.vendor = vr.id;

GRANT SELECT ON Agent TO administrator;

--------------------------------------------------------------------------------
-- AccessAgent -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW AccessAgent
AS
  WITH access AS (
    SELECT * FROM AccessObjectUser(GetEntity('agent'), current_userid())
  )
  SELECT a.* FROM Agent a INNER JOIN access ac ON a.id = ac.object;

GRANT SELECT ON AccessAgent TO administrator;

--------------------------------------------------------------------------------
-- ObjectAgent -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectAgent (Id, Object, Parent,
  Entity, EntityCode, EntityName,
  Class, ClassCode, ClassLabel,
  Type, TypeCode, TypeName, TypeDescription,
  Code, Name, Label, Description,
  Vendor, VendorCode, VendorName, VendorDescription,
  StateType, StateTypeCode, StateTypeName,
  State, StateCode, StateLabel, LastUpdate,
  Owner, OwnerCode, OwnerName, Created,
  Oper, OperCode, OperName, OperDate
)
AS
  SELECT a.id, r.object, o.parent,
         o.entity, o.entitycode, o.entityname,
         o.class, o.classcode, o.classlabel,
         o.type, o.typecode, o.typename, o.typedescription,
         r.code, r.name, o.label, r.description,
         a.vendor, a.vendorcode, a.vendorname, a.vendordescription,
         o.statetype, o.statetypecode, o.statetypename,
         o.state, o.statecode, o.statelabel, o.lastupdate,
         o.owner, o.ownercode, o.ownername, o.created,
         o.oper, o.opercode, o.opername, o.operdate
    FROM AccessAgent a INNER JOIN Reference r ON a.reference = r.id
                       INNER JOIN Object    o ON a.reference = o.id;

GRANT SELECT ON ObjectAgent TO administrator;
