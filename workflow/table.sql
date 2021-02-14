--------------------------------------------------------------------------------
-- ENTITY ----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.entity (
    id			numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    code		text NOT NULL,
    name		text,
    description text
);

COMMENT ON TABLE db.entity IS 'Сущность.';
COMMENT ON COLUMN db.entity.id IS 'Идентификатор';
COMMENT ON COLUMN db.entity.code IS 'Код';
COMMENT ON COLUMN db.entity.name IS 'Наименование';
COMMENT ON COLUMN db.entity.description IS 'Описание';

CREATE UNIQUE INDEX ON db.entity (code);

--------------------------------------------------------------------------------
-- CLASS -----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.class_tree (
    id			numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    parent		numeric(12),
    entity		numeric(12) NOT NULL,
    level		integer NOT NULL,
    code		text NOT NULL,
    label		text NOT NULL,
    abstract    boolean DEFAULT TRUE NOT NULL,
    CONSTRAINT fk_class_tree_parent FOREIGN KEY (parent) REFERENCES db.class_tree(id),
    CONSTRAINT fk_class_tree_entity FOREIGN KEY (entity) REFERENCES db.entity(id)
);

COMMENT ON TABLE db.class_tree IS 'Дерево классов.';

COMMENT ON COLUMN db.class_tree.id IS 'Идентификатор';
COMMENT ON COLUMN db.class_tree.parent IS 'Ссылка на родительский узел';
COMMENT ON COLUMN db.class_tree.entity IS 'Сущность';
COMMENT ON COLUMN db.class_tree.level IS 'Уровень вложенности';
COMMENT ON COLUMN db.class_tree.code IS 'Код';
COMMENT ON COLUMN db.class_tree.label IS 'Метка';
COMMENT ON COLUMN db.class_tree.abstract IS 'Абстрактный: Да/Нет';

--------------------------------------------------------------------------------

CREATE INDEX ON db.class_tree (parent);
CREATE INDEX ON db.class_tree (entity);

CREATE UNIQUE INDEX ON db.class_tree (code);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_class_tree_after_insert()
RETURNS trigger AS $$
BEGIN
  IF NEW.parent IS NULL THEN
    --INSERT INTO db.acu SELECT NEW.id, GetGroup('system'), B'00000', B'00000';
    INSERT INTO db.acu SELECT NEW.id, GetGroup('administrator'), B'00000', B'11111';
    INSERT INTO db.acu SELECT NEW.id, GetUser('apibot'), B'00000', B'01110';
  ELSE
    INSERT INTO db.acu SELECT NEW.id, userid, deny, allow FROM db.acu WHERE class = NEW.parent;

    IF NEW.code = 'document' THEN
      INSERT INTO db.acu SELECT NEW.id, GetGroup('operator'), B'00000', B'11110';
      INSERT INTO db.acu SELECT NEW.id, GetGroup('user'), B'00000', B'11000';
    ELSIF NEW.code = 'reference' THEN
      INSERT INTO db.acu SELECT NEW.id, GetGroup('operator'), B'00000', B'11110';
      INSERT INTO db.acu SELECT NEW.id, GetGroup('user'), B'00000', B'10100';
    ELSIF NEW.code = 'message' THEN
      UPDATE db.acu SET allow = B'11000' WHERE acu.class = NEW.id AND userid = GetGroup('operator');
      INSERT INTO db.acu SELECT NEW.id, GetUser('mailbot'), B'00000', B'01110';
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_class_tree_insert
  AFTER INSERT ON db.class_tree
  FOR EACH ROW
  EXECUTE PROCEDURE ft_class_tree_after_insert();

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_class_tree_before_delete()
RETURNS trigger AS $$
BEGIN
  DELETE FROM db.acu WHERE class = OLD.ID;

  RETURN OLD;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_class_tree_before_delete
  BEFORE DELETE ON db.class_tree
  FOR EACH ROW
  EXECUTE PROCEDURE ft_class_tree_before_delete();

--------------------------------------------------------------------------------
-- TABLE db.acu ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.acu (
    class		numeric(12) NOT NULL,
    userid		numeric(12) NOT NULL,
    deny		bit(5) NOT NULL,
    allow		bit(5) NOT NULL,
    mask		bit(5) DEFAULT B'00000' NOT NULL,
    CONSTRAINT fk_acu_class FOREIGN KEY (class) REFERENCES db.class_tree(id),
    CONSTRAINT fk_acu_userid FOREIGN KEY (userid) REFERENCES db.user(id)
);

