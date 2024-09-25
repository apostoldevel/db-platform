--------------------------------------------------------------------------------
-- Message ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Message (Id, Document,
  Class, ClassCode, ClassLabel,
  AgentType, AgentTypeCode, AgentTypeName, AgentTypeDescription,
  Agent, AgentCode, AgentName, AgentDescription,
  Code, Profile, Address, Subject, Content
)
AS
  SELECT m.id, m.document,
         o.class, c.code, c.label,
         a.type, t.code, t.name, t.description,
         m.agent, a.code, a.name, a.description,
         m.code, m.profile, m.address, m.subject, m.content
    FROM db.message m INNER JOIN db.object o ON o.id = m.document
                      INNER JOIN Class     c ON c.id = o.class
                      INNER JOIN Reference a ON m.agent = a.id
                      INNER JOIN Type      t ON a.type = t.id;

GRANT SELECT ON Message TO administrator;

--------------------------------------------------------------------------------
-- AccessMessage ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW AccessMessage
AS
WITH _access AS (
   WITH _membergroup AS (
     SELECT current_userid() AS userid UNION SELECT userid FROM db.member_group WHERE member = current_userid()
   ) SELECT object
       FROM db.aou AS a INNER JOIN db.entity    e ON a.entity = e.id AND e.code = 'message'
                        INNER JOIN _membergroup m ON a.userid = m.userid
      GROUP BY object
      HAVING (bit_or(a.allow) & ~bit_or(a.deny)) & B'100' = B'100'
) SELECT t.* FROM db.message t INNER JOIN _access ac ON t.id = ac.object;

GRANT SELECT ON AccessMessage TO administrator;

--------------------------------------------------------------------------------
-- ObjectMessage ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectMessage (Id, Object, Parent,
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
    FROM AccessMessage t INNER JOIN db.document          d ON t.document = d.id
                          LEFT JOIN db.document_text    dt ON dt.document = d.id AND dt.locale = current_locale()
                         INNER JOIN DocumentAreaTree     a ON d.area = a.id

                         INNER JOIN db.priority          p ON d.priority = p.id
                          LEFT JOIN db.priority_text    pt ON pt.priority = p.id AND pt.locale = current_locale()

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

                         INNER JOIN db.user              w ON o.owner = w.id
                         INNER JOIN db.user              u ON o.oper = u.id

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

                      INNER JOIN db.priority          p ON d.priority = p.id
                       LEFT JOIN db.priority_text    pt ON pt.priority = p.id AND pt.locale = current_locale()

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

                      INNER JOIN db.user              w ON o.owner = w.id
                      INNER JOIN db.user              u ON o.oper = u.id

                      INNER JOIN db.area              a ON d.area = a.id
                      INNER JOIN db.scope            sc ON o.scope = sc.id;

GRANT SELECT ON ServiceMessage TO administrator;
