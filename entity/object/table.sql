--------------------------------------------------------------------------------
-- OBJECT ----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.object (
    id          uuid PRIMARY KEY,
    parent      uuid REFERENCES db.object(id),
    scope       uuid NOT NULL REFERENCES db.scope(id),
    entity      uuid NOT NULL REFERENCES db.entity(id),
    class       uuid NOT NULL REFERENCES db.class_tree(id),
    type        uuid NOT NULL REFERENCES db.type(id),
    state_type  uuid REFERENCES db.state_type(id),
    state       uuid REFERENCES db.state(id),
    suid        uuid NOT NULL REFERENCES db.user(id),
    owner       uuid NOT NULL REFERENCES db.user(id),
    oper        uuid NOT NULL REFERENCES db.user(id),
    pdate       timestamptz NOT NULL DEFAULT Now(),
    ldate       timestamptz NOT NULL DEFAULT Now(),
    udate       timestamptz NOT NULL DEFAULT Now()
);

COMMENT ON TABLE db.object IS 'Список объектов.';

COMMENT ON COLUMN db.object.id IS 'Идентификатор';
COMMENT ON COLUMN db.object.parent IS 'Родитель';
COMMENT ON COLUMN db.object.scope IS 'Область видимости базы данных';
COMMENT ON COLUMN db.object.entity IS 'Сущность';
COMMENT ON COLUMN db.object.class IS 'Класс';
COMMENT ON COLUMN db.object.type IS 'Тип';
COMMENT ON COLUMN db.object.state_type IS 'Тип состояния';
COMMENT ON COLUMN db.object.state IS 'Состояние';
COMMENT ON COLUMN db.object.suid IS 'Системный пользователь';
COMMENT ON COLUMN db.object.owner IS 'Владелец (пользователь)';
COMMENT ON COLUMN db.object.oper IS 'Пользователь совершивший последнюю операцию';
COMMENT ON COLUMN db.object.pdate IS 'Физическая дата';
COMMENT ON COLUMN db.object.ldate IS 'Логическая дата';
COMMENT ON COLUMN db.object.udate IS 'Дата последнего изменения';

CREATE INDEX ON db.object (parent);
CREATE INDEX ON db.object (scope);
CREATE INDEX ON db.object (entity);
CREATE INDEX ON db.object (class);
CREATE INDEX ON db.object (type);
CREATE INDEX ON db.object (state_type);
CREATE INDEX ON db.object (state);

CREATE INDEX ON db.object (suid);
CREATE INDEX ON db.object (owner);
CREATE INDEX ON db.object (oper);

CREATE INDEX ON db.object (pdate);
CREATE INDEX ON db.object (ldate);
CREATE INDEX ON db.object (udate);

--------------------------------------------------------------------------------
-- db.object_text --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.object_text (
    object      uuid NOT NULL REFERENCES db.object(id) ON DELETE CASCADE,
    locale      uuid NOT NULL REFERENCES db.locale(id) ON DELETE RESTRICT,
    label       text,
    text        text,
    PRIMARY KEY (object, locale)
);

--------------------------------------------------------------------------------

COMMENT ON TABLE db.object_text IS 'Текст объекта.';

COMMENT ON COLUMN db.object_text.object IS 'Идентификатор объекта';
COMMENT ON COLUMN db.object_text.locale IS 'Идентификатор локали';
COMMENT ON COLUMN db.object_text.label IS 'Метка.';
COMMENT ON COLUMN db.object_text.text IS 'Текст.';

--------------------------------------------------------------------------------

CREATE INDEX ON db.object_text (object);
CREATE INDEX ON db.object_text (locale);

CREATE INDEX ON db.object_text (label);
CREATE INDEX ON db.object_text (label text_pattern_ops);

ALTER TABLE db.object_text
    ADD COLUMN searchable_en tsvector
    GENERATED ALWAYS AS (to_tsvector('english', coalesce(label, '') || ' ' || coalesce(text, ''))) STORED;

ALTER TABLE db.object_text
    ADD COLUMN searchable_ru tsvector
    GENERATED ALWAYS AS (to_tsvector('russian', coalesce(label, '') || ' ' || coalesce(text, ''))) STORED;

