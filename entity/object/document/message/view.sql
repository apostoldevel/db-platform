--------------------------------------------------------------------------------
-- Message ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Message
AS
  SELECT t.id, o.parent, t.document,
         o.class, ct.code AS ClassCode, ctt.label AS ClassLabel,
         o.type, y.code AS TypeCode, ty.name AS TypeName, ty.description AS TypeDescription,
         o.state_type AS StateType, st.code AS StateTypeCode, stt.name AS StateTypeName,
         o.state, s.code AS StateCode, sst.label AS StateLabel,
         ar.type AS AgentType, ay.code AS AgentTypeCode, aty.name AS AgentTypeName, aty.description AS AgentTypeDescription,
         t.agent, ar.code AS AgentCode, art.name AS AgentName, art.description AS AgentDescription,
         o.pdate AS Created, o.udate AS LastUpdate, o.ldate AS OperDate,
         t.code, ot.label AS Name, ot.label, dt.description,
         t.profile, t.address, t.subject, t.content
    FROM db.message t INNER JOIN db.object            o ON o.id = t.document
                       LEFT JOIN db.object_text      ot ON ot.object = t.document AND ot.locale = current_locale()
                       LEFT JOIN db.document_text    dt ON dt.document = t.document AND dt.locale = current_locale()

                      INNER JOIN db.class_tree       ct ON o.class = ct.id
                       LEFT JOIN db.class_text      ctt ON ctt.class = ct.id AND ctt.locale = current_locale()

                      INNER JOIN db.type              y ON y.id = o.type
                       LEFT JOIN db.type_text        ty ON ty.type = y.id AND ty.locale = current_locale()

                      INNER JOIN db.state_type       st ON o.state_type = st.id
                       LEFT JOIN db.state_type_text stt ON stt.type = st.id AND stt.locale = current_locale()

                      INNER JOIN db.state             s ON o.state = s.id
                       LEFT JOIN db.state_text      sst ON sst.state = s.id AND sst.locale = current_locale()

                      INNER JOIN db.reference        ar ON t.agent = ar.id
                       LEFT JOIN db.reference_text  art ON art.reference = ar.id AND art.locale = current_locale()

                      INNER JOIN db.type             ay ON ar.type = ay.id
                       LEFT JOIN db.type_text       aty ON aty.type = ay.id AND aty.locale = current_locale();

GRANT SELECT ON Message TO administrator;

--------------------------------------------------------------------------------
-- AccessMessage ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW AccessMessage
AS
WITH _membergroup AS (
  SELECT current_userid() AS userid UNION SELECT userid FROM db.member_group WHERE member = current_userid()
) SELECT object
	FROM db.message t INNER JOIN db.aou         a ON a.object = t.id
					  INNER JOIN _membergroup   m ON a.userid = m.userid
   WHERE a.mask = B'100'
   GROUP BY object;

GRANT SELECT ON AccessMessage TO administrator;

--------------------------------------------------------------------------------
-- ObjectMessage ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectMessage (Id, Object, Parent,
  Entity, EntityCode, EntityName,
  Class, ClassCode, ClassLabel,
  Type, TypeCode, TypeName, TypeDescription,
  StateType, StateTypeCode, StateTypeName,
  State, StateCode, StateLabel,
  Created, LastUpdate, OperDate,
  Code, Name, Label, Description,
  AgentType, AgentTypeCode, AgentTypeName, AgentTypeDescription,
  Agent, AgentCode, AgentName, AgentDescription,
  Profile, Address, Subject, Content,
  Priority, PriorityCode, PriorityName, PriorityDescription,
  Owner, OwnerCode, OwnerName,
  Oper, OperCode, OperName,
  Area, AreaCode, AreaName, AreaDescription,
  Scope, ScopeCode, ScopeName, ScopeDescription
) AS
  SELECT t.id, d.object, o.parent,
         o.entity, e.code, et.name,
         o.class, ct.code, ctt.label,
         o.type, y.code, ty.name, ty.description,
         o.state_type, st.code, stt.name,
         o.state, s.code, sst.label,
         o.pdate, o.udate, o.ldate,
         t.code, ot.label,ot.label, dt.description,
         ar.type, ay.code, aty.name, aty.description,
         t.agent, ar.code, art.name, art.description,
         t.profile, t.address, t.subject, t.content,
         d.priority, p.code, pt.name, pt.description,
         o.owner, w.username, w.name,
         o.oper, u.username, u.name,
         d.area, a.code, a.name, a.description,
         o.scope, sc.code, sc.name, sc.description
    FROM db.message    t INNER JOIN db.document          d ON t.document = d.id
                          LEFT JOIN db.document_text    dt ON dt.document = d.id AND dt.locale = current_locale()

                         INNER JOIN db.object            o ON t.document = o.id
                          LEFT JOIN db.object_text      ot ON ot.object = o.id AND ot.locale = current_locale()

                         INNER JOIN db.entity            e ON o.entity = e.id
                          LEFT JOIN db.entity_text      et ON et.entity = e.id AND et.locale = current_locale()

                         INNER JOIN db.class_tree       ct ON o.class = ct.id
                          LEFT JOIN db.class_text      ctt ON ctt.class = ct.id AND ctt.locale = current_locale()

                         INNER JOIN db.type              y ON o.type = y.id
                          LEFT JOIN db.type_text        ty ON ty.type = y.id AND ty.locale = current_locale()

                         INNER JOIN db.state_type       st ON o.state_type = st.id
                          LEFT JOIN db.state_type_text stt ON stt.type = st.id AND stt.locale = current_locale()

                         INNER JOIN db.state             s ON o.state = s.id
                          LEFT JOIN db.state_text      sst ON sst.state = s.id AND sst.locale = current_locale()

                         INNER JOIN db.priority          p ON d.priority = p.id
                          LEFT JOIN db.priority_text    pt ON pt.priority = p.id AND pt.locale = current_locale()

                         INNER JOIN db.reference        ar ON t.agent = ar.id
                          LEFT JOIN db.reference_text  art ON art.reference = ar.id AND art.locale = current_locale()

                         INNER JOIN db.type             ay ON ar.type = ay.id
                          LEFT JOIN db.type_text       aty ON aty.type = ay.id AND aty.locale = current_locale()

                         INNER JOIN db.user              w ON o.owner = w.id
                         INNER JOIN db.user              u ON o.oper = u.id

                         INNER JOIN DocumentAreaTree     a ON d.area = a.id
                         INNER JOIN db.scope            sc ON o.scope = sc.id;

