--------------------------------------------------------------------------------
-- Scheduler -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Scheduler (Id, Reference, Code, Name, Description,
  Period, DateStart, DateStop,
  Scope, ScopeCode, ScopeName, ScopeDescription
)
AS
  SELECT s.id, s.reference, r.code, r.name, r.description,
         s.period, s.dateStart, s.dateStop,
         r.scope, r.scopecode, r.scopename, r.scopedescription
    FROM db.scheduler s INNER JOIN Reference r ON s.reference = r.id;

GRANT SELECT ON Scheduler TO administrator;

--------------------------------------------------------------------------------
-- AccessScheduler -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW AccessScheduler
AS
  WITH access AS (
    SELECT * FROM AccessObjectUser(GetEntity('scheduler'), current_userid())
  )
  SELECT s.* FROM Scheduler s INNER JOIN access ac ON s.id = ac.object;

GRANT SELECT ON AccessScheduler TO administrator;

--------------------------------------------------------------------------------
-- ObjectScheduler -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectScheduler (Id, Object, Parent,
  Entity, EntityCode, EntityName,
  Class, ClassCode, ClassLabel,
  Type, TypeCode, TypeName, TypeDescription,
  Code, Name, Label, Description,
  Period, DateStart, DateStop,
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
         r.code, r.name, r.label, r.description,
         t.period, t.datestart, t.datestop,
         r.statetype, r.statetypecode, r.statetypename,
         r.state, r.statecode, r.statelabel, r.lastupdate,
         r.owner, r.ownercode, r.ownername, r.created,
         r.oper, r.opercode, r.opername, r.operdate,
         r.scope, r.scopecode, r.scopename, r.scopedescription
    FROM AccessScheduler t INNER JOIN ObjectReference r ON t.reference = r.id;

GRANT SELECT ON ObjectScheduler TO administrator;
