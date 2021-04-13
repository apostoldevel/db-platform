--------------------------------------------------------------------------------
-- Program ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Program (Id, Reference, Code, Name, Description, Body)
AS
  SELECT p.id, p.reference, r.code, r.name, r.description, p.body
    FROM db.program p INNER JOIN Reference r ON p.reference = r.id;

GRANT SELECT ON Program TO administrator;

--------------------------------------------------------------------------------
-- AccessProgram ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW AccessProgram
AS
  WITH access AS (
    SELECT * FROM AccessObjectUser(GetEntity('program'), current_userid())
  )
  SELECT p.* FROM Program p INNER JOIN access ac ON p.id = ac.object;

GRANT SELECT ON AccessProgram TO administrator;

--------------------------------------------------------------------------------
-- ObjectProgram ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectProgram (Id, Object, Parent,
  Entity, EntityCode, EntityName,
  Class, ClassCode, ClassLabel,
  Type, TypeCode, TypeName, TypeDescription,
  Code, Name, Label, Description, Body,
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
         r.code, r.name, o.label, r.description, p.body,
         o.statetype, o.statetypecode, o.statetypename,
         o.state, o.statecode, o.statelabel, o.lastupdate,
         o.owner, o.ownercode, o.ownername, o.created,
         o.oper, o.opercode, o.opername, o.operdate,
         r.scope, r.scopecode, r.scopename, r.scopedescription
    FROM AccessProgram p INNER JOIN Reference r ON p.reference = r.id
                         INNER JOIN Object    o ON p.reference = o.id;

GRANT SELECT ON ObjectProgram TO administrator;
