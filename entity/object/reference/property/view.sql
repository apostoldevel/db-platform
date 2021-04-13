--------------------------------------------------------------------------------
-- Property --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Property (Id, Reference,
  Type, TypeCode, TypeName, TypeDescription,
  Code, Name, Description
) AS
  SELECT p.id, p.reference,
         r.type, t.code, t.name, t.description,
         r.code, r.name, r.description
    FROM db.property p INNER JOIN Reference r ON r.id = p.reference
                       INNER JOIN db.type   t ON t.id = r.type;

GRANT SELECT ON Property TO administrator;

--------------------------------------------------------------------------------
-- AccessProperty --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW AccessProperty
AS
  WITH access AS (
    SELECT * FROM AccessObjectUser(GetEntity('property'), current_userid())
  )
  SELECT c.* FROM Property c INNER JOIN access ac ON c.id = ac.object;

GRANT SELECT ON AccessProperty TO administrator;

--------------------------------------------------------------------------------
-- ObjectProperty --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectProperty (Id, Object, Parent,
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
  SELECT p.id, r.object, o.parent,
         o.entity, o.entitycode, o.entityname,
         o.class, o.classcode, o.classlabel,
         o.type, o.typecode, o.typename, o.typedescription,
         r.code, r.name, o.label, r.description,
         o.statetype, o.statetypecode, o.statetypename,
         o.state, o.statecode, o.statelabel, o.lastupdate,
         o.owner, o.ownercode, o.ownername, o.created,
         o.oper, o.opercode, o.opername, o.operdate,
         r.scope, r.scopecode, r.scopename, r.scopedescription
    FROM AccessProperty p INNER JOIN Reference r ON p.reference = r.id
                          INNER JOIN Object    o ON p.reference = o.id;

GRANT SELECT ON ObjectProperty TO administrator;
