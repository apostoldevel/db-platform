--------------------------------------------------------------------------------
-- OBJECT ----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.object (
    id			numeric(12) PRIMARY KEY,
    parent		numeric(12),
    essence		numeric(12) NOT NULL,
    class		numeric(12) NOT NULL,
    type		numeric(12) NOT NULL,
    state_type  numeric(12),
    state		numeric(12),
    suid		numeric(12) NOT NULL,
    owner		numeric(12) NOT NULL,
    oper		numeric(12) NOT NULL,
    label		text,
    pdate		timestamp NOT NULL DEFAULT Now(),
    ldate		timestamp NOT NULL DEFAULT Now(),
    udate		timestamp NOT NULL DEFAULT Now(),
    CONSTRAINT fk_object_parent FOREIGN KEY (parent) REFERENCES db.object(id),
    CONSTRAINT fk_object_essence FOREIGN KEY (essence) REFERENCES db.essence(id),
    CONSTRAINT fk_object_class FOREIGN KEY (class) REFERENCES db.class_tree(id),
    CONSTRAINT fk_object_type FOREIGN KEY (type) REFERENCES db.type(id),
    CONSTRAINT fk_object_state_type FOREIGN KEY (state_type) REFERENCES db.state_type(id),
    CONSTRAINT fk_object_state FOREIGN KEY (state) REFERENCES db.state(id),
    CONSTRAINT fk_object_suid FOREIGN KEY (suid) REFERENCES db.user(id),
    CONSTRAINT fk_object_owner FOREIGN KEY (owner) REFERENCES db.user(id),
    CONSTRAINT fk_object_oper FOREIGN KEY (oper) REFERENCES db.user(id)
);

COMMENT ON TABLE db.object IS 'Список объектов.';

COMMENT ON COLUMN db.object.id IS 'Идентификатор';
COMMENT ON COLUMN db.object.parent IS 'Родитель';
COMMENT ON COLUMN db.object.essence IS 'Сущность';
COMMENT ON COLUMN db.object.class IS 'Класс';
COMMENT ON COLUMN db.object.type IS 'Тип';
COMMENT ON COLUMN db.object.state_type IS 'Тип состояния';
COMMENT ON COLUMN db.object.state IS 'Состояние';
COMMENT ON COLUMN db.object.suid IS 'Системный пользователь';
COMMENT ON COLUMN db.object.owner IS 'Владелец (пользователь)';
COMMENT ON COLUMN db.object.oper IS 'Пользователь совершивший последнюю операцию';
COMMENT ON COLUMN db.object.label IS 'Метка';
COMMENT ON COLUMN db.object.pdate IS 'Физическая дата';
COMMENT ON COLUMN db.object.ldate IS 'Логическая дата';
COMMENT ON COLUMN db.object.udate IS 'Дата последнего изменения';

CREATE INDEX ON db.object (parent);
CREATE INDEX ON db.object (essence);
CREATE INDEX ON db.object (class);
CREATE INDEX ON db.object (type);
CREATE INDEX ON db.object (state_type);
CREATE INDEX ON db.object (state);

CREATE INDEX ON db.object (suid);
CREATE INDEX ON db.object (owner);
CREATE INDEX ON db.object (oper);

CREATE INDEX ON db.object (label);
CREATE INDEX ON db.object (label text_pattern_ops);

CREATE INDEX ON db.object (pdate);
CREATE INDEX ON db.object (ldate);
CREATE INDEX ON db.object (udate);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_object_before_insert()
RETURNS trigger AS $$
DECLARE
  bAbstract	boolean;
BEGIN
  IF lower(session_user) = 'kernel' THEN
    PERFORM AccessDeniedForUser(session_user);
  END IF;

  SELECT class INTO NEW.class FROM db.type WHERE id = NEW.type;
  SELECT essence, abstract INTO NEW.essence, bAbstract FROM db.class_tree WHERE id = NEW.class;

  IF bAbstract THEN
    PERFORM AbstractError();
  END IF;

  IF NULLIF(NEW.id, 0) IS NULL THEN
    SELECT NEXTVAL('SEQUENCE_ID') INTO NEW.id;
  END IF;

  SELECT type INTO NEW.state_type FROM db.state WHERE id = NEW.state;

  NEW.suid := session_userid();
  NEW.owner := current_userid();
  NEW.oper := current_userid();

  NEW.pdate := now();
  NEW.ldate := now();
  NEW.udate := now();

  RAISE DEBUG 'Создан объект Id: %', NEW.id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_object_before_insert
  BEFORE INSERT ON db.object
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_object_before_insert();

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_object_after_insert()
RETURNS trigger AS $$
BEGIN
  INSERT INTO db.aom SELECT NEW.id;
  INSERT INTO db.aou (object, userid, deny, allow) SELECT NEW.id, userid, SubString(deny FROM 3 FOR 3), SubString(allow FROM 3 FOR 3) FROM db.acu WHERE class = NEW.class;

  UPDATE db.aou SET deny = B'000', allow = B'111' WHERE object = NEW.id AND userid = NEW.owner;
  IF NOT FOUND THEN
    INSERT INTO db.aou SELECT NEW.id, NEW.owner, B'000', B'111';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_object_after_insert
  AFTER INSERT ON db.object
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_object_after_insert();

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_object_before_update()
RETURNS trigger AS $$
BEGIN
  IF lower(session_user) = 'kernel' THEN
    SELECT AccessDeniedForUser(session_user);
  END IF;

  IF OLD.suid <> NEW.suid THEN
    PERFORM AccessDenied();
  END IF;

  IF NOT CheckObjectAccess(NEW.id, B'010') THEN
    --RAISE NOTICE 'Object: %, Type: %, Owner: %, UserId: %', NEW.id, GetTypeCode(NEW.type), NEW.owner, current_userid();
    PERFORM AccessDenied();
  END IF;

  IF OLD.type <> NEW.type THEN
    SELECT class INTO NEW.class FROM db.type WHERE id = NEW.type;
    SELECT essence INTO NEW.essence FROM db.class_tree WHERE id = NEW.class;

    IF OLD.essence <> NEW.essence THEN
      PERFORM IncorrectEssence();
    END IF;
  END IF;

  IF OLD.class <> NEW.class THEN
    NEW.state := GetState(NEW.class, OLD.state_type);

    IF coalesce(OLD.state <> NEW.state, false) THEN
      UPDATE db.object_state SET state = NEW.state
       WHERE object = OLD.id
         AND state = OLD.state;
    END IF;
  END IF;

  IF NEW.state IS NOT NULL THEN
    SELECT type INTO NEW.state_type FROM db.state WHERE id = NEW.state;
  ELSE
    NEW.state_type := NULL;
  END IF;

  IF OLD.owner <> NEW.owner THEN
    DELETE FROM db.aou WHERE object = NEW.id AND userid = OLD.owner AND mask = B'111';
    INSERT INTO db.aou SELECT NEW.id, NEW.owner, B'000', B'111';
  END IF;

  NEW.oper := current_userid();

  NEW.ldate := now();
  NEW.udate := now();

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_object_before_update
  BEFORE UPDATE ON db.object
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_object_before_update();

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_object_before_delete()
RETURNS trigger AS $$
BEGIN
  IF lower(session_user) = 'kernel' THEN
    SELECT AccessDeniedForUser(session_user);
  END IF;

  IF NOT CheckObjectAccess(OLD.ID, B'001') THEN
    PERFORM AccessDenied();
  END IF;

  DELETE FROM db.aou WHERE object = OLD.ID;
  DELETE FROM db.aom WHERE object = OLD.ID;

  RETURN OLD;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_object_before_delete
  BEFORE DELETE ON db.object
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_object_before_delete();

