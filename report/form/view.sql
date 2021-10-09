--------------------------------------------------------------------------------
-- ReportForm ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ReportForm (Id, Reference, Entity, Class, Type,
  Code, Name, Description, Definition
)
AS
  SELECT f.id, f.reference, r.entity, r.class, r.type,
         r.code, r.name, r.description, f.definition
    FROM db.report_form f INNER JOIN Reference r ON r.id = f.reference;

GRANT SELECT ON ReportForm TO administrator;

--------------------------------------------------------------------------------
-- AccessReportForm ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW AccessReportForm
AS
  WITH access AS (
    SELECT * FROM AccessObjectUser(GetEntity('report_form'), current_userid())
  )
  SELECT r.* FROM ReportForm r INNER JOIN access a ON r.id = a.object;

GRANT SELECT ON AccessReportForm TO administrator;

--------------------------------------------------------------------------------
-- ObjectReportForm ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectReportForm
AS
  SELECT f.id, r.object, o.parent,
         o.entity, o.entitycode, o.entityname,
         o.class, o.classcode, o.classlabel,
         o.type, o.typecode, o.typename, o.typedescription,
         r.code, r.name, o.label, r.description, f.definition,
         o.statetype, o.statetypecode, o.statetypename,
         o.state, o.statecode, o.statelabel, o.lastupdate,
         o.owner, o.ownercode, o.ownername, o.created,
         o.oper, o.opercode, o.opername, o.operdate,
         r.scope, r.scopecode, r.scopename, r.scopedescription
    FROM AccessReportForm f INNER JOIN Reference r ON f.reference = r.id
                            INNER JOIN Object    o ON f.reference = o.id;

GRANT SELECT ON ObjectReportForm TO administrator;