COMMENT ON COLUMN db.object_text.searchable_en IS 'Полнотекстовый поиск (en)';
COMMENT ON COLUMN db.object_text.searchable_ru IS 'Полнотекстовый поиск (ru)';

CREATE INDEX ON db.object_text USING GIN (searchable_en);
CREATE INDEX ON db.object_text USING GIN (searchable_ru);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_object_before_insert()
RETURNS trigger AS $$
DECLARE
  bAbstract    boolean;
BEGIN
  IF NEW.id IS NULL THEN
    SELECT gen_kernel_uuid('8') INTO NEW.id;
  END IF;

  SELECT class INTO NEW.class FROM db.type WHERE id = NEW.type;
  SELECT entity, abstract INTO NEW.entity, bAbstract FROM db.class_tree WHERE id = NEW.class;

  IF bAbstract THEN
    PERFORM AbstractError();
  END IF;

  SELECT type INTO NEW.state_type FROM db.state WHERE id = NEW.state;

  IF NEW.scope IS NULL THEN
    SELECT scope INTO NEW.scope FROM db.area WHERE id = GetSessionArea(current_session());
  ELSE
    PERFORM FROM db.area WHERE id = GetSessionArea(current_session()) AND scope = NEW.scope;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'ERR-40000: Area "%" not present in scope "%".', GetSessionArea(current_session()), GetScopeName(NEW.scope);
    END IF;
  END IF;

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
  uUserId    uuid;
  vEntity   text;
BEGIN
  INSERT INTO db.aom SELECT NEW.id;
  INSERT INTO db.aou (object, userid, deny, allow) SELECT NEW.id, userid, SubString(deny FROM 3 FOR 3), SubString(allow FROM 3 FOR 3) FROM db.acu WHERE class = NEW.class;

  INSERT INTO db.aou (object, userid, deny, allow) SELECT NEW.id, NEW.owner, B'000', B'111'
    ON CONFLICT (object, userid) DO UPDATE SET deny = B'000', allow = B'111';

  SELECT code INTO vEntity FROM db.entity WHERE id = NEW.entity;

  IF vEntity = 'message' THEN
    IF NEW.parent IS NOT NULL THEN
      SELECT owner INTO uUserId FROM db.object WHERE id = NEW.parent;
      IF NEW.owner <> uUserId THEN
        UPDATE db.aou SET allow = allow | B'100' WHERE object = NEW.id AND userid = uUserId;
        IF NOT FOUND THEN
          INSERT INTO db.aou (object, userid, deny, allow) SELECT NEW.id, uUserId, B'000', B'100';
        END IF;
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
DECLARE
  bSystem   boolean;
BEGIN
  IF NOT CheckObjectAccess(NEW.id, B'010') THEN
    PERFORM AccessDenied();
  END IF;

  IF OLD.type IS DISTINCT FROM NEW.type THEN
    SELECT class INTO NEW.class FROM db.type WHERE id = NEW.type;
    SELECT entity INTO NEW.entity FROM db.class_tree WHERE id = NEW.class;

    IF OLD.entity IS DISTINCT FROM NEW.entity THEN
      PERFORM IncorrectEntity();
    END IF;
  END IF;

  IF OLD.class IS DISTINCT FROM NEW.class THEN
    NEW.state := GetState(NEW.class, OLD.state_type);

    IF OLD.state IS DISTINCT FROM NEW.state THEN
      UPDATE db.object_state SET state = NEW.state
       WHERE object = OLD.id
         AND state = OLD.state;
    END IF;
  END IF;

  IF OLD.state IS DISTINCT FROM NEW.state THEN
    IF NEW.state IS NOT NULL THEN
      SELECT type INTO NEW.state_type FROM db.state WHERE id = NEW.state;
    ELSE
      NEW.state_type := NULL;
    END IF;
  END IF;

  IF OLD.scope IS DISTINCT FROM NEW.scope THEN
    PERFORM FROM db.area WHERE id = GetSessionArea(current_session()) AND scope = NEW.scope;
    IF NOT FOUND THEN
      NEW.scope := OLD.scope;
    END IF;
  END IF;

  IF OLD.owner IS DISTINCT FROM NEW.owner THEN
    SELECT system INTO bSystem FROM users WHERE id = OLD.owner AND scope = NEW.scope;
    IF NOT bSystem THEN
      DELETE FROM db.aou WHERE object = NEW.id AND userid = OLD.owner AND mask = B'111';
    END IF;
    INSERT INTO db.aou (object, userid, deny, allow) SELECT NEW.id, NEW.owner, B'000', B'111'
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
    object      uuid NOT NULL REFERENCES db.object(id) ON DELETE CASCADE,
    mask        bit(9) DEFAULT B'111100000' NOT NULL,
    PRIMARY KEY (object)
);