--------------------------------------------------------------------------------
-- TABLE db.aom ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.aom (
    object		NUMERIC(12) NOT NULL,
    mask		BIT(9) DEFAULT B'111100000' NOT NULL,
    CONSTRAINT fk_aom_object FOREIGN KEY (object) REFERENCES db.object(id)
);

COMMENT ON TABLE db.aom IS 'Маска доступа к объекту.';

COMMENT ON COLUMN db.aom.object IS 'Объект';
COMMENT ON COLUMN db.aom.mask IS 'Маска доступа. Девять бит (a:{u:sud}{g:sud}{o:sud}), по три бита на действие s - select, u - update, d - delete, для: a - all (все) = u - user (владелец) g - group (группа) o - other (остальные)';

CREATE UNIQUE INDEX ON db.aom (object);

--------------------------------------------------------------------------------
-- TABLE db.aou ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.aou (
    object		numeric(12) NOT NULL,
    userid		numeric(12) NOT NULL,
    deny		bit(3) NOT NULL,
    allow		bit(3) NOT NULL,
    mask		bit(3) DEFAULT B'000' NOT NULL,
    CONSTRAINT fk_aou_object FOREIGN KEY (object) REFERENCES db.object(id),
    CONSTRAINT fk_aou_userid FOREIGN KEY (userid) REFERENCES db.user(id)
);

COMMENT ON TABLE db.aou IS 'Доступ пользователя и групп пользователей к объекту.';

COMMENT ON COLUMN db.aou.object IS 'Объект';
COMMENT ON COLUMN db.aou.userid IS 'Пользователь';
COMMENT ON COLUMN db.aou.deny IS 'Запрещающие биты: {sud}. Где: {s - select; u - update; d - delete}';
COMMENT ON COLUMN db.aou.allow IS 'Разрешающие биты: {sud}. Где: {s - select; u - update; d - delete}';
COMMENT ON COLUMN db.aou.mask IS 'Маска доступа: {sud}. Где: {s - select; u - update; d - delete}';

CREATE UNIQUE INDEX ON db.aou (object, userid);

CREATE INDEX ON db.aou (object);
CREATE INDEX ON db.aou (userid);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_aou_before()
RETURNS TRIGGER AS $$
BEGIN
  IF (TG_OP = 'INSERT') THEN
    NEW.mask = NEW.allow & ~NEW.deny;
    RETURN NEW;
  ELSIF (TG_OP = 'UPDATE') THEN
    NEW.mask = NEW.allow & ~NEW.deny;
    RETURN NEW;
  END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER t_aou_before
  BEFORE INSERT OR UPDATE ON db.aou
  FOR EACH ROW
  EXECUTE PROCEDURE ft_aou_before();

--------------------------------------------------------------------------------
-- FUNCTION aou ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION aou (
  pUserId       numeric,
  OUT object    numeric,
  OUT deny      bit,
  OUT allow     bit,
  OUT mask      bit
) RETURNS       SETOF record
AS $$
  WITH member_group AS (
      SELECT pUserId AS userid UNION ALL SELECT userid FROM db.member_group WHERE member = pUserId
  )
  SELECT a.object, bit_or(a.deny), bit_or(a.allow), bit_or(a.mask)
    FROM db.aou a INNER JOIN member_group m ON a.userid = m.userid
   GROUP BY a.object;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION aou ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION aou (
  pUserId       numeric,
  pObject       numeric,
  OUT object    numeric,
  OUT deny      bit,
  OUT allow     bit,
  OUT mask      bit
) RETURNS       SETOF record
AS $$
  WITH member_group AS (
      SELECT pUserId AS userid UNION ALL SELECT userid FROM db.member_group WHERE member = pUserId
  )
  SELECT a.object, bit_or(a.deny), bit_or(a.allow), bit_or(a.mask)
    FROM db.aou a INNER JOIN member_group m ON a.userid = m.userid
     AND a.object = pObject
   GROUP BY a.object
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectMask ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectMask (
  pObject	numeric,
  pUserId	numeric DEFAULT current_userid()
) RETURNS	bit
AS $$
  SELECT CASE
         WHEN pUserId = o.owner THEN SubString(mask FROM 1 FOR 3)
         WHEN EXISTS (SELECT id FROM db.user WHERE id = pUserId AND type = 'G') THEN SubString(mask FROM 4 FOR 3)
         ELSE SubString(mask FROM 7 FOR 3)
         END
    FROM db.aom a INNER JOIN db.object o ON o.id = a.object
   WHERE object = pObject
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectAccessMask ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectAccessMask (
  pObject	numeric,
  pUserId	numeric DEFAULT current_userid()
) RETURNS	bit
AS $$
  SELECT mask FROM aou(pUserId, pObject)
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CheckObjectAccess -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckObjectAccess (
  pObject	numeric,
  pMask		bit,
  pUserId	numeric DEFAULT current_userid()
) RETURNS	boolean
AS $$
BEGIN
  RETURN coalesce(coalesce(GetObjectAccessMask(pObject, pUserId), GetObjectMask(pObject, pUserId)) & pMask = pMask, false);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DecodeObjectAccess ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DecodeObjectAccess (
  pObject	numeric,
  pUserId	numeric DEFAULT current_userid(),
  OUT s		boolean,
  OUT u		boolean,
  OUT d		boolean
) RETURNS 	record
AS $$
DECLARE
  bMask		bit(3);
BEGIN
  bMask := coalesce(GetObjectAccessMask(pObject, pUserId), GetObjectMask(pObject, pUserId));

  s := bMask & B'100' = B'100';
  u := bMask & B'010' = B'010';
  d := bMask & B'001' = B'001';
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- VIEW ObjectMembers ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectMembers
AS
  SELECT object, userid, deny::int, allow::int, mask::int, u.type, username, name, description
    FROM db.aou a INNER JOIN db.user u ON u.id = a.userid;

GRANT SELECT ON ObjectMembers TO administrator;

--------------------------------------------------------------------------------
-- GetObjectMembers ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectMembers (
  pObject	numeric
) RETURNS 	SETOF ObjectMembers
AS $$
  SELECT * FROM ObjectMembers WHERE object = pObject;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- chmodo ----------------------------------------------------------------------
