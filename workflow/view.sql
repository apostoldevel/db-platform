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

CREATE OR REPLACE VIEW Class (Id, Parent,
  Entity, EntityCode, EntityName,
  Level, Code, Label, Abstract
) AS
  SELECT c.id, c.parent,
         c.entity, e.code, et.name,
         c.level, c.code, ct.label, c.abstract
    FROM db.class_tree c INNER JOIN db.entity       e ON c.entity = e.id
                          LEFT JOIN db.entity_text et ON et.entity = e.id AND et.locale = current_locale()
                          LEFT JOIN db.class_text  ct ON ct.class = c.id AND ct.locale = current_locale();

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
-- FUNCTION ClassTree ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ClassTree (
  pParent   uuid
) RETURNS   SETOF ClassTree
AS $$
  WITH RECURSIVE tree AS (
    SELECT *, ARRAY[row_number() OVER (ORDER BY level, code)] AS sortlist FROM Class WHERE parent IS NOT DISTINCT FROM pParent
    UNION ALL
      SELECT c.*, array_append(t.sortlist, row_number() OVER (ORDER BY c.level, c.code))
        FROM Class c INNER JOIN tree t ON c.parent = t.id
    )
    SELECT * FROM tree
     ORDER BY sortlist;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

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

CREATE OR REPLACE VIEW Type (Id,
  Entity, EntityCode, EntityName,
  Class, ClassCode, ClassLabel,
  Code, Name, Description
)
AS
  SELECT o.id,
         c.entity, e.code, et.name,
         o.class, c.code, ct.label,
         o.code, tt.name, tt.description
    FROM db.type o INNER JOIN db.class_tree   c ON o.class = c.id
                    LEFT JOIN db.class_text  ct ON ct.class = c.id AND ct.locale = current_locale()
                   INNER JOIN db.entity       e ON c.entity = e.id
                    LEFT JOIN db.entity_text et ON et.entity = e.id AND et.locale = current_locale()
                    LEFT JOIN db.type_text   tt ON tt.type = o.id AND tt.locale = current_locale();

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

CREATE OR REPLACE VIEW State (Id,
  Entity, EntityCode, EntityName,
  Class, ClassCode, ClassLabel,
  Type, TypeCode, TypeName,
  Code, Label, Sequence
)
AS
  SELECT s.id,
         c.entity, e.code, et.name,
         s.class, c.code, ct.label,
         s.type, t.code, stt.name,
         s.code, st.label, s.sequence
    FROM db.state s INNER JOIN db.state_type        t ON s.type = t.id
                     LEFT JOIN db.state_type_text stt ON stt.type = t.id AND stt.locale = current_locale()
                    INNER JOIN db.class_tree        c ON s.class = c.id
                     LEFT JOIN db.class_text       ct ON ct.class = c.id AND ct.locale = current_locale()
                    INNER JOIN db.entity            e ON c.entity = e.id
                     LEFT JOIN db.entity_text      et ON et.entity = e.id AND et.locale = current_locale()
                     LEFT JOIN db.state_text       st ON st.state = s.id AND st.locale = current_locale();

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
  Entity, EntityCode, EntityName,
  Class, ClassCode, ClassLabel,
  State, StateCode, StateLabel,
  Action, ActionCode, ActionName,
  Code, Label, Sequence
)
AS
  SELECT m.id, m.parent,
         c.entity, e.code, et.name,
         m.class, c.code, ct.label,
         m.state, s.code, st.label,
         m.action, a.code, at.name,
         m.code, mt.label, m.sequence
    FROM db.method m INNER JOIN db.class_tree   c ON m.class = c.id
                      LEFT JOIN db.class_text  ct ON ct.class = c.id AND ct.locale = current_locale()
                     INNER JOIN db.entity       e ON c.entity = e.id
                      LEFT JOIN db.entity_text et ON et.entity = e.id AND et.locale = current_locale()
                     INNER JOIN db.action       a ON a.id = m.action
                      LEFT JOIN db.action_text at ON at.action = a.id AND at.locale = current_locale()
                      LEFT JOIN db.state        s ON s.id = m.state
                      LEFT JOIN db.state_text  st ON st.state = s.id AND st.locale = current_locale()
                      LEFT JOIN db.method_text mt ON mt.method = m.id AND mt.locale = current_locale();

GRANT SELECT ON Method TO administrator;

--------------------------------------------------------------------------------
-- VIEW AccessMethod -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW AccessMethod (Id, Parent,
  Entity, EntityCode, EntityName,
  Class, ClassCode, ClassLabel,
  State, StateCode, StateLabel,
  Action, ActionCode, ActionName,
  Code, Label, Sequence,
  Execute, Visible, Enable
)
AS
  WITH _access AS (
    SELECT a.method, bit_or(a.allow) & ~bit_or(a.deny) AS mask
      FROM db.amu a
     WHERE userid IN (SELECT current_userid() UNION SELECT userid FROM db.member_group WHERE member = current_userid())
     GROUP BY a.method
  )
  SELECT m.id, m.parent,
         c.entity, e.code, et.name,
         m.class, c.code, ct.label,
         m.state, s.code, st.label,
         m.action, a.code, at.name,
         m.code, mt.label, m.sequence,
         ac.mask & B'100' = B'100' AS execute, ac.mask & B'010' = B'010' AS visible, ac.mask & B'001' = B'001' AS enable
    FROM db.method m INNER JOIN _access        ac ON m.id = ac.method
                     INNER JOIN db.class_tree   c ON m.class = c.id
                      LEFT JOIN db.class_text  ct ON ct.class = c.id AND ct.locale = current_locale()
                     INNER JOIN db.entity       e ON c.entity = e.id
                      LEFT JOIN db.entity_text et ON et.entity = e.id AND et.locale = current_locale()
                     INNER JOIN db.action       a ON a.id = m.action
                      LEFT JOIN db.action_text at ON at.action = a.id AND at.locale = current_locale()
                      LEFT JOIN db.state        s ON s.id = m.state
                      LEFT JOIN db.state_text  st ON st.state = s.id AND st.locale = current_locale()
                      LEFT JOIN db.method_text mt ON mt.method = m.id AND mt.locale = current_locale();

GRANT SELECT ON AccessMethod TO administrator;

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

--------------------------------------------------------------------------------
-- VIEW AMU --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW AMU
AS
  SELECT m.class, m.classcode, m.classlabel,
         m.action, m.actioncode, m.actionname,
         a.method, m.code, m.label,
         a.userid, u.type, u.username, u.name, u.description,
         a.deny, a.allow, a.mask
    FROM db.amu a INNER JOIN Method  m ON a.method = m.id
                  INNER JOIN db.user u ON a.userid = u.id;

GRANT SELECT ON AMU TO administrator;

--------------------------------------------------------------------------------
-- VIEW Priority ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Priority
AS
  SELECT p.id, p.code, t.name, t.description
    FROM db.priority p LEFT JOIN db.priority_text t ON t.priority = p.id AND t.locale = current_locale();

GRANT SELECT ON Action TO administrator;