COMMENT ON TABLE db.aom IS 'Маска доступа к объекту.';

COMMENT ON COLUMN db.aom.object IS 'Объект';
COMMENT ON COLUMN db.aom.mask IS 'Маска доступа. Девять бит (a:{u:sud}{g:sud}{o:sud}), по три бита на действие s - select, u - update, d - delete, для: a - all (все) = u - user (владелец) g - group (группа) o - other (остальные)';

--------------------------------------------------------------------------------
-- TABLE db.aou ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.aou (
    object      uuid NOT NULL REFERENCES db.object(id) ON DELETE CASCADE,
    userid      uuid NOT NULL REFERENCES db.user(id) ON DELETE CASCADE,
    deny        bit(3) NOT NULL,
    allow       bit(3) NOT NULL,
    mask        bit(3) DEFAULT B'000' NOT NULL,
    entity      uuid NOT NULL REFERENCES db.entity(id) ON DELETE RESTRICT,
    PRIMARY KEY (object, userid)
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
CREATE INDEX ON db.aou (entity, userid, mask);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_aou_before()
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
  EXECUTE PROCEDURE db.ft_aou_before();

--------------------------------------------------------------------------------
-- TABLE db.oma ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.oma (
    object      uuid NOT NULL REFERENCES db.object(id) ON DELETE CASCADE,
    method      uuid NOT NULL REFERENCES db.method(id) ON DELETE CASCADE,
    userid      uuid NOT NULL REFERENCES db.user(id) ON DELETE CASCADE,
    mask        bit(3) DEFAULT B'000' NOT NULL,
    PRIMARY KEY (object, method, userid)
);

COMMENT ON TABLE db.oma IS 'Доступ пользователя к методам объекта.';

COMMENT ON COLUMN db.oma.object IS 'Объект';
COMMENT ON COLUMN db.oma.method IS 'Метод';
COMMENT ON COLUMN db.amu.userid IS 'Пользователь';
COMMENT ON COLUMN db.oma.mask IS 'Маска доступа: {xve}. Где: {x - execute, v - visible, e - enable}';

CREATE INDEX ON db.oma (object);
CREATE INDEX ON db.oma (method);
CREATE INDEX ON db.oma (userid);

--------------------------------------------------------------------------------
-- OBJECT_STATE ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.object_state (
    id               uuid PRIMARY KEY DEFAULT gen_kernel_uuid('8'),
    object           uuid NOT NULL REFERENCES db.object(id),
    state            uuid NOT NULL REFERENCES db.state(id),
    validFromDate    timestamptz DEFAULT Now() NOT NULL,
    validToDate      timestamptz DEFAULT TO_DATE('4433-12-31', 'YYYY-MM-DD') NOT NULL
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
      PERFORM DateValidityPeriod();
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
    object        uuid NOT NULL REFERENCES db.object(id),
    method        uuid NOT NULL REFERENCES db.method(id),
    result        jsonb DEFAULT NULL,
    PRIMARY KEY (object, method)
);

COMMENT ON TABLE db.method_stack IS 'Стек выполнения метода.';

COMMENT ON COLUMN db.method_stack.object IS 'Объект';
COMMENT ON COLUMN db.method_stack.method IS 'Метод';
COMMENT ON COLUMN db.method_stack.result IS 'Результат выполения (при наличии)';

--------------------------------------------------------------------------------
-- db.object_group -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.object_group (
    id          uuid PRIMARY KEY,
    owner       uuid NOT NULL REFERENCES db.user(id) ON DELETE CASCADE,
    code        text NOT NULL,
    name        text NOT NULL,
    description text
);

COMMENT ON TABLE db.object_group IS 'Группа объектов.';

COMMENT ON COLUMN db.object_group.id IS 'Идентификатор';
COMMENT ON COLUMN db.object_group.owner IS 'Владелец';
COMMENT ON COLUMN db.object_group.code IS 'Код';
COMMENT ON COLUMN db.object_group.name IS 'Наименование';
COMMENT ON COLUMN db.object_group.description IS 'Описание';

CREATE UNIQUE INDEX ON db.object_group (owner, code);

CREATE INDEX ON db.object_group (owner);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_object_group_insert()
RETURNS trigger AS $$
BEGIN
  IF NEW.id IS NULL THEN
    NEW.id := gen_random_uuid();
  END IF;

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
   SET search_path = kernel, public, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_object_group
  BEFORE INSERT ON db.object_group
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_object_group_insert();

--------------------------------------------------------------------------------
-- db.object_group_member ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.object_group_member (
    gid         uuid NOT NULL REFERENCES db.object_group(id) ON DELETE CASCADE,
    object      uuid NOT NULL REFERENCES db.object(id) ON DELETE CASCADE,
    PRIMARY KEY (gid, object)
);

COMMENT ON TABLE db.object_group_member IS 'Члены группы объектов.';

COMMENT ON COLUMN db.object_group_member.gid IS 'Группа';
COMMENT ON COLUMN db.object_group_member.object IS 'Объект';

CREATE INDEX ON db.object_group_member (gid);
CREATE INDEX ON db.object_group_member (object);

--------------------------------------------------------------------------------
-- db.object_link --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.object_link (
    id              uuid PRIMARY KEY DEFAULT gen_kernel_uuid('8'),
    object          uuid NOT NULL REFERENCES db.object(id) ON DELETE CASCADE,
    linked          uuid NOT NULL REFERENCES db.object(id) ON DELETE CASCADE,
    key             text NOT NULL,
    validFromDate   timestamptz DEFAULT Now() NOT NULL,
    validToDate     timestamptz DEFAULT TO_DATE('4433-12-31', 'YYYY-MM-DD') NOT NULL
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
    object      uuid NOT NULL REFERENCES db.object(id) ON DELETE CASCADE,
    file        uuid NOT NULL REFERENCES db.file(id) ON DELETE RESTRICT,
    updated     timestamptz DEFAULT Now() NOT NULL,
    PRIMARY KEY (object, file)
);

COMMENT ON TABLE db.object_file IS 'Файлы объекта.';

COMMENT ON COLUMN db.object_file.object IS 'Объект';
COMMENT ON COLUMN db.object_file.file IS 'Файл';
COMMENT ON COLUMN db.object_file.updated IS 'Дата обновления';

CREATE INDEX ON db.object_file (object);
CREATE INDEX ON db.object_file (file);

--------------------------------------------------------------------------------
-- db.object_data --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.object_data (
    object      uuid NOT NULL REFERENCES db.object(id) ON DELETE CASCADE,
    type        text NOT NULL DEFAULT 'text',
    code        text NOT NULL,
    data        text,
    PRIMARY KEY (object, type, code),
    CHECK (type IN ('text', 'json', 'xml', 'base64'))
);

COMMENT ON TABLE db.object_data IS 'Произвольные данные объекта.';

COMMENT ON COLUMN db.object_data.object IS 'Объект';
COMMENT ON COLUMN db.object_data.type IS 'Тип произвольных данных объекта';
COMMENT ON COLUMN db.object_data.code IS 'Код';
COMMENT ON COLUMN db.object_data.data IS 'Данные';

CREATE INDEX ON db.object_data (object);
CREATE INDEX ON db.object_data (type);
CREATE INDEX ON db.object_data (code);
CREATE INDEX ON db.object_data (object, type, code);

--------------------------------------------------------------------------------
-- db.object_coordinates -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.object_coordinates (
    id              uuid PRIMARY KEY DEFAULT gen_kernel_uuid('8'),
    object          uuid NOT NULL REFERENCES db.object(id),
    code            text NOT NULL,
    latitude        numeric NOT NULL,
    longitude       numeric NOT NULL,
    accuracy        numeric NOT NULL DEFAULT 0,
    label           text,
    description     text,
    data            jsonb,
    validFromDate   timestamptz DEFAULT Now() NOT NULL,
    validToDate     timestamptz DEFAULT TO_DATE('4433-12-31', 'YYYY-MM-DD') NOT NULL
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