--------------------------------------------------------------------------------
/*
 * Устанавливает битовую маску доступа для объекта и пользователя.
 * @param {numeric} pObject - Идентификатор объекта
 * @param {bit} pMask - Маска доступа. Шесть бит (d:{sud}a:{sud}) где: d - запрещающие биты; a - разрешающие биты: {s - select, u - update, d - delete}
 * @param {numeric} pUserId - Идентификатор пользователя/группы
 * @return {void}
*/
CREATE OR REPLACE FUNCTION chmodo (
  pObject       numeric,
  pMask         bit,
  pUserId       numeric DEFAULT current_userid()
) RETURNS       void
AS $$
DECLARE
  bDeny         bit(3);
  bAllow        bit(3);
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(GetGroup('administrator')) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  pMask := NULLIF(pMask, B'000000');

  IF pMask IS NOT NULL THEN
    bDeny := coalesce(SubString(pMask FROM 1 FOR 3), B'000');
    bAllow := coalesce(SubString(pMask FROM 4 FOR 3), B'000');

    UPDATE db.aou SET deny = bDeny, allow = bAllow WHERE object = pObject AND userid = pUserId;
    IF NOT FOUND THEN
      INSERT INTO db.aou SELECT pObject, pUserId, bDeny, bAllow;
    END IF;
  ELSE
    DELETE FROM db.aou WHERE object = pObject AND userid = pUserId;
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AccessObjectUser ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AccessObjectUser (
  pUserId	numeric DEFAULT current_userid()
) RETURNS TABLE (
    object  numeric
)
AS $$
  WITH membergroup AS (
      SELECT pUserId AS userid UNION ALL SELECT userid FROM db.member_group WHERE member = pUserId
  )
  SELECT a.object
    FROM db.aou a INNER JOIN membergroup m ON a.userid = m.userid
   GROUP BY a.object
  HAVING bit_or(a.mask) & B'100' = B'100'
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- VIEW Object -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Object (Id, Parent,
  Essence, EssenceCode, EssenceName,
  Class, ClassCode, ClassLabel,
  Type, TypeCode, TypeName, TypeDescription,
  Label,
  StateType, StateTypeCode, StateTypeName,
  State, StateCode, StateLabel, LastUpdate,
  Owner, OwnerCode, OwnerName, Created,
  Oper, OperCode, OperName, OperDate
) AS
WITH access AS (
  SELECT * FROM AccessObjectUser()
)
  SELECT o.id, o.parent,
         e.id, e.code, e.name,
         c.id, c.code, c.label,
         t.id, t.code, t.name, t.description,
         o.label,
         p.id, p.code, p.name,
         o.state, s.code, s.label, o.udate,
         o.owner, w.username, w.name, o.pdate,
         o.oper, u.username, u.name, o.ldate
    FROM access a INNER JOIN db.object     o ON o.id = a.object
                  INNER JOIN db.essence    e ON e.id = o.essence
                  INNER JOIN db.class_tree c ON c.id = o.class
                  INNER JOIN db.type       t ON t.id = o.type
                  INNER JOIN db.state_type p ON p.id = o.state_type
                  INNER JOIN db.state      s ON s.id = o.state
                  INNER JOIN db.user       w ON w.id = o.owner AND w.type = 'U'
                  INNER JOIN db.user       u ON u.id = o.oper AND u.type = 'U';

GRANT SELECT ON Object TO administrator;

--------------------------------------------------------------------------------
-- CreateObject ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateObject (
  pParent	numeric,
  pType     numeric,
  pLabel	text DEFAULT null
) RETURNS 	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  INSERT INTO db.object (parent, type, label)
  VALUES (pParent, pType, pLabel)
  RETURNING id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditObject ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditObject (
  pId           numeric,
  pParent       numeric DEFAULT null,
  pType         numeric DEFAULT null,
  pLabel        text DEFAULT null
) RETURNS       void
AS $$
BEGIN
  UPDATE db.object
     SET type = coalesce(pType, type),
         parent = CheckNull(coalesce(pParent, parent, 0)),
         label = CheckNull(coalesce(pLabel, label, '<null>'))
   WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SetObjectParent -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetObjectParent (
  nObject	numeric,
  pParent	numeric
) RETURNS	void
AS $$
BEGIN
  UPDATE db.object SET parent = pParent WHERE id = nObject;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectEssence ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectEssence (
  nObject	numeric
) RETURNS	numeric
AS $$
DECLARE
  nType     numeric;
  nClass    numeric;
BEGIN
  SELECT type INTO nType FROM db.object WHERE id = nObject;
  SELECT class INTO nClass FROM db.type WHERE id = nType;
  RETURN GetEssence(nClass);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectParent -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectParent (
  nObject	numeric
) RETURNS	numeric
AS $$
DECLARE
  nParent	numeric;
BEGIN
  SELECT parent INTO nParent FROM db.object WHERE id = nObject;
  RETURN nParent;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectLabel -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectLabel (
  pObject	numeric
) RETURNS	text
AS $$
DECLARE
  vLabel	text;
BEGIN
  SELECT label INTO vLabel FROM db.object WHERE id = pObject;

  RETURN vLabel;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetObjectLabel -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetObjectLabel (
  pObject	numeric,
  pLabel    text
) RETURNS	void
AS $$
BEGIN
  UPDATE db.object SET label = pLabel WHERE id = pObject;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectClass -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectClass (
  pId		numeric
) RETURNS	numeric
AS $$
DECLARE
  nClass	numeric;
BEGIN
  SELECT class INTO nClass FROM db.type WHERE id = (
    SELECT type FROM db.object WHERE id = pId
  );

  RETURN nClass;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectType ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectType (
  pId		numeric
) RETURNS	numeric
AS $$
DECLARE
  nType         numeric;
BEGIN
  SELECT type INTO nType FROM db.object WHERE id = pId;

  RETURN nType;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectTypeCode --------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectTypeCode (
  pId		numeric
) RETURNS	varchar
AS $$
DECLARE
  vCode		varchar;
BEGIN
  SELECT code INTO vCode FROM db.type WHERE id = (
    SELECT type FROM db.object WHERE id = pId
  );

  RETURN vCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectState -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectState (
  pId		numeric
) RETURNS	numeric
AS $$
DECLARE
  nState	numeric;
BEGIN
  SELECT state INTO nState FROM db.object WHERE id = pId;

  RETURN nState;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetObjectOwner -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetObjectOwner (
  pId		numeric,
  pOwner    numeric
) RETURNS 	void
AS $$
BEGIN
  UPDATE db.object SET owner = pOwner WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectOwner -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectOwner (
  pId		numeric
) RETURNS 	numeric
AS $$
DECLARE
  nOwner	numeric;
BEGIN
  SELECT owner INTO nOwner FROM db.object WHERE id = pId;

  RETURN nOwner;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectOper ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectOper (
  pId		numeric
) RETURNS 	numeric
AS $$
DECLARE
  nOper	numeric;
BEGIN
  SELECT oper INTO nOper FROM db.object WHERE id = pId;

  RETURN nOper;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- OBJECT_STATE ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.object_state (
    id			    numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    object		    numeric(12) NOT NULL,
    state		    numeric(12) NOT NULL,
    validFromDate	timestamp DEFAULT Now() NOT NULL,
    validToDate		timestamp DEFAULT TO_DATE('4433-12-31', 'YYYY-MM-DD') NOT NULL,
    CONSTRAINT fk_object_state_object FOREIGN KEY (object) REFERENCES db.object(id),
    CONSTRAINT fk_object_state_state FOREIGN KEY (state) REFERENCES db.state(id)
);

COMMENT ON TABLE db.object_state IS 'Состояние объекта.';

COMMENT ON COLUMN db.object_state.id IS 'Идентификатор';
COMMENT ON COLUMN db.object_state.object IS 'Объект';
COMMENT ON COLUMN db.object_state.state IS 'Ссылка на состояние объекта';
COMMENT ON COLUMN db.object_state.validFromDate IS 'Дата начала периода действия';
COMMENT ON COLUMN db.object_state.validToDate IS 'Дата окончания периода действия';

