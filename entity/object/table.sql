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
    ldate       timestamptz NOT NULL DEFAULT oper_date(),
    udate       timestamptz NOT NULL DEFAULT Now()
);

COMMENT ON TABLE db.object IS 'Root entity table. Every entity (reference, document) inherits from object.';

COMMENT ON COLUMN db.object.id IS 'Object identifier (UUID).';
COMMENT ON COLUMN db.object.parent IS 'Parent object (self-referencing hierarchy).';
COMMENT ON COLUMN db.object.scope IS 'Database scope (tenant/visibility boundary).';
COMMENT ON COLUMN db.object.entity IS 'Entity kind (e.g. reference, document, message).';
COMMENT ON COLUMN db.object.class IS 'Class within the class tree hierarchy.';
COMMENT ON COLUMN db.object.type IS 'Concrete type within the class.';
COMMENT ON COLUMN db.object.state_type IS 'Current state type (created, enabled, disabled, deleted).';
COMMENT ON COLUMN db.object.state IS 'Current workflow state.';
COMMENT ON COLUMN db.object.suid IS 'System user who created the session.';
COMMENT ON COLUMN db.object.owner IS 'Owner (user who owns this object).';
COMMENT ON COLUMN db.object.oper IS 'User who performed the last operation.';
COMMENT ON COLUMN db.object.pdate IS 'Physical creation timestamp.';
COMMENT ON COLUMN db.object.ldate IS 'Logical (business) date of last operation.';
COMMENT ON COLUMN db.object.udate IS 'Last modification timestamp.';

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

COMMENT ON TABLE db.object_text IS 'Localized text (label and description) for an object.';

COMMENT ON COLUMN db.object_text.object IS 'Object identifier.';
COMMENT ON COLUMN db.object_text.locale IS 'Locale identifier.';
COMMENT ON COLUMN db.object_text.label IS 'Short display label.';
COMMENT ON COLUMN db.object_text.text IS 'Extended description or body text.';

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

COMMENT ON COLUMN db.object_text.searchable_en IS 'Full-text search index (English).';
COMMENT ON COLUMN db.object_text.searchable_ru IS 'Full-text search index (Russian).';

CREATE INDEX ON db.object_text USING GIN (searchable_en);
CREATE INDEX ON db.object_text USING GIN (searchable_ru);

--------------------------------------------------------------------------------

/**
 * @brief Populate computed fields and validate before inserting an object.
 * @param {trigger} NEW - Incoming object row
 * @return {trigger} - Modified NEW row with resolved class, entity, scope, and timestamps
 * @throws AbstractError - When the resolved class is abstract
 * @since 1.0.0
 */
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
  NEW.ldate := oper_date();
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

/**
 * @brief Initialize access control entries after inserting an object.
 * @param {trigger} NEW - Newly inserted object row
 * @return {trigger} - NEW (unchanged)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION db.ft_object_after_insert()
RETURNS trigger AS $$
DECLARE
  uUserId    uuid;
  vEntity   text;
BEGIN
  INSERT INTO db.aom SELECT NEW.id;
  INSERT INTO db.aou (object, userid, deny, allow) SELECT NEW.id, userid, SubString(deny FROM 3 FOR 3), SubString(allow FROM 3 FOR 3) FROM db.acu WHERE class = NEW.class AND (SubString(allow FROM 3 FOR 3) & ~SubString(deny FROM 3 FOR 3)) <> B'000';

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

/**
 * @brief Validate access, recalculate class/state/owner ACL before updating an object.
 * @param {trigger} NEW - Updated object row
 * @return {trigger} - Modified NEW row
 * @throws AccessDenied - When the current user lacks update permission
 * @throws IncorrectEntity - When a type change would alter the entity
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION db.ft_object_before_update()
RETURNS trigger AS $$
DECLARE
  bSystem   boolean;
BEGIN
  IF session_user NOT IN ('kernel', 'postgres') THEN
    IF NOT CheckObjectAccess(NEW.id, B'010') THEN
      PERFORM AccessDenied();
    END IF;
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

  NEW.ldate := oper_date();
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

/**
 * @brief Verify delete permission and remove ACL entries before deleting an object.
 * @param {trigger} OLD - Object row being deleted
 * @return {trigger} - OLD row (allows deletion to proceed)
 * @throws AccessDenied - When the current user lacks delete permission
 * @since 1.0.0
 */
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

COMMENT ON TABLE db.aom IS 'Access Object Mask. Default POSIX-style bitmask per object.';

COMMENT ON COLUMN db.aom.object IS 'Object identifier.';
COMMENT ON COLUMN db.aom.mask IS 'Nine-bit access mask: {u:sud}{g:sud}{o:sud} where s=select, u=update, d=delete for u=owner, g=group, o=others.';

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

