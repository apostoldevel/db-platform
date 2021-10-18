--------------------------------------------------------------------------------
-- Program ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Program (Id, Reference,
  Code, Name, Description, Body,
  Scope, ScopeCode, ScopeName, ScopeDescription
) AS
  SELECT p.id, p.reference, r.code, r.name, r.description, p.body,
         r.scope, r.scopecode, r.scopename, r.scopedescription
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
  SELECT t.id, r.object, r.parent,
         r.entity, r.entitycode, r.entityname,
         r.class, r.classcode, r.classlabel,
         r.type, r.typecode, r.typename, r.typedescription,
         r.code, r.name, r.label, r.description, t.body,
         r.statetype, r.statetypecode, r.statetypename,
         r.state, r.statecode, r.statelabel, r.lastupdate,
         r.owner, r.ownercode, r.ownername, r.created,
         r.oper, r.opercode, r.opername, r.operdate,
         r.scope, r.scopecode, r.scopename, r.scopedescription
    FROM AccessProgram t INNER JOIN ObjectReference r ON t.reference = r.id;

GRANT SELECT ON ObjectProgram TO administrator;