COMMENT ON TABLE db.acu IS 'Доступ пользователя к классам.';

COMMENT ON COLUMN db.acu.class IS 'Класс';
COMMENT ON COLUMN db.acu.userid IS 'Пользователь';
COMMENT ON COLUMN db.acu.deny IS 'Запрещающие биты: {acsud}. Где: {a - access; c - create; s - select; u - update; d - delete}';
COMMENT ON COLUMN db.acu.allow IS 'Разрешающие биты: {acsud}. Где: {a - access; c - create; s - select; u - update; d - delete}';
COMMENT ON COLUMN db.acu.mask IS 'Маска доступа: {acsud}. Где: {a - access; c - create; s - select; u - update; d - delete}';

CREATE INDEX ON db.acu (class);
CREATE INDEX ON db.acu (userid);

CREATE UNIQUE INDEX ON db.acu (class, userid);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_acu_before()
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

CREATE TRIGGER t_acu_before
  BEFORE INSERT OR UPDATE ON db.acu
  FOR EACH ROW
  EXECUTE PROCEDURE ft_acu_before();

--------------------------------------------------------------------------------
-- TYPE ------------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.type (
    id			numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    class		numeric(12) NOT NULL,
    code        text NOT NULL,
    name 		text NOT NULL,
    description text,
    CONSTRAINT fk_type_class FOREIGN KEY (class) REFERENCES db.class_tree(id)
);

COMMENT ON TABLE db.type IS 'Тип.';

COMMENT ON COLUMN db.type.id IS 'Идентификатор';
COMMENT ON COLUMN db.type.class IS 'Класс';
COMMENT ON COLUMN db.type.code IS 'Код';
COMMENT ON COLUMN db.type.name IS 'Наименование';
COMMENT ON COLUMN db.type.description IS 'Описание';

CREATE INDEX ON db.type (class);

CREATE UNIQUE INDEX ON db.type (class, code);

--------------------------------------------------------------------------------
-- STATE -----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.state_type (
    id			numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    code		text NOT NULL,
    name		text NOT NULL
);

COMMENT ON TABLE db.state_type IS 'Тип состояния объекта.';

COMMENT ON COLUMN db.state_type.id IS 'Идентификатор';
COMMENT ON COLUMN db.state_type.code IS 'Код типа состояния объекта';
COMMENT ON COLUMN db.state_type.name IS 'Наименование типа состояния объекта';

CREATE UNIQUE INDEX ON db.state_type (code);

--------------------------------------------------------------------------------

INSERT INTO db.state_type (code, name) VALUES ('created', 'Создан');
INSERT INTO db.state_type (code, name) VALUES ('enabled', 'Включен');
INSERT INTO db.state_type (code, name) VALUES ('disabled', 'Отключен');
INSERT INTO db.state_type (code, name) VALUES ('deleted', 'Удалён');

--------------------------------------------------------------------------------
-- db.state --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.state (
    id			numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    class		numeric(12) NOT NULL,
    type		numeric(12) NOT NULL,
    code		text NOT NULL,
    label		text NOT NULL,
    sequence	integer NOT NULL,
    CONSTRAINT fk_state_class FOREIGN KEY (class) REFERENCES db.class_tree(id),
    CONSTRAINT fk_state_type FOREIGN KEY (type) REFERENCES db.state_type(id)
);

COMMENT ON TABLE db.state IS 'Список состояний объекта.';

COMMENT ON COLUMN db.state.id IS 'Идентификатор';
COMMENT ON COLUMN db.state.class IS 'Класс объекта';
COMMENT ON COLUMN db.state.type IS 'Тип состояния';
COMMENT ON COLUMN db.state.code IS 'Код состояния';
COMMENT ON COLUMN db.state.label IS 'Состояние';
COMMENT ON COLUMN db.state.sequence IS 'Очерёдность';

CREATE INDEX ON db.state (class);
CREATE INDEX ON db.state (type);
CREATE INDEX ON db.state (code);

CREATE UNIQUE INDEX ON db.state (class, code);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_state_insert()
RETURNS trigger AS $$
BEGIN
  IF NULLIF(NEW.code, '') IS NULL THEN
    NEW.code := encode(gen_random_bytes(12), 'hex');
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_state_insert
  BEFORE INSERT ON db.state
  FOR EACH ROW
  EXECUTE PROCEDURE ft_state_insert();

