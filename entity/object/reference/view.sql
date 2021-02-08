--------------------------------------------------------------------------------
-- Reference -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Reference
AS
  SELECT * FROM db.reference;

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
  Oper, OperCode, OperName, OperDate
)
AS
  SELECT r.id, r.object, o.parent,
         r.entity, e.code, e.name,
         r.class, ct.code, ct.label,
         o.type, t.code, t.name, t.description,
         r.code, r.name, o.label, r.description,
         o.state_type, st.code, st.name,
         o.state, s.code, s.label, o.udate,
         o.owner, w.username, w.name, o.pdate,
         o.oper, u.username, u.name, o.ldate
    FROM db.reference r INNER JOIN db.entity     e ON r.entity = e.id
                        INNER JOIN db.class_tree ct ON r.class = ct.id
                        INNER JOIN db.object      o ON r.object = o.id
                        INNER JOIN db.type        t ON o.type = t.id
                        INNER JOIN db.state_type st ON o.state_type = st.id
                        INNER JOIN db.state       s ON o.state = s.id
                        INNER JOIN db.user        w ON o.owner = w.id
                        INNER JOIN db.user        u ON o.oper = u.id;

GRANT SELECT ON ObjectReference TO administrator;
