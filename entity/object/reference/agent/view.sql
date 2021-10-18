--------------------------------------------------------------------------------
-- Agent -----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Agent (Id, Reference, Code, Name, Description,
  Vendor, VendorCode, VendorName, VendorDescription,
  Scope, ScopeCode, ScopeName, ScopeDescription
)
AS
  SELECT a.id, a.reference, r.code, r.name, r.description, a.vendor,
         v.code, v.name, v.description,
         r.scope, r.scopecode, r.scopename, r.scopedescription
    FROM db.agent a INNER JOIN Reference  r ON a.reference = r.id
                    INNER JOIN Reference  v ON a.vendor = v.id;

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
  Oper, OperCode, OperName, OperDate,
  Scope, ScopeCode, ScopeName, ScopeDescription
)
AS
  SELECT t.id, r.id, r.parent,
         r.entity, r.entitycode, r.entityname,
         r.class, r.classcode, r.classlabel,
         r.type, r.typecode, r.typename, r.typedescription,
         r.code, r.name, r.label, r.description,
         t.vendor, t.vendorcode, t.vendorname, t.vendordescription,
         r.statetype, r.statetypecode, r.statetypename,
         r.state, r.statecode, r.statelabel, r.lastupdate,
         r.owner, r.ownercode, r.ownername, r.created,
         r.oper, r.opercode, r.opername, r.operdate,
         r.scope, r.scopecode, r.scopename, r.scopedescription
    FROM AccessAgent t INNER JOIN ObjectReference r ON t.reference = r.id;

GRANT SELECT ON ObjectAgent TO administrator;
