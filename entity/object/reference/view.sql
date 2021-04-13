--------------------------------------------------------------------------------
-- Reference -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Reference
AS
  SELECT r.id, r.object, r.entity, r.class, r.type, r.code, rt.name, rt.description,
         r.scope, s.code AS scopecode, s.name AS scopename, s.description AS scopedescription
    FROM db.reference r INNER JOIN db.scope s ON s.id = r.scope
                         LEFT JOIN db.reference_text rt ON r.id = rt.reference AND rt.locale = current_locale()
   WHERE r.scope = current_scope();

GRANT SELECT ON Reference TO administrator;

--------------------------------------------------------------------------------
-- ObjectReference -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectReference (Id, Object, Parent,
  Entity, EntityCode, EntityName,
  Class, ClassCode, ClassLabel,
  Type, TypeCode, TypeName, TypeDescription,
  Code, Name, Label, Description,
  StateType, StateTypeCode, StateTypeName,
  State, StateCode, StateLabel, LastUpdate,
  Owner, OwnerCode, OwnerName, Created,
  Oper, OperCode, OperName, OperDate,
  Scope, ScopeCode, ScopeName, ScopeDescription
)
AS
  SELECT r.id, r.object, o.parent,
         o.entity, o.entitycode, o.entityname,
         o.class, o.classcode, o.classlabel,
         o.type, o.typecode, o.typename, o.typedescription,
         r.code, r.name, o.label, r.description,
         o.statetype, o.statetypecode, o.statetypename,
         o.state, o.statecode, o.statelabel, o.lastupdate,
         o.owner, o.ownercode, o.ownername, o.created,
         o.oper, o.opercode, o.opername, o.operdate,
         r.scope, r.scopecode, r.scopename, r.scopedescription
    FROM Reference r INNER JOIN Object o ON r.object = o.id;

GRANT SELECT ON ObjectReference TO administrator;
