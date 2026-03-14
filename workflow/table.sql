--------------------------------------------------------------------------------
-- ENTITY ----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.entity (
    id          uuid PRIMARY KEY DEFAULT gen_kernel_uuid('b'),
    code        text NOT NULL
);

COMMENT ON TABLE db.entity IS 'Workflow entity. Top-level domain concept (object, document, reference, etc.).';
COMMENT ON COLUMN db.entity.id IS 'Entity identifier (UUID).';
COMMENT ON COLUMN db.entity.code IS 'Unique entity code (e.g. "object", "document", "reference").';

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

COMMENT ON TABLE db.entity_text IS 'Locale-specific name and description for an entity.';

COMMENT ON COLUMN db.entity_text.entity IS 'Reference to db.entity.';
COMMENT ON COLUMN db.entity_text.locale IS 'Locale for this translation.';
COMMENT ON COLUMN db.entity_text.name IS 'Localised display name.';
COMMENT ON COLUMN db.entity_text.description IS 'Localised description (optional).';

--------------------------------------------------------------------------------

CREATE INDEX ON db.entity_text (entity);
CREATE INDEX ON db.entity_text (locale);

--------------------------------------------------------------------------------
-- CLASS -----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.class_tree (
    id          uuid PRIMARY KEY DEFAULT gen_kernel_uuid('b'),
    parent      uuid REFERENCES db.class_tree(id),
    entity      uuid NOT NULL REFERENCES db.entity(id),
    level       integer NOT NULL,
    code        text NOT NULL,
    abstract    boolean DEFAULT TRUE NOT NULL
);

COMMENT ON TABLE db.class_tree IS 'Hierarchical class tree. Each class belongs to an entity and may inherit from a parent class.';

COMMENT ON COLUMN db.class_tree.id IS 'Class identifier (UUID).';
COMMENT ON COLUMN db.class_tree.parent IS 'Parent class (NULL for root classes).';
COMMENT ON COLUMN db.class_tree.entity IS 'Entity this class belongs to.';
COMMENT ON COLUMN db.class_tree.level IS 'Nesting depth (0 = root).';
COMMENT ON COLUMN db.class_tree.code IS 'Unique class code.';
COMMENT ON COLUMN db.class_tree.abstract IS 'Abstract flag: true = cannot be instantiated directly.';

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

COMMENT ON TABLE db.class_text IS 'Locale-specific label for a class.';

COMMENT ON COLUMN db.class_text.class IS 'Reference to db.class_tree.';
COMMENT ON COLUMN db.class_text.locale IS 'Locale for this translation.';
COMMENT ON COLUMN db.class_text.label IS 'Localised display label.';

--------------------------------------------------------------------------------

CREATE INDEX ON db.class_text (class);
CREATE INDEX ON db.class_text (locale);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_class_tree_after_insert()
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
  EXECUTE PROCEDURE db.ft_class_tree_after_insert();

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_class_tree_before_delete()
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
  EXECUTE PROCEDURE db.ft_class_tree_before_delete();

--------------------------------------------------------------------------------
-- TABLE db.acu ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.acu (
    class       uuid NOT NULL REFERENCES db.class_tree(id) ON DELETE CASCADE,
    userid      uuid NOT NULL REFERENCES db.user(id) ON DELETE CASCADE,
    deny        bit(5) NOT NULL,
    allow       bit(5) NOT NULL,
    mask        bit(5) DEFAULT B'00000' NOT NULL,
    PRIMARY KEY (class, userid)
);

COMMENT ON TABLE db.acu IS 'Access Control Unit. Per-class permission bitmask for each user/group.';

COMMENT ON COLUMN db.acu.class IS 'Class this ACL entry applies to.';
COMMENT ON COLUMN db.acu.userid IS 'User or group granted/denied access.';
COMMENT ON COLUMN db.acu.deny IS 'Deny bits: {acsud} where a=access, c=create, s=select, u=update, d=delete.';
COMMENT ON COLUMN db.acu.allow IS 'Allow bits: {acsud} where a=access, c=create, s=select, u=update, d=delete.';
COMMENT ON COLUMN db.acu.mask IS 'Effective mask: allow & ~deny. Computed by trigger.';

CREATE INDEX ON db.acu (class);
CREATE INDEX ON db.acu (userid);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_acu_before()
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
  EXECUTE PROCEDURE db.ft_acu_before();

