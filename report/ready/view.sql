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
  SELECT o.id, d.object, o.parent,
         o.entity, o.entitycode, o.entityname,
         o.class, o.classcode, o.classlabel,
         o.type, o.typecode, o.typename, o.typedescription,
         r.report, r.reportcode, r.reportname, r.reportdescription,
         r.form, o.label, d.description,
         o.statetype, o.statetypecode, o.statetypename,
         o.state, o.statecode, o.statelabel, o.lastupdate,
         o.owner, o.ownercode, o.ownername, o.created,
         o.oper, o.opercode, o.opername, o.operdate,
         d.area, d.areacode, d.areaname, d.areadescription
    FROM AccessReportReady r INNER JOIN Document d ON r.document = d.id
                             INNER JOIN Object   o ON r.document = o.id;

GRANT SELECT ON ObjectReportReady TO administrator;
