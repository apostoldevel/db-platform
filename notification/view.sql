--------------------------------------------------------------------------------
-- VIEW Notification -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Notification (Id, DateTime, UserId, Object,
  Entity, EntityCode, Class, ClassCode, Action, ActionCode, Method, MethodCode,
  StateOld, StateOldType, StateOldTypeCode, StateOldTypeName, StateOldCode, StateOldLabel,
  StateNew, StateNewType, StateNewTypeCode, StateNewTypeName, StateNewCode, StateNewLabel
)
AS
  SELECT n.id, n.datetime, n.userid, n.object,
         n.entity, e.code, n.class, c.code, n.action, a.code, n.method, m.code,
         n.state_old, os.type, ot.code, ott.name, os.code, ost.label,
         n.state_new, ns.type, nt.code, ntt.name, ns.code, nst.label
    FROM db.notification n INNER JOIN db.entity            e ON n.entity = e.id
                           INNER JOIN db.class_tree        c ON n.class = c.id
                           INNER JOIN db.action            a ON n.action = a.id
                           INNER JOIN db.method            m ON n.method = m.id
                            LEFT JOIN db.state            os ON n.state_old = os.id
                            LEFT JOIN db.state_text      ost ON os.id = ost.state AND ost.locale = current_locale()
                            LEFT JOIN db.state_type       ot ON os.type = ot.id
                            LEFT JOIN db.state_type_text ott ON ot.id = ott.type AND ost.locale = current_locale()
                            LEFT JOIN db.state            ns ON n.state_new = ns.id
                            LEFT JOIN db.state_text      nst ON ns.id = nst.state AND ost.locale = current_locale()
                            LEFT JOIN db.state_type       nt ON ns.type = nt.id
                            LEFT JOIN db.state_type_text ntt ON nt.id = ntt.type AND ost.locale = current_locale();

GRANT SELECT ON Notification TO administrator;
