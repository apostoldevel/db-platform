--------------------------------------------------------------------------------
-- ReportRoutine ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ReportRoutine (Id, Reference, Entity, Class, Type,
  Report, ReportCode, ReportName, ReportDescription,
  Code, Name, Description, Definition,
  Scope, ScopeCode, ScopeName, ScopeDescription
)
AS
  SELECT f.id, f.reference, r.entity, r.class, r.type,
         f.report, p.code, p.name, p.description,
         r.code, r.name, r.description, f.definition,
         r.scope, r.scopecode, r.scopename, r.scopedescription
    FROM db.report_routine f INNER JOIN Reference r ON r.id = f.reference
                             INNER JOIN Report    p ON p.id = f.report;

GRANT SELECT ON ReportRoutine TO administrator;

--------------------------------------------------------------------------------
-- AccessReportRoutine ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW AccessReportRoutine
AS
  WITH access AS (
    SELECT * FROM AccessObjectUser(GetEntity('report_routine'), current_userid())
  )
  SELECT r.* FROM ReportRoutine r INNER JOIN access a ON r.id = a.object;

GRANT SELECT ON AccessReportRoutine TO administrator;

--------------------------------------------------------------------------------
-- ObjectReportRoutine ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectReportRoutine
AS
  SELECT t.id, r.object, r.parent,
         r.entity, r.entitycode, r.entityname,
         r.class, r.classcode, r.classlabel,
         r.type, r.typecode, r.typename, r.typedescription,
         t.report, t.reportcode, t.reportname, t.reportdescription,
         r.code, r.name, r.label, r.description, t.definition,
         r.statetype, r.statetypecode, r.statetypename,
         r.state, r.statecode, r.statelabel, r.lastupdate,
         r.owner, r.ownercode, r.ownername, r.created,
         r.oper, r.opercode, r.opername, r.operdate,
         r.scope, r.scopecode, r.scopename, r.scopedescription
    FROM AccessReportRoutine t INNER JOIN ObjectReference r ON t.reference = r.id;

GRANT SELECT ON ObjectReportRoutine TO administrator;
