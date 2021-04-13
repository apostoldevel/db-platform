--------------------------------------------------------------------------------
-- Version ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Version (Id, Reference, Code, Name, Description)
AS
  SELECT v.id, v.reference, d.code, d.name, d.description
    FROM db.version v INNER JOIN Reference d ON v.reference = d.id;

GRANT SELECT ON Version TO administrator;

--------------------------------------------------------------------------------
-- AccessVersion ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW AccessVersion
AS
  WITH access AS (
    SELECT * FROM AccessObjectUser(GetEntity('version'), current_userid())
  )
  SELECT v.* FROM Version v INNER JOIN access ac ON v.id = ac.object;

GRANT SELECT ON AccessVersion TO administrator;

--------------------------------------------------------------------------------
-- ObjectVersion ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectVersion (Id, Object, Parent,
  Entity, EntityCode, EntityName,
  Class, ClassCode, ClassLabel,
  Type, TypeCode, TypeName, TypeDescription,
  Code, Name, Label, Description,
  StateType, StateTypeCode, StateTypeName,
  State, StateCode, StateLabel, LastUpdate,
  Owner, OwnerCode, OwnerName, Created,
  Oper, OperCode, OperName, OperDate,
  Scope, ScopeCode, ScopeName, ScopeDescription
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
         o.oper, o.opercode, o.opername, o.operdate,
         r.scope, r.scopecode, r.scopename, r.scopedescription
    FROM AccessVersion v INNER JOIN Reference r ON v.reference = r.id
                         INNER JOIN Object    o ON v.reference = o.id;

GRANT SELECT ON ObjectVersion TO administrator;
