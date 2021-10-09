--------------------------------------------------------------------------------
-- ReportRoutine ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ReportRoutine (Id, Reference, Entity, Class, Type,
  Report, ReportCode, ReportName, ReportDescription,
  Code, Name, Description, Definition
)
AS
  SELECT f.id, f.reference, r.entity, r.class, r.type,
         f.report, p.code, p.name, p.description,
         r.code, r.name, r.description, f.definition
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
  SELECT t.id, r.object, o.parent,
         o.entity, o.entitycode, o.entityname,
         o.class, o.classcode, o.classlabel,
         o.type, o.typecode, o.typename, o.typedescription,
         t.report, t.reportcode, t.reportname, t.reportdescription,
         r.code, r.name, o.label, r.description, t.definition,
         o.statetype, o.statetypecode, o.statetypename,
         o.state, o.statecode, o.statelabel, o.lastupdate,
         o.owner, o.ownercode, o.ownername, o.created,
         o.oper, o.opercode, o.opername, o.operdate,
         r.scope, r.scopecode, r.scopename, r.scopedescription
    FROM AccessReportRoutine t INNER JOIN Reference r ON t.reference = r.id
                               INNER JOIN Object    o ON t.reference = o.id;

GRANT SELECT ON ObjectReportRoutine TO administrator;
