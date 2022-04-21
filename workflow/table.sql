--------------------------------------------------------------------------------
-- ENTITY ----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.entity (
    id			uuid PRIMARY KEY DEFAULT gen_kernel_uuid('b'),
    code		text NOT NULL
);

COMMENT ON TABLE db.entity IS 'Сущность.';
COMMENT ON COLUMN db.entity.id IS 'Идентификатор';
COMMENT ON COLUMN db.entity.code IS 'Код';

CREATE UNIQUE INDEX ON db.entity (code);

--------------------------------------------------------------------------------
-- db.entity_text --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.entity_text (
    entity      uuid NOT NULL REFERENCES db.entity(id) ON DELETE CASCADE,
    locale      uuid NOT NULL REFERENCES db.locale(id) ON DELETE RESTRICT,
    name        text NOT NULL,
    description text,
    PRIMARY KEY (entity, locale)
);

--------------------------------------------------------------------------------

COMMENT ON TABLE db.entity_text IS 'Текст сущности.';

COMMENT ON COLUMN db.entity_text.entity IS 'Идентификатор сущности';
COMMENT ON COLUMN db.entity_text.locale IS 'Идентификатор локали';
COMMENT ON COLUMN db.entity_text.name IS 'Наименование';
COMMENT ON COLUMN db.entity_text.description IS 'Описание';

--------------------------------------------------------------------------------

CREATE INDEX ON db.entity_text (entity);
CREATE INDEX ON db.entity_text (locale);

--------------------------------------------------------------------------------
-- CLASS -----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.class_tree (
    id			uuid PRIMARY KEY DEFAULT gen_kernel_uuid('b'),
    parent		uuid REFERENCES db.class_tree(id),
    entity		uuid NOT NULL REFERENCES db.entity(id),
    level		integer NOT NULL,
    code		text NOT NULL,
    abstract    boolean DEFAULT TRUE NOT NULL
);

COMMENT ON TABLE db.class_tree IS 'Дерево классов.';

COMMENT ON COLUMN db.class_tree.id IS 'Идентификатор';
COMMENT ON COLUMN db.class_tree.parent IS 'Ссылка на родительский узел';
COMMENT ON COLUMN db.class_tree.entity IS 'Сущность';
COMMENT ON COLUMN db.class_tree.level IS 'Уровень вложенности';
COMMENT ON COLUMN db.class_tree.code IS 'Код';
COMMENT ON COLUMN db.class_tree.abstract IS 'Абстрактный: Да/Нет';

--------------------------------------------------------------------------------

CREATE INDEX ON db.class_tree (parent);
CREATE INDEX ON db.class_tree (entity);

CREATE UNIQUE INDEX ON db.class_tree (code);

--------------------------------------------------------------------------------
-- db.class_text ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.class_text (
    class       uuid NOT NULL REFERENCES db.class_tree(id) ON DELETE CASCADE,
    locale      uuid NOT NULL REFERENCES db.locale(id) ON DELETE RESTRICT,
    label       text NOT NULL,
    PRIMARY KEY (class, locale)
);

--------------------------------------------------------------------------------

COMMENT ON TABLE db.class_text IS 'Текст класса.';

COMMENT ON COLUMN db.class_text.class IS 'Идентификатор класса';
COMMENT ON COLUMN db.class_text.locale IS 'Идентификатор локали';
COMMENT ON COLUMN db.class_text.label IS 'Метка';

--------------------------------------------------------------------------------