--------------------------------------------------------------------------------
-- TYPE ------------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.type (
    id          uuid PRIMARY KEY DEFAULT gen_kernel_uuid('b'),
    class       uuid NOT NULL REFERENCES db.class_tree(id),
    code        text NOT NULL
);

COMMENT ON TABLE db.type IS 'Object type. Concrete specialisation within a class (e.g. "client.reference").';

COMMENT ON COLUMN db.type.id IS 'Type identifier (UUID).';
COMMENT ON COLUMN db.type.class IS 'Class this type belongs to.';
COMMENT ON COLUMN db.type.code IS 'Unique type code within the class.';

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

COMMENT ON TABLE db.type_text IS 'Locale-specific name and description for an object type.';

COMMENT ON COLUMN db.type_text.type IS 'Reference to db.type.';
COMMENT ON COLUMN db.type_text.locale IS 'Locale for this translation.';
COMMENT ON COLUMN db.type_text.name IS 'Localised display name.';
COMMENT ON COLUMN db.type_text.description IS 'Localised description (optional).';

--------------------------------------------------------------------------------

CREATE INDEX ON db.type_text (type);
CREATE INDEX ON db.type_text (locale);

--------------------------------------------------------------------------------
-- STATE -----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.state_type (
    id          uuid PRIMARY KEY,
    code        text NOT NULL
);

COMMENT ON TABLE db.state_type IS 'State type classifier (e.g. created, enabled, disabled, deleted).';

COMMENT ON COLUMN db.state_type.id IS 'State type identifier (UUID).';
COMMENT ON COLUMN db.state_type.code IS 'Unique state type code.';

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

COMMENT ON TABLE db.state_type_text IS 'Locale-specific name and description for a state type.';

COMMENT ON COLUMN db.state_type_text.type IS 'Reference to db.state_type.';
COMMENT ON COLUMN db.state_type_text.locale IS 'Locale for this translation.';
COMMENT ON COLUMN db.state_type_text.name IS 'Localised display name.';
COMMENT ON COLUMN db.state_type_text.description IS 'Localised description (optional).';

--------------------------------------------------------------------------------

CREATE INDEX ON db.state_type_text (type);
CREATE INDEX ON db.state_type_text (locale);

--------------------------------------------------------------------------------
-- db.state --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.state (
    id          uuid PRIMARY KEY DEFAULT gen_kernel_uuid('b'),
    class       uuid NOT NULL REFERENCES db.class_tree(id),
    type        uuid NOT NULL REFERENCES db.state_type(id),
    code        text NOT NULL,
    sequence    integer NOT NULL
);

COMMENT ON TABLE db.state IS 'Object state. Each class defines an ordered set of states an object can be in.';

COMMENT ON COLUMN db.state.id IS 'State identifier (UUID).';
COMMENT ON COLUMN db.state.class IS 'Class this state is defined for.';
COMMENT ON COLUMN db.state.type IS 'State type (created, enabled, etc.).';
COMMENT ON COLUMN db.state.code IS 'Unique state code within the class.';
COMMENT ON COLUMN db.state.sequence IS 'Display/processing order.';

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

COMMENT ON TABLE db.state_text IS 'Locale-specific label for an object state.';

COMMENT ON COLUMN db.state_text.state IS 'Reference to db.state.';
COMMENT ON COLUMN db.state_text.locale IS 'Locale for this translation.';
COMMENT ON COLUMN db.state_text.label IS 'Localised display label.';

--------------------------------------------------------------------------------

CREATE INDEX ON db.state_text (state);
CREATE INDEX ON db.state_text (locale);

--------------------------------------------------------------------------------
-- ACTION ----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.action (
    id          uuid PRIMARY KEY DEFAULT gen_kernel_uuid('b'),
    code        text NOT NULL
);

COMMENT ON TABLE db.action IS 'Workflow action (e.g. create, enable, disable, delete, execute).';

COMMENT ON COLUMN db.action.id IS 'Action identifier (UUID).';
COMMENT ON COLUMN db.action.code IS 'Unique action code.';

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

COMMENT ON TABLE db.action_text IS 'Locale-specific name and description for an action.';

