--------------------------------------------------------------------------------
-- OBJECT ----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.object (
    id			numeric(12) PRIMARY KEY,
    parent		numeric(12),
    entity		numeric(12) NOT NULL,
    class		numeric(12) NOT NULL,
    type		numeric(12) NOT NULL,
    state_type  numeric(12),
    state		numeric(12),
    suid		numeric(12) NOT NULL,
    owner		numeric(12) NOT NULL,
    oper		numeric(12) NOT NULL,
    label		text,
    data		text,
    pdate		timestamp NOT NULL DEFAULT Now(),
    ldate		timestamp NOT NULL DEFAULT Now(),
    udate		timestamp NOT NULL DEFAULT Now(),
    CONSTRAINT fk_object_parent FOREIGN KEY (parent) REFERENCES db.object(id),
    CONSTRAINT fk_object_entity FOREIGN KEY (entity) REFERENCES db.entity(id),
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
COMMENT ON COLUMN db.object.entity IS 'Сущность';
COMMENT ON COLUMN db.object.class IS 'Класс';
COMMENT ON COLUMN db.object.type IS 'Тип';
COMMENT ON COLUMN db.object.state_type IS 'Тип состояния';
COMMENT ON COLUMN db.object.state IS 'Состояние';
COMMENT ON COLUMN db.object.suid IS 'Системный пользователь';
COMMENT ON COLUMN db.object.owner IS 'Владелец (пользователь)';
COMMENT ON COLUMN db.object.oper IS 'Пользователь совершивший последнюю операцию';
COMMENT ON COLUMN db.object.label IS 'Метка';
COMMENT ON COLUMN db.object.data IS 'Данные';
COMMENT ON COLUMN db.object.pdate IS 'Физическая дата';
COMMENT ON COLUMN db.object.ldate IS 'Логическая дата';
COMMENT ON COLUMN db.object.udate IS 'Дата последнего изменения';

CREATE INDEX ON db.object (parent);
CREATE INDEX ON db.object (entity);
CREATE INDEX ON db.object (class);
CREATE INDEX ON db.object (type);
CREATE INDEX ON db.object (state_type);
CREATE INDEX ON db.object (state);

CREATE INDEX ON db.object (suid);
CREATE INDEX ON db.object (owner);
CREATE INDEX ON db.object (oper);

CREATE INDEX ON db.object (label);
CREATE INDEX ON db.object (label text_pattern_ops);

--CREATE INDEX ON db.object (data);
--CREATE INDEX ON db.object (data text_pattern_ops);

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
  SELECT entity, abstract INTO NEW.entity, bAbstract FROM db.class_tree WHERE id = NEW.class;

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
DECLARE
  nUserId	numeric;
BEGIN
  INSERT INTO db.aom SELECT NEW.id;
  INSERT INTO db.aou (object, userid, deny, allow) SELECT NEW.id, userid, SubString(deny FROM 3 FOR 3), SubString(allow FROM 3 FOR 3) FROM db.acu WHERE class = NEW.class;

  INSERT INTO db.aou SELECT NEW.id, NEW.owner, B'000', B'111'
	ON CONFLICT (object, userid) DO UPDATE SET deny = B'000', allow = B'111';

  IF NEW.parent IS NOT NULL THEN
    SELECT owner INTO nUserId FROM db.object WHERE id = NEW.parent;
    IF NEW.owner <> nUserId THEN
	  UPDATE db.aou SET allow = allow | B'100' WHERE object = NEW.id AND userid = nUserId;
	  IF NOT FOUND THEN
		INSERT INTO db.aou SELECT NEW.id, nUserId, B'000', B'100';
	  END IF;
	END IF;
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
    SELECT entity INTO NEW.entity FROM db.class_tree WHERE id = NEW.class;

    IF OLD.entity <> NEW.entity THEN
      PERFORM IncorrectEntity();
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
	INSERT INTO db.aou SELECT NEW.id, NEW.owner, B'000', B'111'
	  ON CONFLICT (object, userid) DO UPDATE SET deny = B'000', allow = B'111';
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
    entity		numeric(12) NOT NULL,
    CONSTRAINT pk_aou PRIMARY KEY(object, userid),
    CONSTRAINT fk_aou_object FOREIGN KEY (object) REFERENCES db.object(id),
    CONSTRAINT fk_aou_userid FOREIGN KEY (userid) REFERENCES db.user(id),
    CONSTRAINT fk_aou_entity FOREIGN KEY (entity) REFERENCES db.entity(id)
);