GRANT SELECT ON ObjectMessage TO administrator;

--------------------------------------------------------------------------------
-- ServiceMessage --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ServiceMessage (Id, Object, Parent,
  Entity, EntityCode, EntityName,
  Class, ClassCode, ClassLabel,
  Type, TypeCode, TypeName, TypeDescription,
  AgentType, AgentTypeCode, AgentTypeName, AgentTypeDescription,
  Agent, AgentCode, AgentName, AgentDescription,
  Code, Profile, Address, Subject, Content,
  Label, Description,
  StateType, StateTypeCode, StateTypeName,
  State, StateCode, StateLabel, LastUpdate,
  Priority, PriorityCode, PriorityName, PriorityDescription,
  Owner, OwnerCode, OwnerName, Created,
  Oper, OperCode, OperName, OperDate,
  Area, AreaCode, AreaName, AreaDescription,
  Scope, ScopeCode, ScopeName, ScopeDescription
) AS
  SELECT t.id, d.object, o.parent,
         o.entity, e.code, et.name,
         o.class, c.code, ct.label,
         o.type, y.code, ty.name, ty.description,
         ar.type, ay.code, aty.name, aty.description,
         t.agent, ar.code, art.name, art.description,
         t.code, t.profile, t.address, t.subject, t.content,
         ot.label, dt.description,
         o.state_type, st.code, stt.name,
         o.state, s.code, sst.label, o.udate,
         d.priority, p.code, pt.name, pt.description,
         o.owner, w.username, w.name, o.pdate,
         o.oper, u.username, u.name, o.ldate,
         d.area, a.code, a.name, a.description,
         o.scope, sc.code, sc.name, sc.description
    FROM db.message t INNER JOIN db.document          d ON t.document = d.id
                       LEFT JOIN db.document_text    dt ON dt.document = d.id AND dt.locale = current_locale()

                      INNER JOIN db.object            o ON t.document = o.id
                       LEFT JOIN db.object_text      ot ON ot.object = o.id AND ot.locale = current_locale()

                      INNER JOIN db.reference        ar ON t.agent = ar.id
                       LEFT JOIN db.reference_text  art ON art.reference = ar.id AND art.locale = current_locale()

                      INNER JOIN db.type             ay ON ar.type = ay.id
                       LEFT JOIN db.type_text       aty ON aty.type = ay.id AND aty.locale = current_locale()

                      INNER JOIN db.entity            e ON o.entity = e.id
                       LEFT JOIN db.entity_text      et ON et.entity = e.id AND et.locale = current_locale()

                      INNER JOIN db.class_tree        c ON o.class = c.id
                       LEFT JOIN db.class_text       ct ON ct.class = c.id AND ct.locale = current_locale()

                      INNER JOIN db.type              y ON o.type = y.id
                       LEFT JOIN db.type_text        ty ON ty.type = y.id AND ty.locale = current_locale()

                      INNER JOIN db.state_type       st ON o.state_type = st.id
                       LEFT JOIN db.state_type_text stt ON stt.type = st.id AND stt.locale = current_locale()

                      INNER JOIN db.state             s ON o.state = s.id
                       LEFT JOIN db.state_text      sst ON sst.state = s.id AND sst.locale = current_locale()

                      INNER JOIN db.priority          p ON d.priority = p.id
                       LEFT JOIN db.priority_text    pt ON pt.priority = p.id AND pt.locale = current_locale()

                      INNER JOIN db.user              w ON o.owner = w.id
                      INNER JOIN db.user              u ON o.oper = u.id

                      INNER JOIN DocumentAreaTree     a ON d.area = a.id
                      INNER JOIN db.scope            sc ON o.scope = sc.id;

GRANT SELECT ON ServiceMessage TO administrator;
