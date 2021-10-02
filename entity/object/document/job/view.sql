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

CREATE OR REPLACE VIEW ObjectJob (Id, Object, Parent,
  Entity, EntityCode, EntityName,
  Class, ClassCode, ClassLabel,
  Type, TypeCode, TypeName, TypeDescription,
  Scheduler, SchedulerCode, SchedulerName,
  DateStart, DateStop, Period, DateRun,
  Program, ProgramCode, ProgramName,
  Code, Label, Description,
  StateType, StateTypeCode, StateTypeName,
  State, StateCode, StateLabel, LastUpdate,
  Owner, OwnerCode, OwnerName, Created,
  Oper, OperCode, OperName, OperDate,
  Area, AreaCode, AreaName, AreaDescription,
  Scope, ScopeCode, ScopeName, ScopeDescription
)
AS
  SELECT j.id, d.object, o.parent,
         o.entity, o.entitycode, o.entityname,
         o.class, o.classcode, o.classlabel,
         o.type, o.typecode, o.typename, o.typedescription,
         j.scheduler, j.schedulercode, j.schedulername,
         j.datestart, j.datestop, j.period, j.daterun,
         j.program, j.programcode, j.programname,
         j.code, o.label, d.description,
         o.statetype, o.statetypecode, o.statetypename,
         o.state, o.statecode, o.statelabel, o.lastupdate,
         o.owner, o.ownercode, o.ownername, o.created,
         o.oper, o.opercode, o.opername, o.operdate,
         d.area, d.areacode, d.areaname, d.areadescription,
         d.scope, d.scopecode, d.scopename, d.scopedescription
    FROM Job j INNER JOIN Document d ON j.document = d.id
               INNER JOIN Object   o ON j.document = o.id;

GRANT SELECT ON ObjectJob TO administrator;

--------------------------------------------------------------------------------
-- ServiceJob ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ServiceJob (Id, Object, Parent,
  Entity, EntityCode, EntityName,
  Class, ClassCode, ClassLabel,
  Type, TypeCode, TypeName, TypeDescription,
  Scheduler, SchedulerCode, SchedulerName,
  DateStart, DateStop, Period, DateRun,
  Program, ProgramCode, ProgramName,
  Code, Label, Description,
  StateType, StateTypeCode, StateTypeName,
  State, StateCode, StateLabel, LastUpdate,
  Owner, OwnerCode, OwnerName, Created,
  Oper, OperCode, OperName, OperDate,
  Area, AreaCode, AreaName, AreaDescription,
  Scope, ScopeCode, ScopeName, ScopeDescription
)
AS
  SELECT j.id, d.object, o.parent,
         o.entity, o.entitycode, o.entityname,
         o.class, o.classcode, o.classlabel,
         o.type, o.typecode, o.typename, o.typedescription,
         j.scheduler, j.schedulercode, j.schedulername,
         j.datestart, j.datestop, j.period, j.daterun,
         j.program, j.programcode, j.programname,
         j.code, o.label, d.description,
         o.statetype, o.statetypecode, o.statetypename,
         o.state, o.statecode, o.statelabel, o.lastupdate,
         o.owner, o.ownercode, o.ownername, o.created,
         o.oper, o.opercode, o.opername, o.operdate,
         d.area, d.areacode, d.areaname, d.areadescription,
         d.scope, d.scopecode, d.scopename, d.scopedescription
    FROM Job j INNER JOIN Documents d ON j.document = d.id
               INNER JOIN Object    o ON j.document = o.id;

GRANT SELECT ON ObjectJob TO administrator;
--------------------------------------------------------------------------------
-- VIEW SafeJob ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW SafeJob
AS
  WITH Access AS (
	WITH _membergroup AS (
	  SELECT current_userid() AS userid UNION SELECT userid FROM db.member_group WHERE member = current_userid()
	)
	SELECT a.object
      FROM db.job j INNER JOIN db.aou       a ON j.document = a.object
                    INNER JOIN _membergroup g ON a.userid = g.userid
     GROUP BY a.object
	HAVING (bit_or(a.allow) & ~bit_or(a.deny)) & B'100' = B'100'
  )
  SELECT j.* FROM ObjectJob j INNER JOIN Access a ON j.object = a.object;

GRANT SELECT ON SafeJob TO administrator;
