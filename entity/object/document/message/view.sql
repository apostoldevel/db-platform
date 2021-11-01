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
  WITH access AS (
    SELECT * FROM AccessObjectUser(GetEntity('message'), current_userid())
  )
  SELECT m.* FROM Message m INNER JOIN access ac ON m.id = ac.object;

GRANT SELECT ON AccessMessage TO administrator;

--------------------------------------------------------------------------------
-- ObjectMessage ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectMessage
AS
  SELECT t.id, d.object, d.parent,
         d.entity, d.entitycode, d.entityname,
         d.class, d.classcode, d.classlabel,
         d.type, d.typecode, d.typename, d.typedescription,
         t.agenttype, t.agenttypecode, t.agenttypename, t.agenttypedescription,
         t.agent, t.agentcode, t.agentname, t.agentdescription,
         t.code, t.profile, t.address, t.subject, t.content,
         d.label, d.description,
         d.statetype, d.statetypecode, d.statetypename,
         d.state, d.statecode, d.statelabel, d.lastupdate,
         d.owner, d.ownercode, d.ownername, d.created,
         d.oper, d.opercode, d.opername, d.operdate,
         d.area, d.areacode, d.areaname, d.areadescription,
         d.scope, d.scopecode, d.scopename, d.scopedescription
    FROM AccessMessage t INNER JOIN ObjectDocument d ON t.document = d.id;

GRANT SELECT ON ObjectMessage TO administrator;

--------------------------------------------------------------------------------
-- ServiceMessage --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ServiceMessage
AS
  SELECT t.id, d.object, o.parent,
         o.entity, o.entitycode, o.entityname,
         o.class, o.classcode, o.classlabel,
         o.type, o.typecode, o.typename, o.typedescription,
         t.agenttype, t.agenttypecode, t.agenttypename, t.agenttypedescription,
         t.agent, t.agentcode, t.agentname, t.agentdescription,
         t.code, t.profile, t.address, t.subject, t.content,
         o.label, d.description,
         o.statetype, o.statetypecode, o.statetypename,
         o.state, o.statecode, o.statelabel, o.lastupdate,
         o.owner, o.ownercode, o.ownername, o.created,
         o.oper, o.opercode, o.opername, o.operdate,
         d.area, d.areacode, d.areaname, d.areadescription,
         d.scope, d.scopecode, d.scopename, d.scopedescription
    FROM Message t INNER JOIN Document d ON t.document = d.id
                   INNER JOIN Object   o ON t.document = o.id;

GRANT SELECT ON ServiceMessage TO administrator;