CREATE INDEX ON db.class_text (class);
CREATE INDEX ON db.class_text (locale);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_class_tree_after_insert()
RETURNS trigger AS $$
BEGIN
  IF NEW.parent IS NULL THEN
    INSERT INTO db.acu SELECT NEW.id, '00000000-0000-4000-a000-000000000001'::uuid, B'00000', B'11111'; -- administrator group
    INSERT INTO db.acu SELECT NEW.id, '00000000-0000-4000-a002-000000000001'::uuid, B'00000', B'01110'; -- apibot
  ELSE
    INSERT INTO db.acu SELECT NEW.id, userid, deny, allow FROM db.acu WHERE class = NEW.parent;

    IF NEW.code = 'document' THEN
      INSERT INTO db.acu SELECT NEW.id, '00000000-0000-4000-a000-000000000002'::uuid, B'00000', B'11000'; -- user group
    ELSIF NEW.code = 'reference' THEN
      INSERT INTO db.acu SELECT NEW.id, '00000000-0000-4000-a000-000000000002'::uuid, B'00000', B'10100'; -- user group
    ELSIF NEW.code = 'message' THEN
      INSERT INTO db.acu SELECT NEW.id, '00000000-0000-4000-a002-000000000002'::uuid, B'00000', B'01110'; -- mailbot
    ELSIF NEW.code = 'agent' THEN
      INSERT INTO db.acu SELECT NEW.id, '00000000-0000-4000-a002-000000000002'::uuid, B'00000', B'01100'; -- mailbot
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
    class		uuid NOT NULL REFERENCES db.class_tree(id) ON DELETE CASCADE,
    userid		uuid NOT NULL REFERENCES db.user(id) ON DELETE CASCADE,
    deny		bit(5) NOT NULL,
    allow		bit(5) NOT NULL,
    mask		bit(5) DEFAULT B'00000' NOT NULL,
    PRIMARY KEY (class, userid)
);

COMMENT ON TABLE db.acu IS 'Доступ пользователя к классам.';

COMMENT ON COLUMN db.acu.class IS 'Класс';
COMMENT ON COLUMN db.acu.userid IS 'Пользователь';
COMMENT ON COLUMN db.acu.deny IS 'Запрещающие биты: {acsud}. Где: {a - access; c - create; s - select; u - update; d - delete}';
COMMENT ON COLUMN db.acu.allow IS 'Разрешающие биты: {acsud}. Где: {a - access; c - create; s - select; u - update; d - delete}';
COMMENT ON COLUMN db.acu.mask IS 'Маска доступа: {acsud}. Где: {a - access; c - create; s - select; u - update; d - delete}';

CREATE INDEX ON db.acu (class);
CREATE INDEX ON db.acu (userid);

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

--------------------------------------------------------------------------------

CREATE TRIGGER t_acu_before
  BEFORE INSERT OR UPDATE ON db.acu
  FOR EACH ROW
  EXECUTE PROCEDURE ft_acu_before();

--------------------------------------------------------------------------------
-- TYPE ------------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.type (
    id			uuid PRIMARY KEY DEFAULT gen_kernel_uuid('b'),
    class		uuid NOT NULL REFERENCES db.class_tree(id),
    code        text NOT NULL
);

COMMENT ON TABLE db.type IS 'Тип объекта.';

COMMENT ON COLUMN db.type.id IS 'Идентификатор';
COMMENT ON COLUMN db.type.class IS 'Класс';
COMMENT ON COLUMN db.type.code IS 'Код';

CREATE INDEX ON db.type (class);

CREATE UNIQUE INDEX ON db.type (class, code);

--------------------------------------------------------------------------------
-- db.type_text ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.type_text (
    type        uuid NOT NULL REFERENCES db.type(id) ON DELETE CASCADE,
    locale      uuid NOT NULL REFERENCES db.locale(id) ON DELETE RESTRICT,
    name        text NOT NULL,
    description text,
    PRIMARY KEY (type, locale)
);

--------------------------------------------------------------------------------

COMMENT ON TABLE db.type_text IS 'Текст типа объекта.';

COMMENT ON COLUMN db.type_text.type IS 'Идентификатор типа';
COMMENT ON COLUMN db.type_text.locale IS 'Идентификатор локали';
COMMENT ON COLUMN db.type_text.name IS 'Наименование';
COMMENT ON COLUMN db.type_text.description IS 'Описание';

--------------------------------------------------------------------------------

CREATE INDEX ON db.type_text (type);
CREATE INDEX ON db.type_text (locale);

--------------------------------------------------------------------------------
-- STATE -----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.state_type (
    id			uuid PRIMARY KEY,
    code		text NOT NULL
);

COMMENT ON TABLE db.state_type IS 'Тип состояния объекта.';

