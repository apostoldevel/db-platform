--------------------------------------------------------------------------------
-- Message ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Message (Id, Document,
  Source, SourceCode, SourceName, SourceDescription,
  AgentType, AgentTypeCode, AgentTypeName, AgentTypeDescription,
  Agent, AgentCode, AgentName, AgentDescription,
  Code, Profile, Address, Subject, Content
)
AS
  SELECT m.id, m.document,
         o.type, t.code, t.name, t.description,
         ra.type, at.code, at.name, at.description,
         m.agent, ra.code, ra.name, ra.description,
         m.code, m.profile, m.address, m.subject, m.content
    FROM db.message m INNER JOIN Reference ra ON m.agent = ra.id
                      INNER JOIN db.type   at ON ra.type = at.id
                      INNER JOIN db.object  o ON ra.object = o.id
                      INNER JOIN db.type    t ON o.type = t.id;

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
  Area, AreaCode, AreaName, AreaDescription
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
         d.area, d.areacode, d.areaname, d.areadescription
    FROM AccessMessage m INNER JOIN Document d ON m.document = d.id
                         INNER JOIN Object   o ON m.document = o.id;

GRANT SELECT ON ObjectMessage TO administrator;
