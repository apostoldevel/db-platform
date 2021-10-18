--------------------------------------------------------------------------------
-- ReportReady -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ReportReady (Id, Document, Form,
  Report, ReportCode, ReportName, ReportDescription
)
AS
  SELECT r.id, r.document, r.form,
         r.report, t.code, t.name, t.description
    FROM db.report_ready r INNER JOIN Report t ON r.report = t.id;

GRANT SELECT ON ReportReady TO administrator;

--------------------------------------------------------------------------------
-- AccessReportReady -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW AccessReportReady
AS
  WITH access AS (
    SELECT * FROM AccessObjectUser(GetEntity('report_ready'), current_userid())
  )
  SELECT r.* FROM ReportReady r INNER JOIN access a ON r.id = a.object;

GRANT SELECT ON AccessReportReady TO administrator;

--------------------------------------------------------------------------------
-- ObjectReportReady -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectReportReady
AS
  SELECT t.id, d.object, d.parent,
         d.entity, d.entitycode, d.entityname,
         d.class, d.classcode, d.classlabel,
         d.type, d.typecode, d.typename, d.typedescription,
         t.report, t.reportcode, t.reportname, t.reportdescription,
         t.form, d.label, d.description,
         d.statetype, d.statetypecode, d.statetypename,
         d.state, d.statecode, d.statelabel, d.lastupdate,
         d.owner, d.ownercode, d.ownername, d.created,
         d.oper, d.opercode, d.opername, d.operdate,
         d.area, d.areacode, d.areaname, d.areadescription
    FROM AccessReportReady t INNER JOIN ObjectDocument d ON t.document = d.id;

GRANT SELECT ON ObjectReportReady TO administrator;