COMMENT ON COLUMN db.state_type.id IS 'Идентификатор';
COMMENT ON COLUMN db.state_type.code IS 'Код типа состояния объекта';

CREATE UNIQUE INDEX ON db.state_type (code);

--------------------------------------------------------------------------------
-- db.state_type_text ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.state_type_text (
    type        uuid NOT NULL REFERENCES db.state_type(id) ON DELETE CASCADE,
    locale      uuid NOT NULL REFERENCES db.locale(id) ON DELETE RESTRICT,
    name        text NOT NULL,
    description text,
    PRIMARY KEY (type, locale)
);

--------------------------------------------------------------------------------

COMMENT ON TABLE db.state_type_text IS 'Текст типа состояния объекта.';

COMMENT ON COLUMN db.state_type_text.type IS 'Идентификатор типа состояния объекта';
COMMENT ON COLUMN db.state_type_text.locale IS 'Идентификатор локали';
COMMENT ON COLUMN db.state_type_text.name IS 'Наименование';
COMMENT ON COLUMN db.state_type_text.description IS 'Описание';

--------------------------------------------------------------------------------

CREATE INDEX ON db.state_type_text (type);
CREATE INDEX ON db.state_type_text (locale);

--------------------------------------------------------------------------------
-- db.state --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.state (
    id			uuid PRIMARY KEY DEFAULT gen_kernel_uuid('b'),
    class		uuid NOT NULL REFERENCES db.class_tree(id),
    type		uuid NOT NULL REFERENCES db.state_type(id),
    code		text NOT NULL,
    sequence	integer NOT NULL
);

COMMENT ON TABLE db.state IS 'Состояние объекта.';

COMMENT ON COLUMN db.state.id IS 'Идентификатор';
COMMENT ON COLUMN db.state.class IS 'Класс объекта';
COMMENT ON COLUMN db.state.type IS 'Тип состояния';
COMMENT ON COLUMN db.state.code IS 'Код состояния';
COMMENT ON COLUMN db.state.sequence IS 'Очерёдность';

CREATE INDEX ON db.state (class);
CREATE INDEX ON db.state (type);
CREATE INDEX ON db.state (code);

CREATE UNIQUE INDEX ON db.state (class, code);

--------------------------------------------------------------------------------
-- db.state_text ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.state_text (
    state       uuid NOT NULL REFERENCES db.state(id) ON DELETE CASCADE,
    locale      uuid NOT NULL REFERENCES db.locale(id) ON DELETE RESTRICT,
    label       text NOT NULL,
    PRIMARY KEY (state, locale)
);

--------------------------------------------------------------------------------

COMMENT ON TABLE db.state_text IS 'Текст состояние объекта.';

COMMENT ON COLUMN db.state_text.state IS 'Идентификатор сущности';
COMMENT ON COLUMN db.state_text.locale IS 'Идентификатор локали';
COMMENT ON COLUMN db.state_text.label IS 'Метка';

--------------------------------------------------------------------------------

CREATE INDEX ON db.state_text (state);
CREATE INDEX ON db.state_text (locale);

--------------------------------------------------------------------------------
-- ACTION ----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.action (
    id			uuid PRIMARY KEY DEFAULT gen_kernel_uuid('b'),
    code		text NOT NULL
);

COMMENT ON TABLE db.action IS 'Действие.';

COMMENT ON COLUMN db.action.id IS 'Идентификатор';
COMMENT ON COLUMN db.action.code IS 'Код действия';

CREATE UNIQUE INDEX ON db.action (code);

--------------------------------------------------------------------------------
-- db.action_text --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.action_text (
    action      uuid NOT NULL REFERENCES db.action(id) ON DELETE CASCADE,
    locale      uuid NOT NULL REFERENCES db.locale(id) ON DELETE RESTRICT,
    name        text NOT NULL,
    description text,
    PRIMARY KEY (action, locale)
);

--------------------------------------------------------------------------------

COMMENT ON TABLE db.action_text IS 'Текст действия.';