CREATE INDEX ON db.object_state (object);
CREATE INDEX ON db.object_state (state);
CREATE INDEX ON db.object_state (object, validFromDate, validToDate);

CREATE UNIQUE INDEX ON db.object_state (object, state, validFromDate, validToDate);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_object_state_change()
RETURNS TRIGGER AS
$$
BEGIN
  IF (TG_OP = 'INSERT') OR (TG_OP = 'UPDATE') THEN
    IF NEW.validfromdate IS NULL THEN
      NEW.validfromdate := now();
    END IF;

    IF NEW.validtodate IS NULL THEN
      NEW.validtodate := MAXDATE();
    END IF;

    IF NEW.validfromdate > NEW.validtodate THEN
      RAISE EXCEPTION 'ERR-80000: Дата начала периода действия не должна превышать дату окончания периода действия.';
    END IF;

    IF TG_OP = 'INSERT' THEN
      UPDATE db.object SET state = NEW.state WHERE id = NEW.object;
    END IF;

    RETURN NEW;
  ELSE
    IF OLD.validtodate = MAXDATE() THEN
      UPDATE db.object SET state = NULL WHERE id = OLD.object;
    END IF;

    RETURN OLD;
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_object_state_change
  AFTER INSERT OR UPDATE OR DELETE ON db.object_state
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_object_state_change();

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
-- FUNCTION AddObjectState -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddObjectState (
  pObject       numeric,
  pState        numeric,
  pDateFrom     timestamp DEFAULT oper_date()
) RETURNS       numeric
AS $$
DECLARE
  nId           numeric;

  dtDateFrom    timestamp;
  dtDateTo      timestamp;
BEGIN
  -- получим дату значения в текущем диапозоне дат
  SELECT validFromDate, validToDate INTO dtDateFrom, dtDateTo
    FROM db.object_state
   WHERE object = pObject
     AND validFromDate <= pDateFrom
     AND validToDate > pDateFrom;

  IF coalesce(dtDateFrom, MINDATE()) = pDateFrom THEN
    -- обновим значение в текущем диапозоне дат
    UPDATE db.object_state SET State = pState
     WHERE object = pObject
       AND validFromDate <= pDateFrom
       AND validToDate > pDateFrom;
  ELSE
    -- обновим дату значения в текущем диапозоне дат
    UPDATE db.object_state SET validToDate = pDateFrom
     WHERE object = pObject
       AND validFromDate <= pDateFrom
       AND validToDate > pDateFrom;

    INSERT INTO db.object_state (object, state, validFromDate, validToDate)
    VALUES (pObject, pState, pDateFrom, coalesce(dtDateTo, MAXDATE()))
    RETURNING id INTO nId;
  END IF;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectState -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectState (
  pObject	numeric,
  pDate		timestamp
) RETURNS	numeric
AS $$
DECLARE
  nState	numeric;
BEGIN
  SELECT state INTO nState
    FROM db.object_state
   WHERE object = pObject
     AND validFromDate <= pDate
     AND validToDate > pDate;

  RETURN nState;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectStateCode -------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectStateCode (
  pObject	numeric,
  pDate		timestamp DEFAULT oper_date()
) RETURNS 	varchar
AS $$
DECLARE
  nState	numeric;
  vCode		varchar;
BEGIN
  vCode := null;

  nState := GetObjectState(pObject, pDate);
  IF nState IS NOT NULL THEN
    SELECT code INTO vCode FROM db.state WHERE id = nState;
  END IF;

  RETURN vCode;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN null;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectStateType -------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectStateType (
  pObject	numeric,
  pDate		timestamp DEFAULT oper_date()
) RETURNS	numeric
AS $$
DECLARE
  nState	numeric;
BEGIN
  SELECT state INTO nState
    FROM db.object_state
   WHERE object = pObject
     AND validFromDate <= pDate
     AND validToDate > pDate;

  RETURN GetStateTypeByState(nState);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectStateTypeCode ---------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectStateTypeCode (
  pObject	numeric,
  pDate		timestamp DEFAULT oper_date()
) RETURNS 	varchar
AS $$
DECLARE
  nState	numeric;
BEGIN
  SELECT state INTO nState
    FROM db.object_state
   WHERE object = pObject
     AND validFromDate <= pDate
     AND validToDate > pDate;

  RETURN GetStateTypeCodeByState(nState);
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN null;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetNewState --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetNewState (
  pMethod	numeric
) RETURNS 	numeric
AS $$
DECLARE
  nNewState	numeric;
BEGIN
  SELECT newstate INTO nNewState FROM db.transition WHERE method = pMethod;

  RETURN nNewState;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- PROCEDURE ChangeObjectState -------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ChangeObjectState (
  pObject	numeric DEFAULT context_object(),
  pMethod	numeric DEFAULT context_method()
) RETURNS 	void
AS $$
DECLARE
  nNewState	numeric;
BEGIN
  nNewState := GetNewState(pMethod);
  IF nNewState IS NOT NULL THEN
    PERFORM AddObjectState(pObject, nNewState);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectMethod ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectMethod (
  pObject	numeric,
  pAction	numeric
) RETURNS	numeric
AS $$
DECLARE
  nType     numeric;
  nClass	numeric;
  nState	numeric;
  nMethod	numeric;
BEGIN
  SELECT type, state INTO nType, nState FROM db.object WHERE id = pObject;
  SELECT class INTO nClass FROM db.type WHERE id = nType;

  nMethod := GetMethod(nClass, nState, pAction);

  RETURN nMethod;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- METHOD STACK ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.method_stack (
    object		numeric(12) NOT NULL,
    method		numeric(12) NOT NULL,
    result		jsonb DEFAULT NULL,
    CONSTRAINT pk_object_method PRIMARY KEY(object, method),
    CONSTRAINT fk_method_stack_object FOREIGN KEY (object) REFERENCES db.object(id),
    CONSTRAINT fk_method_stack_method FOREIGN KEY (method) REFERENCES db.method(id)
);

COMMENT ON TABLE db.method_stack IS 'Стек выполнения метода.';

COMMENT ON COLUMN db.method_stack.object IS 'Объект';
COMMENT ON COLUMN db.method_stack.method IS 'Метод';
COMMENT ON COLUMN db.method_stack.result IS 'Результат выполения (при наличии)';

--------------------------------------------------------------------------------
-- FUNCTION AddMethodResult ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddMethodResult (
  pResult   jsonb,
  pObject	numeric DEFAULT context_object(),
  pMethod	numeric DEFAULT context_method()
) RETURNS	void
AS $$
BEGIN
  UPDATE db.method_stack SET result = pResult WHERE object = pObject AND method = pMethod;
  IF NOT FOUND THEN
    INSERT INTO db.method_stack (object, method, result) VALUES (pObject, pMethod, pResult);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION ClearMethodResult --------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ClearMethodResult (
  pObject	numeric,
  pMethod	numeric
) RETURNS	void
AS $$
  SELECT AddMethodResult(NULL, pObject, pMethod);
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetMethodResult ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetMethodResult (
  pObject	numeric,
  pMethod	numeric
) RETURNS	jsonb
AS $$
  SELECT result FROM db.method_stack WHERE object = pObject AND method = pMethod
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- PROCEDURE ExecuteAction -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ExecuteAction (
  pClass	numeric DEFAULT context_class(),
  pAction	numeric DEFAULT context_action()
) RETURNS	void
AS $$
DECLARE
  nClass	numeric;
  Rec		record;
