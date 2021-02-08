--------------------------------------------------------------------------------
-- Scheduler -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Scheduler (Id, Reference, Code, Name, Description,
  Period, DateStart, DateStop
)
AS
  SELECT s.id, s.reference, d.code, d.name, d.description,
         s.period, s.dateStart, s.dateStop
    FROM db.scheduler s INNER JOIN db.reference d ON s.reference = d.id;

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
  Oper, OperCode, OperName, OperDate
)
AS
  SELECT s.id, r.object, o.parent,
         o.entity, o.entitycode, o.entityname,
         o.class, o.classcode, o.classlabel,
         o.type, o.typecode, o.typename, o.typedescription,
         r.code, r.name, o.label, r.description,
         s.period, s.datestart, s.datestop,
         o.statetype, o.statetypecode, o.statetypename,
         o.state, o.statecode, o.statelabel, o.lastupdate,
         o.owner, o.ownercode, o.ownername, o.created,
         o.oper, o.opercode, o.opername, o.operdate
    FROM AccessScheduler s INNER JOIN Reference r ON s.reference = r.id
                           INNER JOIN Object    o ON s.reference = o.id;

GRANT SELECT ON ObjectScheduler TO administrator;
