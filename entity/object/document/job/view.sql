--------------------------------------------------------------------------------
-- Job -------------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Job (Id, Document, Code,
  Scheduler, SchedulerCode, SchedulerName,
  DateStart, DateStop, Period, DateRun,
  Program, ProgramCode, ProgramName
)
AS
  SELECT j.id, j.document, j.code,
         j.scheduler, s.code, s.name,
         s.datestart, s.datestop, s.period, j.daterun,
         j.program, p.code, p.name
    FROM db.job j INNER JOIN Scheduler s ON j.scheduler = s.id
                  INNER JOIN Program   p ON j.program = p.id;

GRANT SELECT ON Job TO administrator;

--------------------------------------------------------------------------------
-- AccessJob -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW AccessJob
AS
  WITH access AS (
    SELECT * FROM AccessObjectUser(GetEntity('job'), current_userid())
  )
  SELECT t.* FROM Job t INNER JOIN access ac ON t.id = ac.object;

GRANT SELECT ON AccessJob TO administrator;

--------------------------------------------------------------------------------
-- ObjectJob -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectJob
AS
  SELECT t.id, d.object, d.parent,
         d.entity, d.entitycode, d.entityname,
         d.class, d.classcode, d.classlabel,
         d.type, d.typecode, d.typename, d.typedescription,
         t.scheduler, t.schedulercode, t.schedulername,
         t.datestart, t.datestop, t.period, t.daterun,
         t.program, t.programcode, t.programname,
         t.code, d.label, d.description,
         d.statetype, d.statetypecode, d.statetypename,
         d.state, d.statecode, d.statelabel, d.lastupdate,
         d.owner, d.ownercode, d.ownername, d.created,
         d.oper, d.opercode, d.opername, d.operdate,
         d.area, d.areacode, d.areaname, d.areadescription,
         d.scope, d.scopecode, d.scopename, d.scopedescription
    FROM AccessJob t INNER JOIN ObjectDocument d ON t.document = d.id;

GRANT SELECT ON ObjectJob TO administrator;

--------------------------------------------------------------------------------
-- ServiceJob ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ServiceJob
AS
  SELECT t.id, d.object, o.parent,
         o.entity, o.entitycode, o.entityname,
         o.class, o.classcode, o.classlabel,
         o.type, o.typecode, o.typename, o.typedescription,
         t.scheduler, t.schedulercode, t.schedulername,
         t.datestart, t.datestop, t.period, t.daterun,
         t.program, t.programcode, t.programname,
         t.code, o.label, d.description,
         o.statetype, o.statetypecode, o.statetypename,
         o.state, o.statecode, o.statelabel, o.lastupdate,
         o.owner, o.ownercode, o.ownername, o.created,
         o.oper, o.opercode, o.opername, o.operdate,
         d.area, d.areacode, d.areaname, d.areadescription,
         d.scope, d.scopecode, d.scopename, d.scopedescription
    FROM Job t INNER JOIN Document d ON t.document = d.id
               INNER JOIN Object   o ON t.document = o.id;

GRANT SELECT ON ServiceJob TO administrator;