COMMENT ON COLUMN db.action_text.action IS 'Идентификатор действия';
COMMENT ON COLUMN db.action_text.locale IS 'Идентификатор локали';
COMMENT ON COLUMN db.action_text.name IS 'Наименование';
COMMENT ON COLUMN db.action_text.description IS 'Описание';

--------------------------------------------------------------------------------

CREATE INDEX ON db.action_text (action);
CREATE INDEX ON db.action_text (locale);

--------------------------------------------------------------------------------
-- METHOD ----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.method (
    id			uuid PRIMARY KEY DEFAULT gen_kernel_uuid('b'),
    parent		uuid REFERENCES db.method(id),
    class		uuid NOT NULL REFERENCES db.class_tree(id),
    state		uuid REFERENCES db.state(id),
    action		uuid NOT NULL REFERENCES db.action(id),
    code		text NOT NULL,
    sequence    integer NOT NULL,
    visible		boolean DEFAULT true
);

COMMENT ON TABLE db.method IS 'Методы класса.';

COMMENT ON COLUMN db.method.id IS 'Идентификатор';
COMMENT ON COLUMN db.method.parent IS 'Ссылка на родительский узел';
COMMENT ON COLUMN db.method.class IS 'Класс';
COMMENT ON COLUMN db.method.state IS 'Состояние';
COMMENT ON COLUMN db.method.action IS 'Действие';
COMMENT ON COLUMN db.method.code IS 'Код метода класса';
COMMENT ON COLUMN db.method.sequence IS 'Очерёдность';
COMMENT ON COLUMN db.method.visible IS 'Видимое: Да/Нет';

--------------------------------------------------------------------------------

CREATE INDEX ON db.method (parent);
CREATE INDEX ON db.method (class);
CREATE INDEX ON db.method (state);
CREATE INDEX ON db.method (action);

--CREATE UNIQUE INDEX ON db.method (class, state, action);
CREATE UNIQUE INDEX ON db.method (class, code);

--------------------------------------------------------------------------------
-- db.method_text --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.method_text (
    method      uuid NOT NULL REFERENCES db.method(id) ON DELETE CASCADE,
    locale      uuid NOT NULL REFERENCES db.locale(id) ON DELETE RESTRICT,
    label       text NOT NULL,
    PRIMARY KEY (method, locale)
);

--------------------------------------------------------------------------------

COMMENT ON TABLE db.method_text IS 'Текст состояние объекта.';

COMMENT ON COLUMN db.method_text.method IS 'Идентификатор сущности';
COMMENT ON COLUMN db.method_text.locale IS 'Идентификатор локали';
COMMENT ON COLUMN db.method_text.label IS 'Метка';

--------------------------------------------------------------------------------

CREATE INDEX ON db.method_text (method);
CREATE INDEX ON db.method_text (locale);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_method_before_insert()
RETURNS trigger AS $$
BEGIN
  IF NEW.code IS NULL THEN
    NEW.code := coalesce(GetStateCode(NEW.state), 'null') || ':' || GetActionCode(NEW.action);
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
    method		uuid NOT NULL REFERENCES db.method(id) ON DELETE CASCADE,
    userid		uuid NOT NULL REFERENCES db.user(id) ON DELETE CASCADE,
    deny		bit(3) NOT NULL,
    allow		bit(3) NOT NULL,
    mask		bit(3) DEFAULT B'000' NOT NULL,
    PRIMARY KEY (method, userid)
);

COMMENT ON TABLE db.amu IS 'Доступ пользователя к методам класса.';

COMMENT ON COLUMN db.amu.method IS 'Метод';
COMMENT ON COLUMN db.amu.userid IS 'Пользователь';
COMMENT ON COLUMN db.amu.mask IS 'Маска доступа. Шесть бит (d:{xve}a:{xve}) где: d - запрещающие биты; a - разрешающие биты: {x - execute, v - visible, e - enable}';

CREATE INDEX ON db.amu (method);
CREATE INDEX ON db.amu (userid);

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
    id			uuid PRIMARY KEY DEFAULT gen_kernel_uuid('b'),
    state		uuid REFERENCES db.state(id),
    method		uuid NOT NULL UNIQUE REFERENCES db.method(id),
    newstate    uuid NOT NULL REFERENCES db.state(id)
);