COMMENT ON TABLE db.aou IS 'Access Object User. Per-user/group deny+allow bits for each object.';

COMMENT ON COLUMN db.aou.object IS 'Object identifier.';
COMMENT ON COLUMN db.aou.userid IS 'User or group identifier.';
COMMENT ON COLUMN db.aou.deny IS 'Deny bits: {sud} where s=select, u=update, d=delete.';
COMMENT ON COLUMN db.aou.allow IS 'Allow bits: {sud} where s=select, u=update, d=delete.';
COMMENT ON COLUMN db.aou.mask IS 'Effective mask: allow AND NOT deny.';
COMMENT ON COLUMN db.aou.entity IS 'Entity (denormalized from object for fast filtering).';

CREATE INDEX ON db.aou (object);
CREATE INDEX ON db.aou (userid);
CREATE INDEX ON db.aou (entity);
CREATE INDEX ON db.aou (entity, userid, mask);

--------------------------------------------------------------------------------

/**
 * @brief Compute effective mask and populate entity before inserting/updating AOU rows.
 * @param {trigger} NEW - AOU row being inserted or updated
 * @return {trigger} - Modified NEW row with computed mask and entity
 * @since 1.0.0
 */
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

COMMENT ON TABLE db.oma IS 'Object Method Access. Per-user permission cache for object methods.';

COMMENT ON COLUMN db.oma.object IS 'Object identifier.';
COMMENT ON COLUMN db.oma.method IS 'Method identifier.';
COMMENT ON COLUMN db.oma.userid IS 'User or group identifier.';
COMMENT ON COLUMN db.oma.mask IS 'Method access mask: {xve} where x=execute, v=visible, e=enable.';

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

COMMENT ON TABLE db.object_state IS 'Object state history. Tracks temporal validity periods per state.';

COMMENT ON COLUMN db.object_state.id IS 'Record identifier.';
COMMENT ON COLUMN db.object_state.object IS 'Object identifier.';
COMMENT ON COLUMN db.object_state.state IS 'State identifier.';
COMMENT ON COLUMN db.object_state.validFromDate IS 'Start of the validity period.';
COMMENT ON COLUMN db.object_state.validToDate IS 'End of the validity period.';

CREATE INDEX ON db.object_state (object);
CREATE INDEX ON db.object_state (state);
CREATE INDEX ON db.object_state (object, validFromDate, validToDate);

CREATE UNIQUE INDEX ON db.object_state (object, state, validFromDate, validToDate);

--------------------------------------------------------------------------------

/**
 * @brief Enforce date constraints and clear object state on deletion of active period.
 * @param {trigger} NEW/OLD - Object state row being inserted, updated, or deleted
 * @return {trigger} - NEW or OLD depending on operation
 * @throws DateValidityPeriod - When validFromDate exceeds validToDate
 * @since 1.0.0
 */
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

COMMENT ON TABLE db.method_stack IS 'Method execution stack. Accumulates results during method execution.';

COMMENT ON COLUMN db.method_stack.object IS 'Object identifier.';
COMMENT ON COLUMN db.method_stack.method IS 'Method identifier.';
COMMENT ON COLUMN db.method_stack.result IS 'Execution result (JSON), if any.';

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

COMMENT ON TABLE db.object_group IS 'Named groups for organizing objects (per-user).';

COMMENT ON COLUMN db.object_group.id IS 'Group identifier.';
COMMENT ON COLUMN db.object_group.owner IS 'Owner (user who created the group).';
COMMENT ON COLUMN db.object_group.code IS 'Unique code within owner scope.';
COMMENT ON COLUMN db.object_group.name IS 'Display name.';
COMMENT ON COLUMN db.object_group.description IS 'Optional description.';

CREATE UNIQUE INDEX ON db.object_group (owner, code);

CREATE INDEX ON db.object_group (owner);

--------------------------------------------------------------------------------

/**
 * @brief Auto-generate id, owner, and code defaults before inserting an object group.
 * @param {trigger} NEW - Object group row being inserted
 * @return {trigger} - Modified NEW row
 * @since 1.0.0
 */
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

COMMENT ON TABLE db.object_group_member IS 'Membership of objects in groups (many-to-many).';

COMMENT ON COLUMN db.object_group_member.gid IS 'Group identifier.';
COMMENT ON COLUMN db.object_group_member.object IS 'Object identifier.';

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

COMMENT ON TABLE db.object_link IS 'Temporal many-to-many links between objects.';