COMMENT ON TABLE db.aou IS 'Доступ пользователя и групп пользователей к объекту.';

COMMENT ON COLUMN db.aou.object IS 'Объект';
COMMENT ON COLUMN db.aou.userid IS 'Пользователь';
COMMENT ON COLUMN db.aou.deny IS 'Запрещающие биты: {sud}. Где: {s - select; u - update; d - delete}';
COMMENT ON COLUMN db.aou.allow IS 'Разрешающие биты: {sud}. Где: {s - select; u - update; d - delete}';
COMMENT ON COLUMN db.aou.mask IS 'Маска доступа: {sud}. Где: {s - select; u - update; d - delete}';
COMMENT ON COLUMN db.aou.entity IS 'Сущность';

CREATE INDEX ON db.aou (object);
CREATE INDEX ON db.aou (userid);
CREATE INDEX ON db.aou (entity);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_aou_before()
RETURNS TRIGGER AS $$
BEGIN
  IF (TG_OP = 'INSERT') THEN
    SELECT entity INTO NEW.entity FROM db.object WHERE id = NEW.object;
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

--------------------------------------------------------------------------------

CREATE TRIGGER t_object_group
  BEFORE INSERT ON db.object_group
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_object_group_insert();

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
-- db.object_coordinates -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.object_coordinates (
    id				bigserial PRIMARY KEY NOT NULL,
    object          numeric(12) NOT NULL,
    code            text NOT NULL,
    latitude        numeric NOT NULL,
    longitude       numeric NOT NULL,
    accuracy        numeric NOT NULL DEFAULT 0,
    label           text,
    description	    text,
    data			jsonb,
    validFromDate   timestamptz DEFAULT Now() NOT NULL,
    validToDate     timestamptz DEFAULT TO_DATE('4433-12-31', 'YYYY-MM-DD') NOT NULL,
    CONSTRAINT fk_object_coordinates_object FOREIGN KEY (object) REFERENCES db.object(id)
);

COMMENT ON TABLE db.object_coordinates IS 'Произвольные данные объекта.';

COMMENT ON COLUMN db.object_coordinates.id IS 'Идентификатор';
COMMENT ON COLUMN db.object_coordinates.object IS 'Объект';
COMMENT ON COLUMN db.object_coordinates.code IS 'Код';
COMMENT ON COLUMN db.object_coordinates.latitude IS 'Широта';
COMMENT ON COLUMN db.object_coordinates.longitude IS 'Долгота';
COMMENT ON COLUMN db.object_coordinates.accuracy IS 'Точность (высота над уровнем моря)';
COMMENT ON COLUMN db.object_coordinates.label IS 'Метка';
COMMENT ON COLUMN db.object_coordinates.description IS 'Описание';
COMMENT ON COLUMN db.object_coordinates.data IS 'Данные в произвольном формате';
COMMENT ON COLUMN db.object_coordinates.validFromDate IS 'Дата начала периода действия';
COMMENT ON COLUMN db.object_coordinates.validToDate IS 'Дата окончания периода действия';

CREATE UNIQUE INDEX ON db.object_coordinates (object, code, validFromDate, validToDate);
CREATE INDEX ON db.object_coordinates (object);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_object_coordinates_after_insert()
RETURNS trigger AS $$
BEGIN
  IF NEW.validToDate = MAXDATE() THEN
    PERFORM pg_notify('geo', json_build_object('id', NEW.id, 'object', NEW.object, 'code', NEW.code)::text);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_object_coordinates_after_insert
  AFTER INSERT ON db.object_coordinates
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_object_coordinates_after_insert();