COMMENT ON COLUMN db.action_text.action IS 'Reference to db.action.';
COMMENT ON COLUMN db.action_text.locale IS 'Locale for this translation.';
COMMENT ON COLUMN db.action_text.name IS 'Localised display name.';
COMMENT ON COLUMN db.action_text.description IS 'Localised description (optional).';

--------------------------------------------------------------------------------

CREATE INDEX ON db.action_text (action);
CREATE INDEX ON db.action_text (locale);

--------------------------------------------------------------------------------
-- METHOD ----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.method (
    id          uuid PRIMARY KEY DEFAULT gen_kernel_uuid('b'),
    parent      uuid REFERENCES db.method(id),
    class       uuid NOT NULL REFERENCES db.class_tree(id),
    state       uuid REFERENCES db.state(id),
    action      uuid NOT NULL REFERENCES db.action(id),
    code        text NOT NULL,
    sequence    integer NOT NULL,
    visible     boolean DEFAULT true
);

COMMENT ON TABLE db.method IS 'Class method. Binds a (class, state, action) triple into an executable operation.';

COMMENT ON COLUMN db.method.id IS 'Method identifier (UUID).';
COMMENT ON COLUMN db.method.parent IS 'Parent method (for nested/sub-menu methods).';
COMMENT ON COLUMN db.method.class IS 'Class this method belongs to.';
COMMENT ON COLUMN db.method.state IS 'State in which this method is available (NULL = any state).';
COMMENT ON COLUMN db.method.action IS 'Action performed by this method.';
COMMENT ON COLUMN db.method.code IS 'Auto-generated code: "state_code:action_code".';
COMMENT ON COLUMN db.method.sequence IS 'Display/processing order.';
COMMENT ON COLUMN db.method.visible IS 'Whether this method appears in the UI.';

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

COMMENT ON TABLE db.method_text IS 'Locale-specific label for a method.';

COMMENT ON COLUMN db.method_text.method IS 'Reference to db.method.';
COMMENT ON COLUMN db.method_text.locale IS 'Locale for this translation.';
COMMENT ON COLUMN db.method_text.label IS 'Localised display label.';

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

CREATE OR REPLACE FUNCTION db.ft_method_after_insert()
RETURNS trigger AS $$
DECLARE
  bAllow    bit(3);
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
  EXECUTE PROCEDURE db.ft_method_after_insert();

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
    method      uuid NOT NULL REFERENCES db.method(id) ON DELETE CASCADE,
    userid      uuid NOT NULL REFERENCES db.user(id) ON DELETE CASCADE,
    deny        bit(3) NOT NULL,
    allow       bit(3) NOT NULL,
    mask        bit(3) DEFAULT B'000' NOT NULL,
    PRIMARY KEY (method, userid)
);

COMMENT ON TABLE db.amu IS 'Access Method Unit. Per-method permission bitmask for each user/group.';

COMMENT ON COLUMN db.amu.method IS 'Method this ACL entry applies to.';
COMMENT ON COLUMN db.amu.userid IS 'User or group granted/denied access.';
COMMENT ON COLUMN db.amu.deny IS 'Deny bits: {xve} where x=execute, v=visible, e=enable.';
COMMENT ON COLUMN db.amu.allow IS 'Allow bits: {xve} where x=execute, v=visible, e=enable.';
COMMENT ON COLUMN db.amu.mask IS 'Effective mask: allow & ~deny. Computed by trigger.';

CREATE INDEX ON db.amu (method);
CREATE INDEX ON db.amu (userid);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_amu_before()
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
  EXECUTE PROCEDURE db.ft_amu_before();

--------------------------------------------------------------------------------
-- db.transition ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.transition (
    id          uuid PRIMARY KEY DEFAULT gen_kernel_uuid('b'),
    state       uuid REFERENCES db.state(id),
    method      uuid NOT NULL UNIQUE REFERENCES db.method(id),
    newState    uuid NOT NULL REFERENCES db.state(id)
);

COMMENT ON TABLE db.transition IS 'State transition. Maps a method to the new state it produces.';

COMMENT ON COLUMN db.transition.id IS 'Transition identifier (UUID).';
COMMENT ON COLUMN db.transition.state IS 'Current state before the transition (NULL = initial/any).';
COMMENT ON COLUMN db.transition.method IS 'Method that triggers this transition.';
COMMENT ON COLUMN db.transition.newState IS 'Target state after the transition.';

