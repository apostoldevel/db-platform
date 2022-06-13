--------------------------------------------------------------------------------
-- VIEW Notification -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Notification (Id, DateTime, UserId, Object,
  Entity, EntityCode, Class, ClassCode, Action, ActionCode, Method, MethodCode,
  StateOld, StateOldType, StateOldCode, StateOldLabel,
  StateNew, StateNewType, StateNewCode, StateNewLabel
)
AS
  SELECT n.id, n.datetime, n.userid, n.object,
         n.entity, e.code, n.class, c.code, n.action, a.code, n.method, m.code,
         n.state_old, os.type, os.code, ost.label,
         n.state_new, ns.type, ns.code, nst.label
    FROM db.notification n INNER JOIN db.entity       e ON n.entity = e.id
                           INNER JOIN db.class_tree   c ON n.class = c.id
                           INNER JOIN db.action       a ON n.action = a.id
                           INNER JOIN db.method       m ON n.method = m.id
                           INNER JOIN db.state       os ON n.state_old = os.id
                            LEFT JOIN db.state_text ost ON os.id = ost.state
                           INNER JOIN db.state       ns ON n.state_new = ns.id
                            LEFT JOIN db.state_text nst ON ns.id = nst.state;

GRANT SELECT ON Notification TO administrator;
