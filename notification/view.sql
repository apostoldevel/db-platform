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
                            LEFT JOIN db.state_type_text ott ON ot.id = ott.type AND ott.locale = current_locale()
                            LEFT JOIN db.state            ns ON n.state_new = ns.id
                            LEFT JOIN db.state_text      nst ON ns.id = nst.state AND nst.locale = current_locale()
                            LEFT JOIN db.state_type       nt ON ns.type = nt.id
                            LEFT JOIN db.state_type_text ntt ON nt.id = ntt.type AND ntt.locale = current_locale();

GRANT SELECT ON Notification TO administrator;

--------------------------------------------------------------------------------
-- VIEW ObjectMethodHistory ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectMethodHistory (Id, Object, DateTime,
  UserId, UserName, FullName, LastName, FirstName, MiddleName,
  Phone, Email, EmailVerified, PhoneVerified, Picture,
  Method, MethodCode, MethodLabel, Action, ActionCode, ActionName, ActionDescription,
  StateOldType, StateOldTypeCode, StateOldTypeName, StateOld, StateOldCode, StateOldLabel,
  StateNewType, StateNewTypeCode, StateNewTypeName, StateNew, StateNewCode, StateNewLabel
)
AS
  SELECT n.id, n.object, n.datetime,
         n.userid, u.username, u.name, p.family_name, p.given_name, p.patronymic_name,
         u.phone, u.email, p.email_verified, p.phone_verified, p.picture,
         n.method, m.code, mt.label, n.action, a.code, at.name, at.description,
         os.type, ot.code, ott.name, n.state_old, os.code, ost.label,
         ns.type, nt.code, ntt.name, n.state_new, ns.code, nst.label
    FROM db.notification n INNER JOIN db.user              u ON n.userid = u.id
                           INNER JOIN db.profile           p ON u.id = p.userid AND p.scope = current_scope()
                           INNER JOIN db.method            m ON n.method = m.id
                            LEFT JOIN db.method_text      mt ON mt.method = m.id AND mt.locale = current_locale()
                           INNER JOIN db.action            a ON n.action = a.id
                            LEFT JOIN db.action_text      at ON at.action = a.id AND at.locale = current_locale()
                            LEFT JOIN db.state            os ON n.state_old = os.id
                            LEFT JOIN db.state_text      ost ON os.id = ost.state AND ost.locale = current_locale()
                            LEFT JOIN db.state_type       ot ON os.type = ot.id
                            LEFT JOIN db.state_type_text ott ON ot.id = ott.type AND ott.locale = current_locale()
                            LEFT JOIN db.state            ns ON n.state_new = ns.id
                            LEFT JOIN db.state_text      nst ON ns.id = nst.state AND nst.locale = current_locale()
                            LEFT JOIN db.state_type       nt ON ns.type = nt.id
                            LEFT JOIN db.state_type_text ntt ON nt.id = ntt.type AND ntt.locale = current_locale();

GRANT SELECT ON ObjectMethodHistory TO administrator;