CREATE INDEX ON db.transition (state);
CREATE INDEX ON db.transition (method);

--------------------------------------------------------------------------------
-- EVENT -----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.event_type (
    id          uuid PRIMARY KEY,
    code        text NOT NULL
);

COMMENT ON TABLE db.event_type IS 'Event type classifier (e.g. before, after, execute).';

COMMENT ON COLUMN db.event_type.id IS 'Event type identifier (UUID).';
COMMENT ON COLUMN db.event_type.code IS 'Unique event type code.';

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

COMMENT ON TABLE db.event_type_text IS 'Locale-specific name and description for an event type.';

COMMENT ON COLUMN db.event_type_text.type IS 'Reference to db.event_type.';
COMMENT ON COLUMN db.event_type_text.locale IS 'Locale for this translation.';
COMMENT ON COLUMN db.event_type_text.name IS 'Localised display name.';
COMMENT ON COLUMN db.event_type_text.description IS 'Localised description (optional).';

--------------------------------------------------------------------------------

CREATE INDEX ON db.event_type_text (type);
CREATE INDEX ON db.event_type_text (locale);

--------------------------------------------------------------------------------
-- db.event --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.event (
    id          uuid PRIMARY KEY DEFAULT gen_kernel_uuid('b'),
    class       uuid NOT NULL REFERENCES db.class_tree(id),
    type        uuid NOT NULL REFERENCES db.event_type(id),
    action      uuid NOT NULL REFERENCES db.action(id),
    text        text,
    sequence    integer NOT NULL,
    enabled     boolean DEFAULT TRUE NOT NULL
);

COMMENT ON TABLE db.event IS 'Workflow event. PL/pgSQL handler fired when an action occurs on a class.';

COMMENT ON COLUMN db.event.id IS 'Event identifier (UUID).';
COMMENT ON COLUMN db.event.class IS 'Class this event is bound to.';
COMMENT ON COLUMN db.event.type IS 'Event type (before, after, execute).';
COMMENT ON COLUMN db.event.action IS 'Action that triggers this event.';
COMMENT ON COLUMN db.event.text IS 'PL/pgSQL code body executed when the event fires.';
COMMENT ON COLUMN db.event.sequence IS 'Execution order among events for the same action.';
COMMENT ON COLUMN db.event.enabled IS 'Whether this event handler is active.';

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

COMMENT ON TABLE db.event_text IS 'Locale-specific label for an event.';

COMMENT ON COLUMN db.event_text.event IS 'Reference to db.event.';
COMMENT ON COLUMN db.event_text.locale IS 'Locale for this translation.';
COMMENT ON COLUMN db.event_text.label IS 'Localised display label.';

--------------------------------------------------------------------------------

CREATE INDEX ON db.event_text (event);
CREATE INDEX ON db.event_text (locale);

--------------------------------------------------------------------------------
-- PRIORITY --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.priority (
    id          uuid PRIMARY KEY DEFAULT gen_kernel_uuid('b'),
    code        text NOT NULL
);

COMMENT ON TABLE db.priority IS 'Priority level for objects/tasks (e.g. low, normal, high, critical).';

COMMENT ON COLUMN db.priority.id IS 'Priority identifier (UUID).';
COMMENT ON COLUMN db.priority.code IS 'Unique priority code.';

CREATE UNIQUE INDEX ON db.priority (code);

--------------------------------------------------------------------------------
-- db.priority_text ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.priority_text (
    priority    uuid NOT NULL REFERENCES db.priority(id) ON DELETE CASCADE,
    locale      uuid NOT NULL REFERENCES db.locale(id) ON DELETE RESTRICT,
    name        text NOT NULL,
    description text,
    PRIMARY KEY (priority, locale)
);

--------------------------------------------------------------------------------

COMMENT ON TABLE db.priority_text IS 'Locale-specific name and description for a priority level.';

COMMENT ON COLUMN db.priority_text.priority IS 'Reference to db.priority.';
COMMENT ON COLUMN db.priority_text.locale IS 'Locale for this translation.';
COMMENT ON COLUMN db.priority_text.name IS 'Localised display name.';
COMMENT ON COLUMN db.priority_text.description IS 'Localised description (optional).';

--------------------------------------------------------------------------------

CREATE INDEX ON db.priority_text (priority);
CREATE INDEX ON db.priority_text (locale);