BEGIN
  FOR Rec IN
    SELECT typecode, text
      FROM Event
     WHERE class = pClass
       AND action = pAction
       AND enabled
     ORDER BY sequence
  LOOP
    IF Rec.typecode = 'parent' THEN
      SELECT parent INTO nClass FROM db.class_tree WHERE id = pClass;
      IF nClass IS NOT NULL THEN
        PERFORM ExecuteAction(nClass, pAction);
      END IF;
    ELSIF Rec.typecode = 'event' THEN
      EXECUTE 'SELECT ' || Rec.Text;
    ELSIF Rec.typecode = 'plpgsql' THEN
      EXECUTE Rec.Text;
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- PROCEDURE ExecuteMethod -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ExecuteMethod (
  pObject       numeric,
  pMethod       numeric,
  pForm         jsonb DEFAULT null
) RETURNS       jsonb
AS $$
DECLARE
  nSaveObject	numeric;
  nSaveClass	numeric;
  nSaveMethod	numeric;
  nSaveAction	numeric;
  pSaveForm     jsonb;

  sLabel        text;

  nClass        numeric;
  nAction       numeric;
BEGIN
  IF NOT CheckMethodAccess(pMethod, B'100') THEN
    SELECT label INTO sLabel FROM db.method WHERE id = pMethod;
    PERFORM AccessDenied('метода ' || sLabel);
  END IF;

  nSaveObject := context_object();
  nSaveClass  := context_class();
  nSaveMethod := context_method();
  nSaveAction := context_action();
  pSaveForm   := context_form();

  PERFORM ClearMethodResult(pObject, pMethod);

  nClass := GetObjectClass(pObject);

  SELECT action INTO nAction FROM db.method WHERE id = pMethod;

  PERFORM InitContext(pObject, nClass, pMethod, nAction);
  PERFORM InitForm(pForm);

  PERFORM ExecuteAction(nClass, nAction);

  PERFORM InitForm(pSaveForm);
  PERFORM InitContext(nSaveObject, nSaveClass, nSaveMethod, nSaveAction);

  RETURN GetMethodResult(pObject, pMethod);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- PROCEDURE ExecuteMethodForAllChild ------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ExecuteMethodForAllChild (
  pObject	numeric DEFAULT context_object(),
  pClass	numeric DEFAULT context_class(),
  pMethod	numeric DEFAULT context_method(),
  pAction	numeric DEFAULT context_action(),
  pForm		jsonb DEFAULT context_form()
) RETURNS	jsonb
AS $$
DECLARE
  nMethod	numeric;
  rec		RECORD;
  result    jsonb;
BEGIN
  result := jsonb_build_array();

  FOR rec IN
    SELECT o.id, t.class, o.state
      FROM db.object o INNER JOIN db.type t ON o.type = t.id
     WHERE o.parent = pObject AND t.class = pClass
  LOOP
    nMethod := GetMethod(rec.class, rec.state, pAction);
    IF nMethod IS NOT NULL THEN
      result := result || ExecuteMethod(rec.id, nMethod, pForm);
    END IF;
  END LOOP;

  PERFORM InitContext(pObject, pClass, pMethod, pAction);

  RETURN result;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- PROCEDURE ExecuteObjectAction -----------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ExecuteObjectAction (
  pObject	numeric,
  pAction	numeric,
  pForm		jsonb DEFAULT null
) RETURNS 	jsonb
AS $$
DECLARE
  nMethod	numeric;
BEGIN
  nMethod := GetObjectMethod(pObject, pAction);

  IF nMethod IS NOT NULL THEN
    RETURN ExecuteMethod(pObject, nMethod, pForm);
  END IF;

  IF IsVisibleMethod(nMethod) THEN
    PERFORM MethodActionNotFound(pObject, pAction);
  END IF;

  RETURN null;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- db.object_group -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.object_group (
    id          numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    owner       numeric(12) NOT NULL,
    code        varchar(30) NOT NULL,
    name        varchar(50) NOT NULL,
    description text,
    CONSTRAINT fk_object_group_owner FOREIGN KEY (owner) REFERENCES db.user(id)
);

COMMENT ON TABLE db.object_group IS 'Группа объектов.';

COMMENT ON COLUMN db.object_group.id IS 'Идентификатор';
COMMENT ON COLUMN db.object_group.owner IS 'Владелец';
COMMENT ON COLUMN db.object_group.code IS 'Код';
COMMENT ON COLUMN db.object_group.name IS 'Наименование';
COMMENT ON COLUMN db.object_group.description IS 'Описание';

CREATE INDEX ON db.object_group (owner);

CREATE UNIQUE INDEX ON db.object_group (code);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_object_group_insert()
RETURNS trigger AS $$
BEGIN
  IF NEW.owner IS NULL THEN
    NEW.owner := current_userid();
  END IF;

  IF NEW.code IS NULL THEN
    NEW.code := encode(gen_random_bytes(12), 'hex');
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

CREATE TRIGGER t_object_group
  BEFORE INSERT ON db.object_group
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_object_group_insert();

--------------------------------------------------------------------------------
-- CreateObjectGroup -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateObjectGroup (
  pCode         varchar,
  pName         varchar,
  pDescription  varchar
) RETURNS       numeric
AS $$
DECLARE
  nId           numeric;
