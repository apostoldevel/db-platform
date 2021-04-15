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
    FROM db.message m INNER JOIN db.object     o ON o.id = m.document
                      INNER JOIN db.class_tree c ON c.id = o.class
                      INNER JOIN Reference     a ON m.agent = a.id
                      INNER JOIN db.type       t ON a.type = t.id;

GRANT SELECT ON Message TO administrator;

--------------------------------------------------------------------------------
-- AccessMessage ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW AccessMessage
AS
  WITH access AS (
    SELECT * FROM AccessObjectUser(GetEntity('message'), current_userid())
  )
  SELECT m.* FROM Message m INNER JOIN access ac ON m.id = ac.object;

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
  Owner, OwnerCode, OwnerName, Created,
  Oper, OperCode, OperName, OperDate,
  Area, AreaCode, AreaName, AreaDescription,
  Scope, ScopeCode, ScopeName, ScopeDescription
)
AS
  SELECT m.id, d.object, o.parent,
         o.entity, o.entitycode, o.entityname,
         o.class, o.classcode, o.classlabel,
         o.type, o.typecode, o.typename, o.typedescription,
         m.agenttype, m.agenttypecode, m.agenttypename, m.agenttypedescription,
         m.agent, m.agentcode, m.agentname, m.agentdescription,
         m.code, m.profile, m.address, m.subject, m.content,
         o.label, d.description,
         o.statetype, o.statetypecode, o.statetypename,
         o.state, o.statecode, o.statelabel, o.lastupdate,
         o.owner, o.ownercode, o.ownername, o.created,
         o.oper, o.opercode, o.opername, o.operdate,
         d.area, d.areacode, d.areaname, d.areadescription,
         d.scope, d.scopecode, d.scopename, d.scopedescription
    FROM AccessMessage m INNER JOIN Document d ON m.document = d.id
                         INNER JOIN Object   o ON m.document = o.id;

GRANT SELECT ON ObjectMessage TO administrator;
