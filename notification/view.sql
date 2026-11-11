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
/**
 * @brief Method journal of objects with the user who ran each method.
 * @note Since 1.2.40 the contacts of that user (username, phone, email, their
 *       verification flags, picture) are given to an administrator and to the
 *       user himself; for anyone else they are NULL. The user id and the name
 *       stay. The check sits in the select list, so a read bounded by object or
 *       date keeps its plan; a read that filters, searches or sorts on a contact
 *       column compares the masked value and scans the journal.
 * @since 1.0.0
 */
CREATE OR REPLACE VIEW ObjectMethodHistory (Id, Object, DateTime,
  UserId, UserName, FullName, LastName, FirstName, MiddleName,
  Phone, Email, EmailVerified, PhoneVerified, Picture,
  Method, MethodCode, MethodLabel, Action, ActionCode, ActionName, ActionDescription,
  StateOldType, StateOldTypeCode, StateOldTypeName, StateOld, StateOldCode, StateOldLabel,
  StateNewType, StateNewTypeCode, StateNewTypeName, StateNew, StateNewCode, StateNewLabel
)
AS
  SELECT n.id, n.object, n.datetime,
         n.userid,
         CASE WHEN (SELECT IsAdmin()) OR n.userid = (SELECT current_userid()) THEN u.username END,
         u.name, p.family_name, p.given_name, p.patronymic_name,
         CASE WHEN (SELECT IsAdmin()) OR n.userid = (SELECT current_userid()) THEN u.phone END,
         CASE WHEN (SELECT IsAdmin()) OR n.userid = (SELECT current_userid()) THEN u.email END,
         CASE WHEN (SELECT IsAdmin()) OR n.userid = (SELECT current_userid()) THEN p.email_verified END,
         CASE WHEN (SELECT IsAdmin()) OR n.userid = (SELECT current_userid()) THEN p.phone_verified END,
         CASE WHEN (SELECT IsAdmin()) OR n.userid = (SELECT current_userid()) THEN p.picture END,
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
