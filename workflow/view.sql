--------------------------------------------------------------------------------
-- VIEW Entity -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Entity
AS
  SELECT * FROM db.entity;

GRANT SELECT ON Entity TO administrator;

--------------------------------------------------------------------------------
-- VIEW Class ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Class (Id, Parent, Entity, EntityCode, EntityName, Level, Code,
  Label, Abstract)
AS
  SELECT c.id, c.parent, c.entity, t.code, t.name, c.level, c.code, c.label, c.abstract
    FROM db.class_tree c INNER JOIN db.entity t ON t.id = c.entity;

GRANT SELECT ON Class TO administrator;

--------------------------------------------------------------------------------
-- VIEW ClassTree --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ClassTree
AS
  WITH RECURSIVE tree AS (
    SELECT *, ARRAY[row_number() OVER (ORDER BY level, code)] AS sortlist FROM Class WHERE parent IS NULL
    UNION ALL
      SELECT c.*, array_append(t.sortlist, row_number() OVER (ORDER BY c.level, c.code))
        FROM Class c INNER JOIN tree t ON c.parent = t.id
    )
    SELECT * FROM tree
     ORDER BY sortlist;

GRANT SELECT ON ClassTree TO administrator;

--------------------------------------------------------------------------------
-- VIEW ClassMembers -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ClassMembers
AS
  SELECT class, userid, deny::int, allow::int, mask::int, u.type, username, name, description
    FROM db.acu a INNER JOIN db.user u ON u.id = a.userid;

GRANT SELECT ON ClassMembers TO administrator;

--------------------------------------------------------------------------------
-- VIEW Type -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Type (Id, Entity, EntityCode, EntityName,
  Class, ClassCode, ClassLabel, Code, Name, Description
)
AS
  SELECT o.id, c.entity, e.code, e.name,
         o.class, c.code, c.label, o.code, o.name, o.description
    FROM db.type o INNER JOIN db.class_tree c ON c.id = o.class
                   INNER JOIN db.entity e ON e.id = c.entity;

GRANT SELECT ON Type TO administrator;

--------------------------------------------------------------------------------
-- VIEW StateType --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW StateType
AS
  SELECT * FROM db.state_type;

GRANT SELECT ON StateType TO administrator;

--------------------------------------------------------------------------------
-- VIEW State ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW State (Id, Class, ClassCode, ClassLabel,
    Type, TypeCode, TypeName, Code, Label, Sequence
)
AS
  SELECT s.id, s.class, c.code, c.label, s.type,
         t.code, t.name, s.code, s.label, s.sequence
    FROM db.state s INNER JOIN db.state_type t ON t.id = s.type
                    INNER JOIN db.class_tree c on c.id = s.class;

GRANT SELECT ON State TO administrator;

--------------------------------------------------------------------------------
-- VIEW Action -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Action
AS
  SELECT * FROM db.action;

GRANT SELECT ON Action TO administrator;

--------------------------------------------------------------------------------
-- VIEW Method -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Method (Id, Parent,
  Class, ClassCode, ClassLabel,
  State, StateCode, StateLabel,
  Action, ActionCode, ActionName,
  Code, Label, Sequence, Visible
)
AS
  SELECT m.id, m.parent,
         m.class, c.code, c.label,
         m.state, s.code, s.label,
         m.action, a.code, a.name,
         m.code, m.label, m.sequence, m.visible
    FROM db.method m INNER JOIN db.class_tree c ON c.id = m.class
                     INNER JOIN db.action a ON a.id = m.action
                      LEFT JOIN db.state s ON s.id = m.state;

GRANT SELECT ON Method TO administrator;

--------------------------------------------------------------------------------
-- VIEW MethodMembers ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW MethodMembers
AS
  SELECT method, userid, deny::int, allow::int, mask::int, u.type, username, name, description
    FROM db.amu a INNER JOIN db.user u ON u.id = a.userid;

GRANT SELECT ON MethodMembers TO administrator;

--------------------------------------------------------------------------------
-- VIEW Transition -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Transition (Id,
  State, StateTypeCode, StateTypeName, StateCode, StateLabel,
  Method, MethodCode, MethodLabel, ActionCode, ActionName,
  NewState, NewStateTypeCode, NewStateTypeName, NewStateCode, NewStateLabel
)
AS
  SELECT st.id,
         os.id, os.typecode, os.typename, os.code, os.label,
         cm.id, cm.code, cm.label, cm.actioncode, cm.actionname,
         ns.id, ns.typecode, ns.typename, ns.code, ns.label
    FROM db.transition st  LEFT JOIN State  os ON os.id = st.state
                          INNER JOIN Method cm ON cm.id = st.method
                          INNER JOIN State  ns ON ns.id = st.newstate;

GRANT SELECT ON Transition TO administrator;

--------------------------------------------------------------------------------
-- VIEW EventType --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW EventType
AS
  SELECT * FROM db.event_type;

GRANT SELECT ON EventType TO administrator;

--------------------------------------------------------------------------------
-- VIEW Event ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Event (Id, Class, Type, TypeCode, TypeName,
  Action, ActionCode, ActionName, Label, Text, Sequence, Enabled
)
AS
  SELECT el.id, el.class, el.type, et.code, et.name, el.action, al.code, al.name,
         el.label, el.text, el.sequence, el.enabled
    FROM db.event el INNER JOIN db.event_type et ON et.id = el.type
                     INNER JOIN db.action al ON al.id = el.action;

GRANT SELECT ON Event TO administrator;

