--------------------------------------------------------------------------------
-- VIEW Object -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Object (Id, Parent,
  Entity, EntityCode, EntityName,
  Class, ClassCode, ClassLabel,
  Type, TypeCode, TypeName, TypeDescription,
  Label, Text,
  StateType, StateTypeCode, StateTypeName,
  State, StateCode, StateLabel, LastUpdate,
  Owner, OwnerCode, OwnerName, Created,
  Oper, OperCode, OperName, OperDate,
  Scope, ScopeCode, ScopeName, ScopeDescription
) AS
  SELECT o.id, o.parent,
         o.entity, e.code, et.name,
         o.class, c.code, ct.label,
         o.type, y.code, ty.name, ty.description,
         ot.label, ot.text,
         o.state_type, st.code, stt.name,
         o.state, s.code, sst.label, o.udate,
         o.owner, w.username, w.name, o.pdate,
         o.oper, u.username, u.name, o.ldate,
         o.scope, sc.code, sc.name, sc.description
    FROM db.object o  LEFT JOIN db.object_text      ot ON ot.object = o.id AND ot.locale = current_locale()
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

GRANT SELECT ON Object TO administrator;

--------------------------------------------------------------------------------
-- AccessObject ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW AccessObject
AS
  WITH access AS (
    SELECT * FROM aou(current_userid())
  )
  SELECT o.* FROM Object o INNER JOIN access ac ON o.id = ac.object WHERE o.scope = current_scope();

GRANT SELECT ON AccessObject TO administrator;

--------------------------------------------------------------------------------
-- AccessObjectId --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW AccessObjectId
AS
  WITH access AS (
    SELECT * FROM aou(current_userid())
  )
  SELECT o.id FROM db.object o INNER JOIN access ac ON o.id = ac.object WHERE o.scope = current_scope();

GRANT SELECT ON AccessObject TO administrator;

--------------------------------------------------------------------------------
-- VIEW ObjectMembers ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectMembers
AS
  SELECT object, userid, deny::int, allow::int, mask::int, u.type, username, name, description
    FROM db.aou a INNER JOIN db.user u ON u.id = a.userid;

GRANT SELECT ON ObjectMembers TO administrator;

--------------------------------------------------------------------------------
-- VIEW ObjectState ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectState (Id, Object, Class,
  State, StateTypeCode, StateTypeName, StateCode, StateLabel,
  ValidFromDate, validToDate
)
AS
  SELECT o.id, o.object, s.class, o.state, s.typecode, s.typename, s.code, s.label,
         o.validFromDate, o.validToDate
    FROM db.object_state o INNER JOIN State s ON s.id = o.state;

GRANT SELECT ON ObjectState TO administrator;

--------------------------------------------------------------------------------
-- ObjectGroup -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectGroup
AS
  SELECT *
    FROM db.object_group g INNER JOIN db.profile p ON g.owner = p.userid AND p.scope = current_scope()
   WHERE g.owner = current_userid();

GRANT SELECT ON ObjectGroup TO administrator;

--------------------------------------------------------------------------------
-- ObjectGroupMember -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectGroupMember (GId, Object, Code, Name, Description)
AS
  SELECT m.gid, m.object, g.code, g.name, g.description
    FROM db.object_group_member m INNER JOIN ObjectGroup g ON g.id = m.gid;

GRANT SELECT ON ObjectGroupMember TO administrator;

--------------------------------------------------------------------------------
-- VIEW ObjectLink -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectLink
AS
  SELECT * FROM db.object_link;

GRANT SELECT ON ObjectLink TO administrator;

--------------------------------------------------------------------------------
-- VIEW ObjectFile -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectFile (Object, Label, Owner, OwnerCode, OwnerName,
    Name, Path, Size, Date, Data, Link, Hash, Text, Type, CallBack, Loaded, Picture
)
AS
    SELECT t.object, ot.label, t.owner, u.username, u.name,
           t.file_name, t.file_path, t.file_size, t.file_date, encode(t.file_data, 'base64'),
           t.file_link, t.file_hash, t.file_text, t.file_type, t.call_back, t.load_date, p.picture
      FROM db.object_file t INNER JOIN db.object_text ot ON t.object = ot.object AND ot.locale = current_locale()
                            INNER JOIN db.user         u ON u.id = t.owner
                            INNER JOIN db.profile      p ON u.id = p.userid AND p.scope = current_scope();

GRANT SELECT ON ObjectFile TO administrator;

--------------------------------------------------------------------------------
-- VIEW ObjectData -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectData
AS
  SELECT * FROM db.object_data;

GRANT SELECT ON ObjectData TO administrator;

--------------------------------------------------------------------------------
-- VIEW ObjectCoordinates ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectCoordinates
AS
  SELECT oc.id, oc.object,
         o.entity, o.entitycode, o.entityname,
         o.class, o.classcode, o.classlabel,
         o.type, o.typecode, o.typename, o.typedescription,
         oc.code, oc.latitude, oc.longitude, oc.accuracy,
         oc.label, oc.description, oc.data, oc.validfromdate, oc.validtodate
    FROM db.object_coordinates oc INNER JOIN Object o ON oc.object = o.id;

GRANT SELECT ON ObjectCoordinates TO administrator;

--------------------------------------------------------------------------------
-- VIEW AOU --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW AOU
AS
  SELECT a.object,
         o.entity, o.entitycode, o.entityname,
         o.class, o.classcode, o.classlabel,
         o.type, o.typecode, o.typename, o.typedescription,
         o.label, o.text,
         o.statetype, o.statetypecode, o.statetypename,
         o.state, o.statecode, o.statelabel, o.lastupdate,
         o.owner, o.ownercode, o.ownername, o.created,
         o.oper, o.opercode, o.opername, o.operdate,
         a.userid, u.type AS role, u.username, u.name, u.description,
         a.deny, a.allow, a.mask
    FROM db.aou a INNER JOIN Object  o ON a.object = o.id
                  INNER JOIN db.user u ON a.userid = u.id;

GRANT SELECT ON AOU TO administrator;