COMMENT ON COLUMN db.object_link.object IS 'Source object identifier.';
COMMENT ON COLUMN db.object_link.linked IS 'Target (linked) object identifier.';
COMMENT ON COLUMN db.object_link.key IS 'Link key (relationship discriminator).';
COMMENT ON COLUMN db.object_link.validFromDate IS 'Start of the validity period.';
COMMENT ON COLUMN db.object_link.validToDate IS 'End of the validity period.';

--------------------------------------------------------------------------------

CREATE UNIQUE INDEX ON db.object_link (object, key, validFromDate, validToDate);
CREATE UNIQUE INDEX ON db.object_link (object, linked, validFromDate, validToDate);

--------------------------------------------------------------------------------
-- db.object_reference ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.object_reference (
    id              uuid PRIMARY KEY DEFAULT gen_kernel_uuid('8'),
    object          uuid NOT NULL REFERENCES db.object(id) ON DELETE CASCADE,
    key             text NOT NULL,
    reference       text NOT NULL,
    validFromDate   timestamptz DEFAULT Now() NOT NULL,
    validToDate     timestamptz DEFAULT TO_DATE('4433-12-31', 'YYYY-MM-DD') NOT NULL
);

--------------------------------------------------------------------------------

COMMENT ON TABLE db.object_reference IS 'Temporal external reference (URI/string) attached to an object.';

COMMENT ON COLUMN db.object_reference.object IS 'Object identifier.';
COMMENT ON COLUMN db.object_reference.key IS 'Reference key (discriminator).';
COMMENT ON COLUMN db.object_reference.reference IS 'External reference string (URI, code, etc.).';
COMMENT ON COLUMN db.object_reference.validFromDate IS 'Start of the validity period.';
COMMENT ON COLUMN db.object_reference.validToDate IS 'End of the validity period.';

--------------------------------------------------------------------------------

CREATE UNIQUE INDEX ON db.object_reference (object, key, validFromDate, validToDate);
CREATE UNIQUE INDEX ON db.object_reference (reference, key, validFromDate, validToDate);

--------------------------------------------------------------------------------
-- db.object_file --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.object_file (
    object      uuid NOT NULL REFERENCES db.object(id) ON DELETE CASCADE,
    file        uuid NOT NULL REFERENCES db.file(id) ON DELETE RESTRICT,
    updated     timestamptz DEFAULT Now() NOT NULL,
    PRIMARY KEY (object, file)
);

COMMENT ON TABLE db.object_file IS 'File attachments associated with an object.';

COMMENT ON COLUMN db.object_file.object IS 'Object identifier.';
COMMENT ON COLUMN db.object_file.file IS 'File identifier (references db.file).';
COMMENT ON COLUMN db.object_file.updated IS 'Timestamp of the last update to the attachment.';

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

COMMENT ON TABLE db.object_data IS 'Arbitrary key-value data attached to an object.';

COMMENT ON COLUMN db.object_data.object IS 'Object identifier.';
COMMENT ON COLUMN db.object_data.type IS 'Data format: text, json, xml, or base64.';
COMMENT ON COLUMN db.object_data.code IS 'Data key (unique per object+type).';
COMMENT ON COLUMN db.object_data.data IS 'Stored value (text representation).';

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

COMMENT ON TABLE db.object_coordinates IS 'Temporal GPS coordinates attached to an object.';

COMMENT ON COLUMN db.object_coordinates.id IS 'Record identifier.';
COMMENT ON COLUMN db.object_coordinates.object IS 'Object identifier.';
COMMENT ON COLUMN db.object_coordinates.code IS 'Coordinate set code (e.g. "default").';
COMMENT ON COLUMN db.object_coordinates.latitude IS 'Latitude in decimal degrees.';
COMMENT ON COLUMN db.object_coordinates.longitude IS 'Longitude in decimal degrees.';
COMMENT ON COLUMN db.object_coordinates.accuracy IS 'Accuracy / altitude in meters.';
COMMENT ON COLUMN db.object_coordinates.label IS 'Short display label.';
COMMENT ON COLUMN db.object_coordinates.description IS 'Optional description.';
COMMENT ON COLUMN db.object_coordinates.data IS 'Additional data in free-form JSON.';
COMMENT ON COLUMN db.object_coordinates.validFromDate IS 'Start of the validity period.';
COMMENT ON COLUMN db.object_coordinates.validToDate IS 'End of the validity period.';

CREATE UNIQUE INDEX ON db.object_coordinates (object, code, validFromDate, validToDate);
CREATE INDEX ON db.object_coordinates (object);

--------------------------------------------------------------------------------

/**
 * @brief Send a pg_notify geo event when a current-period coordinate is inserted.
 * @param {trigger} NEW - Newly inserted coordinate row
 * @return {trigger} - NEW (unchanged)
 * @since 1.0.0
 */
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
