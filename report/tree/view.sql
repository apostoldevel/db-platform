--------------------------------------------------------------------------------
-- ReportTree ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ReportTree (Id, Reference, Entity, Class, Type,
  Root, Node, Level, Sequence,
  Code, Name, Description,
  Scope, ScopeCode, ScopeName, ScopeDescription
)
AS
  SELECT t.id, t.reference, r.entity, r.class, r.type,
         t.root, t.node, t.level, t.sequence, r.code, r.name, r.description,
         r.scope, r.scopecode, r.scopename, r.scopedescription
    FROM db.report_tree t INNER JOIN Reference r ON t.reference = r.id;

GRANT SELECT ON ReportTree TO administrator;

--------------------------------------------------------------------------------
-- AccessReportTree ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW AccessReportTree
AS
  WITH access AS (
    SELECT * FROM AccessObjectUser(GetEntity('report_tree'), current_userid())
  )
  SELECT r.* FROM ReportTree r INNER JOIN access a ON r.id = a.object;

GRANT SELECT ON AccessReportTree TO administrator;

--------------------------------------------------------------------------------
-- VIEW ObjectReportTree -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectReportTree
AS
  SELECT t.id, r.object, r.parent,
         r.entity, r.entitycode, r.entityname,
         r.class, r.classcode, r.classlabel,
         r.type, r.typecode, r.typename, r.typedescription,
         t.root, t.node, t.level, t.sequence,
         r.code, r.name, r.label, r.description,
         r.statetype, r.statetypecode, r.statetypename,
         r.state, r.statecode, r.statelabel, r.lastupdate,
         r.owner, r.ownercode, r.ownername, r.created,
         r.oper, r.opercode, r.opername, r.operdate,
         r.scope, r.scopecode, r.scopename, r.scopedescription
    FROM AccessReportTree t INNER JOIN ObjectReference r ON t.reference = r.id;