BEGIN
  INSERT INTO db.object_group (code, name, description)
  VALUES (pCode, pName, pDescription)
  RETURNING id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditObjectGroup -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditObjectGroup (
  pId		    numeric,
  pCode		    varchar DEFAULT null,
  pName		    varchar DEFAULT null,
  pDescription	varchar DEFAULT null
) RETURNS	    void
AS $$
BEGIN
  UPDATE db.object_group
     SET code = coalesce(pCode, code),
         name = coalesce(pName, name),
         description = coalesce(pDescription, description)
   WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectGroup --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectGroup (
  pCode		varchar
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM db.object_group WHERE code = pCode;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ObjectGroup -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectGroup
AS
  SELECT * FROM db.object_group;

GRANT SELECT ON ObjectGroup TO administrator;

--------------------------------------------------------------------------------
-- ObjectGroup -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ObjectGroup (
  pOwner    numeric DEFAULT current_userid()
) RETURNS	SETOF ObjectGroup
AS $$
  SELECT * FROM ObjectGroup WHERE owner = pOwner
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- db.object_group_member ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.object_group_member (
    id          numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    gid         numeric(12) NOT NULL,
    object      numeric(12) NOT NULL,
    CONSTRAINT fk_object_group_member_gid FOREIGN KEY (gid) REFERENCES db.object_group(id),
    CONSTRAINT fk_object_group_member_object FOREIGN KEY (object) REFERENCES db.object(id)
);

COMMENT ON TABLE db.object_group_member IS 'Члены группы объектов.';

COMMENT ON COLUMN db.object_group_member.id IS 'Идентификатор';
COMMENT ON COLUMN db.object_group_member.gid IS 'Группа';
COMMENT ON COLUMN db.object_group_member.object IS 'Объект';

CREATE INDEX ON db.object_group_member (gid);
CREATE INDEX ON db.object_group_member (object);

--------------------------------------------------------------------------------
-- AddObjectToGroup ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddObjectToGroup (
  pGroup	numeric,
  pObject	numeric
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM db.object_group_member WHERE gid = pGroup AND object = pObject;
  IF NOT found THEN
    INSERT INTO db.object_group_member (gid, object) VALUES (pGroup, pObject)
    RETURNING id INTO nId;
  END IF;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteObjectFromGroup -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteObjectFromGroup (
  pGroup	numeric,
  pObject	numeric
) RETURNS	void
AS $$
DECLARE
  nCount	integer;
BEGIN
  DELETE FROM db.object_group_member
   WHERE gid = pGroup
     AND object = pObject;

  SELECT count(object) INTO nCount
    FROM db.object_group_member
   WHERE gid = pGroup;

  IF nCount = 0 THEN
    DELETE FROM db.object_group WHERE id = pGroup;
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ObjectGroupMember -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectGroupMember (Id, GId, Object, Code, Name, Description)
AS
  SELECT m.id, m.gid, m.object, g.code, g.name, g.description
    FROM db.object_group_member m INNER JOIN ObjectGroup g ON g.id = m.gid;

GRANT SELECT ON ObjectGroupMember TO administrator;

--------------------------------------------------------------------------------
-- db.object_link --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.object_link (
    id              numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    object          numeric(12) NOT NULL,
    linked          numeric(12) NOT NULL,
    key             text NOT NULL,
    validFromDate	timestamp DEFAULT Now() NOT NULL,
    validToDate		timestamp DEFAULT TO_DATE('4433-12-31', 'YYYY-MM-DD') NOT NULL,
    CONSTRAINT fk_object_link_object FOREIGN KEY (object) REFERENCES db.object(id),
    CONSTRAINT fk_object_link_linked FOREIGN KEY (linked) REFERENCES db.object(id)
);

--------------------------------------------------------------------------------

COMMENT ON TABLE db.object_link IS 'Связанные с объектом объекты.';

COMMENT ON COLUMN db.object_link.object IS 'Идентификатор объекта';
COMMENT ON COLUMN db.object_link.linked IS 'Идентификатор связанного объекта';
COMMENT ON COLUMN db.object_link.key IS 'Ключ';
COMMENT ON COLUMN db.object_link.validFromDate IS 'Дата начала периода действия';
COMMENT ON COLUMN db.object_link.validToDate IS 'Дата окончания периода действия';

--------------------------------------------------------------------------------

CREATE UNIQUE INDEX ON db.object_link (object, key, validFromDate, validToDate);
CREATE UNIQUE INDEX ON db.object_link (object, linked, validFromDate, validToDate);

--------------------------------------------------------------------------------
-- FUNCTION SetObjectLink ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Устанавливает связь с объектом.
 * @param {numeric} pObject - Идентификатор объекта
 * @param {numeric} pLinked - Идентификатор связанного объекта
 * @param {text} pKey - Ключ
 * @param {timestamp} pDateFrom - Дата начала периода
 * @return {void}
 */
CREATE OR REPLACE FUNCTION SetObjectLink (
  pObject       numeric,
  pLinked       numeric,
  pKey          text,
  pDateFrom     timestamp DEFAULT oper_date()
) RETURNS       numeric
AS $$
DECLARE
  nId           numeric;
  nLinked       numeric;

  dtDateFrom    timestamp;
  dtDateTo      timestamp;
BEGIN
  -- получим дату значения в текущем диапозоне дат
  SELECT linked, validFromDate, validToDate INTO nLinked, dtDateFrom, dtDateTo
    FROM db.object_link
   WHERE object = pObject
     AND key = pKey
     AND validFromDate <= pDateFrom
     AND validToDate > pDateFrom;

  IF coalesce(nLinked, 0) <> coalesce(pLinked, 0) THEN
    -- обновим дату значения в текущем диапозоне дат
    UPDATE db.object_link SET validToDate = pDateFrom
     WHERE object = pObject
       AND key = pKey
       AND validFromDate <= pDateFrom
       AND validToDate > pDateFrom;

    IF pLinked IS NOT NULL THEN
      INSERT INTO db.object_link (object, key, linked, validFromDate, validToDate)
      VALUES (pObject, pKey, pLinked, pDateFrom, coalesce(dtDateTo, MAXDATE()))
      RETURNING id INTO nId;
    END IF;
  END IF;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetObjectLink ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает связанный с объектом объект.
 * @param {numeric} pObject - Идентификатор объекта
 * @param {text} pKey - Ключ
 * @param {timestamp} pDate - Дата
 * @return {text}
 */
CREATE OR REPLACE FUNCTION GetObjectLink (
  pObject	numeric,
  pKey	    text,
  pDate		timestamp DEFAULT oper_date()
) RETURNS	text
AS $$
DECLARE
  nLinked		numeric;
BEGIN
  SELECT linked INTO nLinked
    FROM db.object_link
   WHERE object = pObject
     AND key = pKey
     AND validFromDate <= pDate
     AND validToDate > pDate;

  RETURN nLinked;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- db.object_file --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.object_file (
    object      numeric(12) NOT NULL,
    file_name	text NOT NULL,
    file_path	text NOT NULL,
    file_size	numeric DEFAULT 0,
    file_date	timestamp DEFAULT NULL,
    file_data	bytea DEFAULT NULL,
    file_hash	text DEFAULT NULL,
    file_text	text,
    file_type	text,
    load_date	timestamp DEFAULT Now() NOT NULL,
    CONSTRAINT pk_object_file PRIMARY KEY(object, file_name, file_path),
    CONSTRAINT fk_object_file_object FOREIGN KEY (object) REFERENCES db.object(id)
);

COMMENT ON TABLE db.object_file IS 'Файлы объекта.';

COMMENT ON COLUMN db.object_file.object IS 'Объект';
COMMENT ON COLUMN db.object_file.file_name IS 'Наименование файла (без пути)';
COMMENT ON COLUMN db.object_file.file_path IS 'Путь к файлу (без имени)';
COMMENT ON COLUMN db.object_file.file_size IS 'Размер файла';
COMMENT ON COLUMN db.object_file.file_date IS 'Дата и время файла';
COMMENT ON COLUMN db.object_file.file_data IS 'Содержимое файла (если нужно)';
COMMENT ON COLUMN db.object_file.file_hash IS 'Хеш файла';
COMMENT ON COLUMN db.object_file.file_text IS 'Произвольный текст (описание)';
COMMENT ON COLUMN db.object_file.file_type IS 'Тип файла в формате MIME';
COMMENT ON COLUMN db.object_file.load_date IS 'Дата загрузки';

CREATE INDEX ON db.object_file (file_hash);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_object_file_insert()
RETURNS trigger AS $$
BEGIN
  IF NULLIF(NEW.file_path, '') IS NULL THEN
    NEW.file_path := '~/';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_object_file
  BEFORE INSERT ON db.object_file
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_object_file_insert();

--------------------------------------------------------------------------------
-- VIEW ObjectFile -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectFile (Object, Name, Path, Size, Date, Body,
    Hash, Text, Type, Loaded
)
AS
    SELECT object, file_name, file_path, file_size, file_date, encode(file_data, 'base64'),
           file_hash, file_text, file_type, load_date
      FROM db.object_file;

GRANT SELECT ON ObjectFile TO administrator;

--------------------------------------------------------------------------------
-- NewObjectFile ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION NewObjectFile (
  pObject	numeric,
  pName		text,
  pPath		text,
  pSize		numeric,
  pDate		timestamp,
  pData		bytea DEFAULT null,
  pHash		text DEFAULT null,
  pText		text DEFAULT null,
  pType		text DEFAULT null
) RETURNS	void
AS $$
BEGIN
  INSERT INTO db.object_file (object, file_name, file_path, file_size, file_date, file_data, file_hash, file_text, file_type)
  VALUES (pObject, pName, pPath, pSize, pDate, pData, pHash, pText, pType);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditObjectFile --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditObjectFile (
  pObject   numeric,
  pName		text,
  pPath		text DEFAULT null,
  pSize		numeric DEFAULT null,
  pDate		timestamp DEFAULT null,
  pData		bytea DEFAULT null,
  pHash		text DEFAULT null,
  pText		text DEFAULT null,
  pType		text DEFAULT null,
  pLoad		timestamp DEFAULT null
) RETURNS	void
AS $$
BEGIN
  UPDATE db.object_file
    SET file_path = coalesce(pPath, file_path),
        file_size = coalesce(pSize, file_size),
        file_date = coalesce(pDate, file_date),
        file_data = coalesce(pData, file_data),
        file_hash = coalesce(pHash, file_hash),
        file_text = CheckNull(coalesce(pText, file_text, '<null>')),
        file_type = CheckNull(coalesce(pType, file_type, '<null>')),
        load_date = coalesce(pLoad, load_date)
  WHERE object = pObject
    AND file_name = pName
    AND file_path = coalesce(pPath, '~/');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteObjectFile ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteObjectFile (
  pObject   numeric,
  pName		text,
  pPath		text DEFAULT null
) RETURNS	void
AS $$
BEGIN
  DELETE FROM db.object_file WHERE object = pObject AND file_name = pName AND file_path = coalesce(pPath, '~/');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SetObjectFile ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetObjectFile (
  pObject	numeric,
  pName		text,
  pPath		text,
  pSize		numeric,
  pDate		timestamp,
  pData		bytea DEFAULT null,
  pHash		text DEFAULT null,
  pText		text DEFAULT null,
  pType		text DEFAULT null
) RETURNS	int
AS $$
DECLARE
  Size          int;
BEGIN
  IF coalesce(pSize, 0) >= 0 THEN
    SELECT file_size INTO Size FROM db.object_file WHERE object = pObject AND file_name = pName;
    IF NOT FOUND THEN
      PERFORM NewObjectFile(pObject, pName, pPath, pSize, pDate, pData, pHash, pText, pType);
    ELSE
      PERFORM EditObjectFile(pObject, pName, pPath, pSize, pDate, pData, pHash, pText, pType);
    END IF;
  ELSE
    PERFORM DeleteObjectFile(pObject, pName);
  END IF;
  RETURN Size;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectFiles --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectFiles (
  pObject	numeric
) RETURNS	text[][]
AS $$
DECLARE
  arResult	text[][];
  i		    integer DEFAULT 1;
  r		    ObjectFile%rowtype;
BEGIN
  FOR r IN
    SELECT *
      FROM ObjectFile
     WHERE object = pObject
  LOOP
    arResult[i] := ARRAY[r.object, r.name, r.path, r.size, r.date, r.hash, r.text, r.type, r.loaded];
    i := i + 1;
  END LOOP;

  RETURN arResult;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectFilesJson ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectFilesJson (
  pObject	numeric
) RETURNS	json
AS $$
DECLARE
  arResult	json[];
  r		    record;
BEGIN
  FOR r IN
    SELECT Object, Name, Path, Size, Date, Hash, Text, Type, Loaded
      FROM ObjectFile
     WHERE object = pObject
  LOOP
    arResult := array_append(arResult, row_to_json(r));
  END LOOP;

  RETURN array_to_json(arResult);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectFilesJsonb ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectFilesJsonb (
  pObject	numeric
) RETURNS	jsonb
AS $$
BEGIN
  RETURN GetObjectFilesJson(pObject);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- db.object_data_type ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.object_data_type (
    id			numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    code        varchar(30) NOT NULL,
    name 		varchar(50) NOT NULL,
    description	text
);

COMMENT ON TABLE db.object_data_type IS 'Тип произвольных данных объекта.';

COMMENT ON COLUMN db.object_data_type.id IS 'Идентификатор';
COMMENT ON COLUMN db.object_data_type.code IS 'Код';
COMMENT ON COLUMN db.object_data_type.name IS 'Наименование';
COMMENT ON COLUMN db.object_data_type.description IS 'Описание';

CREATE INDEX ON db.object_data_type (code);

INSERT INTO db.object_data_type (code, name, description) VALUES ('text', 'Текст', 'Произвольная строка');
INSERT INTO db.object_data_type (code, name, description) VALUES ('json', 'JSON', 'JavaScript Object Notation');
INSERT INTO db.object_data_type (code, name, description) VALUES ('xml', 'XML', 'eXtensible Markup Language');

--------------------------------------------------------------------------------
-- GetObjectDataType -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectDataType (
  pCode		varchar
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM db.object_data_type WHERE code = pCode;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ObjectDataType --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectDataType (Id, Code, Name, Description)
AS
  SELECT id, code, name, description
    FROM db.object_data_type;

GRANT SELECT ON ObjectDataType TO administrator;

--------------------------------------------------------------------------------
-- db.object_data --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.object_data (
    object      numeric(12) NOT NULL,
    type        numeric(12) NOT NULL,
    code        varchar(30) NOT NULL,
    data        text,
    CONSTRAINT pk_object_data PRIMARY KEY(object, type, code),
    CONSTRAINT fk_object_data_object FOREIGN KEY (object) REFERENCES db.object(id),
    CONSTRAINT fk_object_data_type FOREIGN KEY (type) REFERENCES db.object_data_type(id)
);

COMMENT ON TABLE db.object_data IS 'Произвольные данные объекта.';

COMMENT ON COLUMN db.object_data.object IS 'Объект';
COMMENT ON COLUMN db.object_data.type IS 'Тип произвольных данных объекта';
COMMENT ON COLUMN db.object_data.code IS 'Код';
COMMENT ON COLUMN db.object_data.data IS 'Данные';

CREATE INDEX ON db.object_data (object);

--------------------------------------------------------------------------------
-- VIEW ObjectData -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectData (Object, Type, TypeCode, TypeName, TypeDescription, Code, Data)
AS
  SELECT d.object, d.type, t.code, t.name, t.description, d.code, d.data
    FROM db.object_data d INNER JOIN db.object_data_type t ON t.id = d.type;

GRANT SELECT ON ObjectData TO administrator;

--------------------------------------------------------------------------------
-- NewObjectData ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION NewObjectData (
  pObject	numeric,
  pType		numeric,
  pCode		varchar,
  pData		text
) RETURNS	void
AS $$
BEGIN
  INSERT INTO db.object_data (object, type, code, data)
  VALUES (pObject, pType, pCode, pData);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditObjectData --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditObjectData (
  pObject	numeric,
  pType		numeric,
  pCode		varchar,
  pData		text
) RETURNS	void
AS $$
BEGIN
  UPDATE db.object_data
     SET data = coalesce(pData, data)
   WHERE object = pObject
     AND type = pType
     AND code = pCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteObjectData ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteObjectData (
  pObject	numeric,
  pType		numeric,
  pCode		varchar
) RETURNS	void
AS $$
BEGIN
  DELETE FROM db.object_data WHERE object = pObject AND type = pType AND code = pCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SetObjectData ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetObjectData (
  pObject	numeric,
  pType		numeric,
  pCode		varchar,
  pData		text
) RETURNS	text
AS $$
DECLARE
  vData		text;
BEGIN
  IF pData IS NOT NULL THEN
    SELECT data INTO vData FROM db.object_data WHERE object = pObject AND type = pType AND code = pCode;
    IF NOT FOUND THEN
      PERFORM NewObjectData(pObject, pType, pCode, pData);
    ELSE
      PERFORM EditObjectData(pObject, pType, pCode, pData);
    END IF;
  ELSE
    PERFORM DeleteObjectData(pObject, pType, pCode);
  END IF;
  RETURN vData;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectData ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectData (
  pObject	numeric,
  pType		numeric,
  pCode		varchar
) RETURNS	text
AS $$
DECLARE
  vData		text;
BEGIN
  SELECT data INTO vData FROM db.object_data WHERE object = pObject AND type = pType AND code = pCode;
  RETURN vData;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectData ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectData (
  pObject	numeric
) RETURNS	text[][]
AS $$
DECLARE
  arResult	text[][];
  i             integer DEFAULT 1;
  r             ObjectData%rowtype;
BEGIN
  FOR r IN
    SELECT *
      FROM ObjectData
     WHERE object = pObject
  LOOP
    arResult[i] := ARRAY[pObject, r.type, r.typeCode, r.code, r.data];
    i := i + 1;
  END LOOP;

  RETURN arResult;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectDataJson -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectDataJson (
  pObject	numeric
) RETURNS	json
AS $$
DECLARE
  arResult	json[];
  r             record;
BEGIN
  FOR r IN
    SELECT object, type, typeCode, Code, Data
      FROM ObjectData
     WHERE object = pObject
  LOOP
    arResult := array_append(arResult, row_to_json(r));
  END LOOP;

  RETURN array_to_json(arResult);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectDataJsonb ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectDataJsonb (
  pObject	numeric
) RETURNS	jsonb
AS $$
BEGIN
  RETURN GetObjectDataJson(pObject);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- db.object_coordinates -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.object_coordinates (
    object          numeric(12) NOT NULL,
    code            varchar(30) NOT NULL,
    latitude        numeric NOT NULL,
    longitude       numeric NOT NULL,
    accuracy        numeric NOT NULL DEFAULT 0,
    label           varchar(50),
    description	    text,
    validFromDate   timestamptz DEFAULT Now() NOT NULL,
    validToDate     timestamptz DEFAULT TO_DATE('4433-12-31', 'YYYY-MM-DD') NOT NULL,
    CONSTRAINT pk_object_coordinates PRIMARY KEY(object, code, validFromDate, validToDate),
    CONSTRAINT fk_object_coordinates_object FOREIGN KEY (object) REFERENCES db.object(id)
);

COMMENT ON TABLE db.object_coordinates IS 'Произвольные данные объекта.';

COMMENT ON COLUMN db.object_coordinates.object IS 'Объект';
COMMENT ON COLUMN db.object_coordinates.code IS 'Код';
COMMENT ON COLUMN db.object_coordinates.latitude IS 'Широта';
COMMENT ON COLUMN db.object_coordinates.longitude IS 'Долгота';
COMMENT ON COLUMN db.object_coordinates.accuracy IS 'Точность (высота над уровнем моря)';
COMMENT ON COLUMN db.object_coordinates.label IS 'Метка';
COMMENT ON COLUMN db.object_coordinates.description IS 'Описание';
COMMENT ON COLUMN db.object_coordinates.validFromDate IS 'Дата начала периода действия';
COMMENT ON COLUMN db.object_coordinates.validToDate IS 'Дата окончания периода действия';

CREATE INDEX ON db.object_coordinates (object);

--------------------------------------------------------------------------------
-- VIEW ObjectCoordinates ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectCoordinates
AS
  SELECT * FROM db.object_coordinates;

GRANT SELECT ON ObjectCoordinates TO administrator;

--------------------------------------------------------------------------------
-- NewObjectCoordinates --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION NewObjectCoordinates (
  pObject         numeric,
  pCode           varchar,
  pLatitude       numeric,
  pLongitude      numeric,
  pAccuracy       numeric DEFAULT 0,
  pLabel          varchar DEFAULT null,
  pDescription    text DEFAULT null,
  pDateFrom       timestamptz DEFAULT Now()
) RETURNS         void
AS $$
DECLARE
  dtDateFrom      timestamp;
  dtDateTo        timestamp;
BEGIN
  -- получим дату значения в текущем диапозоне дат
  SELECT validFromDate, validToDate INTO dtDateFrom, dtDateTo
    FROM db.object_coordinates
   WHERE object = pObject
     AND code = pCode
     AND validFromDate <= pDateFrom
     AND validToDate > pDateFrom;

  IF coalesce(dtDateFrom, MINDATE()) = pDateFrom THEN
    -- обновим значение в текущем диапозоне дат
    UPDATE db.object_coordinates
       SET latitude = pLatitude, longitude = pLongitude, accuracy = pAccuracy,
           label = coalesce(pLabel, label),
           description = coalesce(pDescription, description)
     WHERE object = pObject
       AND code = pCode
       AND validFromDate <= pDateFrom
       AND validToDate > pDateFrom;
  ELSE
    -- обновим дату значения в текущем диапозоне дат
    UPDATE db.object_coordinates SET validToDate = pDateFrom
     WHERE object = pObject
       AND code = pCode
       AND validFromDate <= pDateFrom
       AND validToDate > pDateFrom;

    INSERT INTO db.object_coordinates (object, code, latitude, longitude, accuracy, label, description, validFromDate, validToDate)
    VALUES (pObject, pCode, pLatitude, pLongitude, pAccuracy, pLabel, pDescription, pDateFrom, coalesce(dtDateTo, MAXDATE()));
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteObjectCoordinates -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteObjectCoordinates (
  pObject	numeric,
  pCode		varchar
) RETURNS	void
AS $$
BEGIN
  DELETE FROM db.object_coordinates WHERE object = pObject AND code = pCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectCoordinates --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectCoordinates (
  pObject       numeric,
  pCode         varchar
) RETURNS       ObjectCoordinates
AS $$
  SELECT * FROM ObjectCoordinates WHERE object = pObject AND code = pCode;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectCoordinatesJson ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectCoordinatesJson (
  pObject	numeric,
  pCode         varchar DEFAULT NULL,
  pDateFrom     timestamptz DEFAULT Now()
) RETURNS	json
AS $$
DECLARE
  arResult	json[];
  r             record;
BEGIN
  FOR r IN
    SELECT *
      FROM ObjectCoordinates
     WHERE object = pObject
       AND code = coalesce(pCode, code)
       AND validFromDate <= pDateFrom
       AND validToDate > pDateFrom
  LOOP
    arResult := array_append(arResult, row_to_json(r));
  END LOOP;

  RETURN array_to_json(arResult);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetObjectCoordinatesJsonb ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetObjectCoordinatesJsonb (
  pObject	numeric
) RETURNS	jsonb
AS $$
BEGIN
  RETURN GetObjectCoordinatesJson(pObject);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