COMMENT ON TABLE db.transition IS 'Переходы из одного состояния в другое.';

COMMENT ON COLUMN db.transition.id IS 'Идентификатор';
COMMENT ON COLUMN db.transition.state IS 'Состояние (текущее)';
COMMENT ON COLUMN db.transition.method IS 'Совершаемая операция (действие)';
COMMENT ON COLUMN db.transition.newstate IS 'Состояние (новое)';

CREATE INDEX ON db.transition (state);
CREATE INDEX ON db.transition (method);

--------------------------------------------------------------------------------
-- EVENT -----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.event_type (
    id			uuid PRIMARY KEY,
    code		text NOT NULL
);

COMMENT ON TABLE db.event_type IS 'Тип события.';

COMMENT ON COLUMN db.event_type.id IS 'Идентификатор';
COMMENT ON COLUMN db.event_type.code IS 'Код типа события';

CREATE UNIQUE INDEX ON db.event_type (code);

--------------------------------------------------------------------------------
-- db.event_type_text ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.event_type_text (
    type        uuid NOT NULL REFERENCES db.event_type(id) ON DELETE CASCADE,
    locale      uuid NOT NULL REFERENCES db.locale(id) ON DELETE RESTRICT,
    name        text NOT NULL,
    description text,
    PRIMARY KEY (type, locale)
);

--------------------------------------------------------------------------------

COMMENT ON TABLE db.event_type_text IS 'Текст типа события.';

COMMENT ON COLUMN db.event_type_text.type IS 'Идентификатор типа события';
COMMENT ON COLUMN db.event_type_text.locale IS 'Идентификатор локали';
COMMENT ON COLUMN db.event_type_text.name IS 'Наименование';
COMMENT ON COLUMN db.event_type_text.description IS 'Описание';

--------------------------------------------------------------------------------

CREATE INDEX ON db.event_type_text (type);
CREATE INDEX ON db.event_type_text (locale);

--------------------------------------------------------------------------------
-- db.event --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.event (
    id			uuid PRIMARY KEY DEFAULT gen_kernel_uuid('b'),
    class		uuid NOT NULL REFERENCES db.class_tree(id),
    type		uuid NOT NULL REFERENCES db.event_type(id),
    action		uuid NOT NULL REFERENCES db.action(id),
    text		text,
    sequence	integer NOT NULL,
    enabled		boolean DEFAULT TRUE NOT NULL
);

COMMENT ON TABLE db.event IS 'Событие.';

COMMENT ON COLUMN db.event.id IS 'Идентификатор';
COMMENT ON COLUMN db.event.class IS 'Класс объекта';
COMMENT ON COLUMN db.event.type IS 'Тип события';
COMMENT ON COLUMN db.event.action IS 'Действие';
COMMENT ON COLUMN db.event.text IS 'Текст';
COMMENT ON COLUMN db.event.sequence IS 'Очерёдность';
COMMENT ON COLUMN db.event.enabled IS 'Включено: Да/Нет';

CREATE INDEX ON db.event (class);
CREATE INDEX ON db.event (type);
CREATE INDEX ON db.event (action);

--------------------------------------------------------------------------------
-- db.event_text ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.event_text (
    event       uuid NOT NULL REFERENCES db.event(id) ON DELETE CASCADE,
    locale      uuid NOT NULL REFERENCES db.locale(id) ON DELETE RESTRICT,
    label       text NOT NULL,
    PRIMARY KEY (event, locale)
);

--------------------------------------------------------------------------------

COMMENT ON TABLE db.event_text IS 'Текст события.';

COMMENT ON COLUMN db.event_text.event IS 'Идентификатор сущности';
COMMENT ON COLUMN db.event_text.locale IS 'Идентификатор локали';
COMMENT ON COLUMN db.event_text.label IS 'Метка';

--------------------------------------------------------------------------------

CREATE INDEX ON db.event_text (event);
CREATE INDEX ON db.event_text (locale);
