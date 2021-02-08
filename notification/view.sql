--------------------------------------------------------------------------------
-- VIEW Notification -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Notification (Id, DateTime, UserId, Object,
  Entity, EntityCode, Class, ClassCode, Action, ActionCode, Method, MethodCode
)
AS
  SELECT n.id, n.datetime, n.userid, n.object,
         n.entity, e.code, n.class, c.code, n.action, a.code, n.method, m.code
    FROM db.notification n INNER JOIN db.entity     e ON n.entity = e.id
                           INNER JOIN db.class_tree c ON n.class = c.id
                           INNER JOIN db.action     a ON n.action = a.id
                           INNER JOIN db.method     m ON n.method = m.id;

GRANT SELECT ON Notification TO administrator;