--------------------------------------------------------------------------------
-- ACTION ----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.action (
    id			numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    code		text NOT NULL,
    name		text NOT NULL,
    description	text
);

COMMENT ON TABLE db.action IS 'Список действий.';

COMMENT ON COLUMN db.action.id IS 'Идентификатор';
COMMENT ON COLUMN db.action.code IS 'Код действия';
COMMENT ON COLUMN db.action.name IS 'Наименование действия';
COMMENT ON COLUMN db.action.description IS 'Описание';

CREATE UNIQUE INDEX ON db.action (code);

--------------------------------------------------------------------------------
-- METHOD ----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.method (
    id			numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    parent		numeric(12),
    class		numeric(12) NOT NULL,
    state		numeric(12),
    action		numeric(12) NOT NULL,
    code		text NOT NULL,
    label		text NOT NULL,
    sequence    integer NOT NULL,
    visible		boolean DEFAULT TRUE,
    CONSTRAINT fk_method_class FOREIGN KEY (class) REFERENCES db.class_tree(id),
    CONSTRAINT fk_method_state FOREIGN KEY (state) REFERENCES db.state(id),
    CONSTRAINT fk_method_action FOREIGN KEY (action) REFERENCES db.action(id)
);

COMMENT ON TABLE db.method IS 'Методы класса.';

COMMENT ON COLUMN db.method.id IS 'Идентификатор';
COMMENT ON COLUMN db.method.parent IS 'Ссылка на родительский узел';
COMMENT ON COLUMN db.method.class IS 'Класс';
COMMENT ON COLUMN db.method.state IS 'Состояние';
COMMENT ON COLUMN db.method.action IS 'Действие';
COMMENT ON COLUMN db.method.code IS 'Код метода класса';
COMMENT ON COLUMN db.method.label IS 'Метка';
COMMENT ON COLUMN db.method.sequence IS 'Очерёдность';
COMMENT ON COLUMN db.method.visible IS 'Видимое: Да/Нет';

--------------------------------------------------------------------------------

CREATE INDEX ON db.method (parent);
CREATE INDEX ON db.method (class);
CREATE INDEX ON db.method (state);
CREATE INDEX ON db.method (action);
CREATE INDEX ON db.method (visible);

CREATE UNIQUE INDEX ON db.method (class, state, action);
CREATE UNIQUE INDEX ON db.method (class, code);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_method_before_insert()
RETURNS trigger AS $$
BEGIN
  NEW.state = NULLIF(NEW.state, 0);

  IF NEW.code IS NULL THEN
    NEW.code := coalesce(GetStateCode(NEW.state), 'null') || ':' || GetActionCode(NEW.action);
  END IF;

  IF NEW.label IS NULL THEN
    NEW.label := GetActionName(NEW.action);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_method_before_insert
  BEFORE INSERT ON db.method
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_method_before_insert();

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_method_after_insert()
RETURNS trigger AS $$
DECLARE
  bAllow	bit(3);
BEGIN
  IF NEW.visible THEN
	bAllow := B'111';
  ELSE
	bAllow := B'101';
  END IF;

  INSERT INTO db.amu SELECT NEW.id, userid, B'000', bAllow FROM db.acu WHERE class = NEW.class;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_method_after_insert
  AFTER INSERT ON db.method
  FOR EACH ROW
  EXECUTE PROCEDURE ft_method_after_insert();

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_method_before_delete()
RETURNS trigger AS $$
BEGIN
  DELETE FROM db.transition WHERE method = OLD.ID;
  DELETE FROM db.amu WHERE method = OLD.ID;

  RETURN OLD;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_method_before_delete
  BEFORE DELETE ON db.method
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_method_before_delete();

--------------------------------------------------------------------------------
-- TABLE db.amu ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.amu (
    method		numeric(12) NOT NULL,
    userid		numeric(12) NOT NULL,
    deny		bit(3) NOT NULL,
    allow		bit(3) NOT NULL,
    mask		bit(3) DEFAULT B'000' NOT NULL,
    CONSTRAINT fk_amu_method FOREIGN KEY (method) REFERENCES db.method(id),
    CONSTRAINT fk_amu_userid FOREIGN KEY (userid) REFERENCES db.user(id)
);

COMMENT ON TABLE db.amu IS 'Доступ пользователя к методам класса.';

