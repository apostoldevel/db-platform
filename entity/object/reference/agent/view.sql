--------------------------------------------------------------------------------
-- Agent -----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Agent (Id, Reference, Code, Name, Description,
  Vendor, VendorCode, VendorName, VendorDescription,
  Scope, ScopeCode, ScopeName, ScopeDescription
)
AS
  SELECT a.id, a.reference, r.code, r.name, r.description, a.vendor,
         v.code, v.name, v.description,
         r.scope, r.scopecode, r.scopename, r.scopedescription
    FROM db.agent a INNER JOIN Reference  r ON a.reference = r.id
                    INNER JOIN Reference  v ON a.vendor = v.id;

GRANT SELECT ON Agent TO administrator;

--------------------------------------------------------------------------------
-- AccessAgent -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW AccessAgent
AS
  WITH access AS (
    SELECT * FROM AccessObjectUser(GetEntity('agent'), current_userid())
  )
  SELECT a.* FROM Agent a INNER JOIN access ac ON a.id = ac.object;

GRANT SELECT ON AccessAgent TO administrator;

--------------------------------------------------------------------------------
-- ObjectAgent -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectAgent (Id, Object, Parent,
  Entity, EntityCode, EntityName,
  Class, ClassCode, ClassLabel,
  Type, TypeCode, TypeName, TypeDescription,
  Vendor, VendorCode, VendorName, VendorDescription,
  Code, Name, Label, Description,
  StateType, StateTypeCode, StateTypeName,
  State, StateCode, StateLabel, LastUpdate,
  Owner, OwnerCode, OwnerName, Created,
  Oper, OperCode, OperName, OperDate,
  Scope, ScopeCode, ScopeName, ScopeDescription
)
AS
  SELECT t.id, r.object, o.parent,
         o.entity, e.code, et.name,
         o.class, c.code, ct.label,
         o.type, y.code, ty.name, ty.description,
         t.vendor, rv.code, rvt.name, rvt.description,
         r.code, rt.name, ot.label, rt.description,
         o.state_type, st.code, stt.name,
         o.state, s.code, sst.label, o.udate,
         o.owner, w.username, w.name, o.pdate,
         o.oper, u.username, u.name, o.ldate,
         o.scope, sc.code, sc.name, sc.description
    FROM db.agent t INNER JOIN db.reference         r ON t.reference = r.id AND r.scope = current_scope()
                     LEFT JOIN db.reference_text   rt ON rt.reference = r.id AND rt.locale = current_locale()
                    INNER JOIN db.object            o ON t.reference = o.id
                     LEFT JOIN db.object_text      ot ON ot.object = o.id AND ot.locale = current_locale()
                    INNER JOIN db.entity            e ON o.entity = e.id
                     LEFT JOIN db.entity_text      et ON et.entity = e.id AND et.locale = current_locale()
                    INNER JOIN db.class_tree        c ON o.class = c.id
                     LEFT JOIN db.class_text       ct ON ct.class = c.id AND ct.locale = current_locale()
                    INNER JOIN db.type              y ON o.type = y.id
                     LEFT JOIN db.type_text        ty ON ty.type = y.id AND ty.locale = current_locale()
                    INNER JOIN db.state_type       st ON o.state_type = st.id
                     LEFT JOIN db.state_type_text stt ON stt.type = st.id AND stt.locale = current_locale()
                    INNER JOIN db.state             s ON o.state = s.id
                     LEFT JOIN db.state_text      sst ON sst.state = s.id AND sst.locale = current_locale()
                    INNER JOIN db.user              w ON o.owner = w.id
                    INNER JOIN db.user              u ON o.oper = u.id
                    INNER JOIN db.scope            sc ON o.scope = sc.id
                     LEFT JOIN db.reference        rv ON t.vendor = rv.id
                     LEFT JOIN db.reference_text  rvt ON rvt.reference = rv.id AND rvt.locale = current_locale();

GRANT SELECT ON ObjectAgent TO administrator;
