--------------------------------------------------------------------------------
-- Job -------------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Job (Id, Document, Code,
  Scheduler, SchedulerCode, SchedulerName,
  DateStart, DateStop, Period, DateRun,
  Program, ProgramCode, ProgramName,
  Scope, ScopeCode, ScopeName, ScopeDescription
)
AS
  SELECT j.id, j.document, j.code,
         j.scheduler, s.code, s.name,
         s.datestart, s.datestop, s.period, j.daterun,
         j.program, p.code, p.name,
         j.scope, t.code, t.name, t.description
    FROM db.job j INNER JOIN Scheduler s ON j.scheduler = s.id
                  INNER JOIN Program   p ON j.program = p.id
                  INNER JOIN Scope     t ON j.scope = t.id;

GRANT SELECT ON Job TO administrator;

--------------------------------------------------------------------------------
-- AccessJob -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW AccessJob
AS
WITH _access AS (
   WITH _membergroup AS (
	 SELECT current_userid() AS userid UNION SELECT userid FROM db.member_group WHERE member = current_userid()
   ) SELECT object
       FROM db.aou AS a INNER JOIN db.entity    e ON a.entity = e.id AND e.code = 'job'
                        INNER JOIN _membergroup m ON a.userid = m.userid
      WHERE a.mask & B'100' = B'100'
      GROUP BY object
) SELECT t.* FROM db.job t INNER JOIN _access ac ON t.id = ac.object;

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
  Priority, PriorityCode, PriorityName, PriorityDescription,
  Owner, OwnerCode, OwnerName, Created,
  Oper, OperCode, OperName, OperDate,
  Area, AreaCode, AreaName, AreaDescription,
  Scope, ScopeCode, ScopeName, ScopeDescription
) AS
  SELECT t.id, d.object, o.parent,
         o.entity, e.code, et.name,
         o.class, c.code, ct.label,
         o.type, y.code, ty.name, ty.description,
         t.scheduler, srr.code, srt.name,
         sr.datestart, sr.datestop, sr.period, t.daterun,
         t.program, pr.code, prt.name,
         t.code, ot.label, dt.description,
         o.state_type, st.code, stt.name,
         o.state, s.code, sst.label, o.udate,
         d.priority, p.code, pt.name, pt.description,
         o.owner, w.username, w.name, o.pdate,
         o.oper, u.username, u.name, o.ldate,
         d.area, a.code, a.name, a.description,
         o.scope, sc.code, sc.name, sc.description
    FROM AccessJob t INNER JOIN db.document          d ON t.document = d.id
                     INNER JOIN DocumentAreaTree     a ON d.area = a.id
                      LEFT JOIN db.document_text    dt ON dt.document = d.id AND dt.locale = current_locale()
                     INNER JOIN db.priority          p ON d.priority = p.id
                      LEFT JOIN db.priority_text    pt ON pt.priority = p.id AND pt.locale = current_locale()
                     INNER JOIN db.object            o ON t.document = o.id
                      LEFT JOIN db.object_text      ot ON ot.object = o.id AND ot.locale = current_locale()
                     INNER JOIN db.entity            e ON o.entity = e.id
                      LEFT JOIN db.entity_text      et ON et.entity = e.id AND et.locale = current_locale()
                     INNER JOIN db.class_tree        c ON o.class = c.id
                      LEFT JOIN db.class_text       ct ON ct.class = c.id AND ct.locale = current_locale()
                     INNER JOIN db.type              y ON o.type = y.id
                      LEFT JOIN db.type_text        ty ON ty.type = y.id AND ty.locale = current_locale()
                     INNER JOIN db.scheduler        sr ON t.scheduler = sr.id
                     INNER JOIN db.reference       srr ON sr.reference = srr.id
                      LEFT JOIN db.reference_text  srt ON srt.reference = srr.id AND srt.locale = current_locale()
                     INNER JOIN db.reference        pr ON t.program = pr.id
                      LEFT JOIN db.reference_text  prt ON prt.reference = pr.id AND prt.locale = current_locale()
                     INNER JOIN db.state_type       st ON o.state_type = st.id
                      LEFT JOIN db.state_type_text stt ON stt.type = st.id AND stt.locale = current_locale()
                     INNER JOIN db.state             s ON o.state = s.id
                      LEFT JOIN db.state_text      sst ON sst.state = s.id AND sst.locale = current_locale()
                     INNER JOIN db.user              w ON o.owner = w.id
                     INNER JOIN db.user              u ON o.oper = u.id
                     INNER JOIN db.scope            sc ON o.scope = sc.id;

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
  Priority, PriorityCode, PriorityName, PriorityDescription,
  Owner, OwnerCode, OwnerName, Created,
  Oper, OperCode, OperName, OperDate,
  Area, AreaCode, AreaName, AreaDescription,
  Scope, ScopeCode, ScopeName, ScopeDescription
) AS
  SELECT t.id, d.object, o.parent,
         o.entity, e.code, et.name,
         o.class, c.code, ct.label,
         o.type, y.code, ty.name, ty.description,
         t.scheduler, srr.code, srt.name,
         sr.datestart, sr.datestop, sr.period, t.daterun,
         t.program, pr.code, prt.name,
         t.code, ot.label, dt.description,
         o.state_type, st.code, stt.name,
         o.state, s.code, sst.label, o.udate,
         d.priority, p.code, pt.name, pt.description,
         o.owner, w.username, w.name, o.pdate,
         o.oper, u.username, u.name, o.ldate,
         d.area, a.code, a.name, a.description,
         o.scope, sc.code, sc.name, sc.description
    FROM db.job t INNER JOIN db.document          d ON t.document = d.id
                   LEFT JOIN db.document_text    dt ON dt.document = d.id AND dt.locale = current_locale()
                  INNER JOIN db.priority          p ON d.priority = p.id
                   LEFT JOIN db.priority_text    pt ON pt.priority = p.id AND pt.locale = current_locale()
                  INNER JOIN db.object            o ON t.document = o.id
                   LEFT JOIN db.object_text      ot ON ot.object = o.id AND ot.locale = current_locale()
                  INNER JOIN db.entity            e ON o.entity = e.id
                   LEFT JOIN db.entity_text      et ON et.entity = e.id AND et.locale = current_locale()
                  INNER JOIN db.class_tree        c ON o.class = c.id
                   LEFT JOIN db.class_text       ct ON ct.class = c.id AND ct.locale = current_locale()
                  INNER JOIN db.type              y ON o.type = y.id
                   LEFT JOIN db.type_text        ty ON ty.type = y.id AND ty.locale = current_locale()
                  INNER JOIN db.scheduler        sr ON t.scheduler = sr.id
                  INNER JOIN db.reference       srr ON sr.reference = srr.id
                   LEFT JOIN db.reference_text  srt ON srt.reference = srr.id AND srt.locale = current_locale()
                  INNER JOIN db.reference        pr ON t.program = pr.id
                   LEFT JOIN db.reference_text  prt ON prt.reference = pr.id AND prt.locale = current_locale()
                  INNER JOIN db.state_type       st ON o.state_type = st.id
                   LEFT JOIN db.state_type_text stt ON stt.type = st.id AND stt.locale = current_locale()
                  INNER JOIN db.state             s ON o.state = s.id
                   LEFT JOIN db.state_text      sst ON sst.state = s.id AND sst.locale = current_locale()
                  INNER JOIN db.user              w ON o.owner = w.id
                  INNER JOIN db.user              u ON o.oper = u.id
                  INNER JOIN db.area              a ON d.area = a.id
                  INNER JOIN db.scope            sc ON o.scope = sc.id;

GRANT SELECT ON ServiceJob TO administrator;