COMMENT ON COLUMN db.amu.method IS 'Метод';
COMMENT ON COLUMN db.amu.userid IS 'Пользователь';
COMMENT ON COLUMN db.amu.mask IS 'Маска доступа. Шесть бит (d:{xve}a:{xve}) где: d - запрещающие биты; a - разрешающие биты: {x - execute, v - visible, e - enable}';

CREATE INDEX ON db.amu (method);
CREATE INDEX ON db.amu (userid);

CREATE UNIQUE INDEX ON db.amu (method, userid);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_amu_before()
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

CREATE TRIGGER t_amu_before
  BEFORE INSERT OR UPDATE ON db.amu
  FOR EACH ROW
  EXECUTE PROCEDURE ft_amu_before();

--------------------------------------------------------------------------------
-- db.transition ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.transition (
    id			numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    state		numeric(12),
    method		numeric(12) NOT NULL,
    newstate    numeric(12) NOT NULL,
    CONSTRAINT fk_transition_state FOREIGN KEY (state) REFERENCES db.state(id),
    CONSTRAINT fk_transition_method FOREIGN KEY (method) REFERENCES db.method(id),
    CONSTRAINT fk_transition_newstate FOREIGN KEY (newstate) REFERENCES db.state(id)
);

COMMENT ON TABLE db.transition IS 'Переходы из одного состояния в другое.';

COMMENT ON COLUMN db.transition.id IS 'Идентификатор';
COMMENT ON COLUMN db.transition.state IS 'Состояние (текущее)';
COMMENT ON COLUMN db.transition.method IS 'Совершаемая операция (действие)';
COMMENT ON COLUMN db.transition.newstate IS 'Состояние (новое)';

CREATE INDEX ON db.transition (state);
CREATE UNIQUE INDEX ON db.transition (method);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_transition_before_insert()
RETURNS trigger AS $$
BEGIN
  NEW.STATE = NULLIF(NEW.STATE, 0);

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_transition_before_insert
  BEFORE INSERT ON db.transition
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_transition_before_insert();

--------------------------------------------------------------------------------
-- EVENT -----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.event_type (
    id			numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    code		text NOT NULL,
    name		text NOT NULL
);

COMMENT ON TABLE db.event_type IS 'Тип события.';

COMMENT ON COLUMN db.event_type.id IS 'Идентификатор';
COMMENT ON COLUMN db.event_type.code IS 'Код типа события';
COMMENT ON COLUMN db.event_type.name IS 'Наименование типа события';

CREATE UNIQUE INDEX ON db.event_type (code);

--------------------------------------------------------------------------------

INSERT INTO db.event_type (code, name) VALUES ('parent', 'События класса родителя');
INSERT INTO db.event_type (code, name) VALUES ('event', 'Событие');
INSERT INTO db.event_type (code, name) VALUES ('plpgsql', 'PL/pgSQL код');

--------------------------------------------------------------------------------
-- db.event --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.event (
    id			numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    class		numeric(12) NOT NULL,
    type		numeric(12) NOT NULL,
    action		numeric(12) NOT NULL,
    label		text NOT NULL,
    text		text,
    sequence	integer NOT NULL,
    enabled		boolean DEFAULT TRUE NOT NULL,
    CONSTRAINT fk_event_class FOREIGN KEY (class) REFERENCES db.class_tree(id),
    CONSTRAINT fk_event_type FOREIGN KEY (type) REFERENCES db.event_type(id),
    CONSTRAINT fk_event_action FOREIGN KEY (action) REFERENCES db.action(id)
);

COMMENT ON TABLE db.event IS 'События.';

COMMENT ON COLUMN db.event.id IS 'Идентификатор';
COMMENT ON COLUMN db.event.class IS 'Класс объекта';
COMMENT ON COLUMN db.event.type IS 'Тип события';
COMMENT ON COLUMN db.event.action IS 'Действие';
COMMENT ON COLUMN db.event.label IS 'Событие';
COMMENT ON COLUMN db.event.text IS 'Текст';
COMMENT ON COLUMN db.event.sequence IS 'Очерёдность';
COMMENT ON COLUMN db.event.enabled IS 'Включено: Да/Нет';

CREATE INDEX ON db.event (class);
CREATE INDEX ON db.event (type);
CREATE INDEX ON db.event (action);
CREATE INDEX ON db.event (enabled);
