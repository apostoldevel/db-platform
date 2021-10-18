--------------------------------------------------------------------------------
-- ReportForm ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ReportForm (Id, Reference, Entity, Class, Type,
  Code, Name, Description, Definition,
  Scope, ScopeCode, ScopeName, ScopeDescription
)
AS
  SELECT f.id, f.reference, r.entity, r.class, r.type,
         r.code, r.name, r.description, f.definition,
         r.scope, r.scopecode, r.scopename, r.scopedescription
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
  SELECT t.id, r.object, r.parent,
         r.entity, r.entitycode, r.entityname,
         r.class, r.classcode, r.classlabel,
         r.type, r.typecode, r.typename, r.typedescription,
         r.code, r.name, r.label, r.description, t.definition,
         r.statetype, r.statetypecode, r.statetypename,
         r.state, r.statecode, r.statelabel, r.lastupdate,
         r.owner, r.ownercode, r.ownername, r.created,
         r.oper, r.opercode, r.opername, r.operdate,
         r.scope, r.scopecode, r.scopename, r.scopedescription
    FROM AccessReportForm t INNER JOIN ObjectReference r ON t.reference = r.id;

GRANT SELECT ON ObjectReportForm TO administrator;
