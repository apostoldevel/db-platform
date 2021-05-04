--------------------------------------------------------------------------------
-- VIEW Entity -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Entity
AS
  SELECT e.id, e.code, t.name, t.description
    FROM db.entity e LEFT JOIN db.entity_text t ON t.entity = e.id AND t.locale = current_locale();

GRANT SELECT ON Entity TO administrator;

--------------------------------------------------------------------------------
-- VIEW Class ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Class (Id, Parent, Entity, EntityCode, EntityName,
  Level, Code, Label, Abstract
) AS
  SELECT c.id, c.parent, c.entity, e.code, e.name, c.level, c.code, t.label, c.abstract
    FROM db.class_tree c INNER JOIN Entity        e ON e.id = c.entity
                          LEFT JOIN db.class_text t ON t.class = c.id AND t.locale = current_locale();

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
         o.class, c.code, c.label, o.code, t.name, t.description
    FROM db.type o INNER JOIN Class        c ON c.id = o.class
                   INNER JOIN Entity       e ON e.id = c.entity
                    LEFT JOIN db.type_text t ON t.type = o.id AND t.locale = current_locale();

GRANT SELECT ON Type TO administrator;

--------------------------------------------------------------------------------
-- VIEW StateType --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW StateType
AS
  SELECT s.id, s.code, t.name, t.description
    FROM db.state_type s LEFT JOIN db.state_type_text t ON t.type = s.id AND t.locale = current_locale();

GRANT SELECT ON StateType TO administrator;

--------------------------------------------------------------------------------
-- VIEW State ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW State (Id, Class, ClassCode, ClassLabel,
  Type, TypeCode, TypeName, Code, Label, Sequence
)
AS
  SELECT s.id, s.class, c.code, c.label, s.type,
         st.code, st.name, s.code, t.label, s.sequence
    FROM db.state s INNER JOIN StateType    st ON st.id = s.type
                    INNER JOIN Class         c ON c.id = s.class
                     LEFT JOIN db.state_text t ON t.state = s.id AND t.locale = current_locale();

GRANT SELECT ON State TO administrator;

--------------------------------------------------------------------------------
-- VIEW Action -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Action
AS
  SELECT a.id, a.code, t.name, t.description
    FROM db.action a LEFT JOIN db.action_text t ON t.action = a.id AND t.locale = current_locale();

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
         m.code, t.label, m.sequence, m.visible
    FROM db.method m INNER JOIN Class          c ON c.id = m.class
                     INNER JOIN Action         a ON a.id = m.action
                      LEFT JOIN State          s ON s.id = m.state
                      LEFT JOIN db.method_text t ON t.method = m.id AND t.locale = current_locale();

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
  SELECT e.id, e.code, t.name, t.description
    FROM db.event_type e LEFT JOIN db.event_type_text t ON t.type = e.id AND t.locale = current_locale();

GRANT SELECT ON EventType TO administrator;

--------------------------------------------------------------------------------
-- VIEW Event ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Event (Id, Class, Type, TypeCode, TypeName,
  Action, ActionCode, ActionName, Label, Text, Sequence, Enabled
)
AS
  SELECT e.id, e.class, e.type, et.code, et.name, e.action, a.code, a.name,
         t.label, e.text, e.sequence, e.enabled
    FROM db.event e INNER JOIN EventType     et ON et.id = e.type
                    INNER JOIN Action        a ON a.id = e.action
                     LEFT JOIN db.event_text t ON t.event = e.id AND t.locale = current_locale();

GRANT SELECT ON Event TO administrator;
