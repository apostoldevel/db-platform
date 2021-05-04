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

--------------------------------------------------------------------------------

\ir '../workflow/routine.sql'

--------------------------------------------------------------------------------

INSERT INTO db.state_type_text (type, name, locale) VALUES ('00000000-0000-4000-b001-000000000001', 'Created', current_locale());
INSERT INTO db.state_type_text (type, name, locale) VALUES ('00000000-0000-4000-b001-000000000001', 'Создан', GetLocale('ru'));

INSERT INTO db.state_type_text (type, name, locale) VALUES ('00000000-0000-4000-b001-000000000002', 'Enabled', current_locale());
INSERT INTO db.state_type_text (type, name, locale) VALUES ('00000000-0000-4000-b001-000000000002', 'Включен', GetLocale('ru'));

INSERT INTO db.state_type_text (type, name, locale) VALUES ('00000000-0000-4000-b001-000000000003', 'Disabled', current_locale());
INSERT INTO db.state_type_text (type, name, locale) VALUES ('00000000-0000-4000-b001-000000000003', 'Отключен', GetLocale('ru'));

INSERT INTO db.state_type_text (type, name, locale) VALUES ('00000000-0000-4000-b001-000000000004', 'Deleted', current_locale());
INSERT INTO db.state_type_text (type, name, locale) VALUES ('00000000-0000-4000-b001-000000000004', 'Удалён', GetLocale('ru'));

--------------------------------------------------------------------------------

INSERT INTO db.event_type_text (type, name, locale) VALUES ('00000000-0000-4000-b002-000000000001', 'Parent class events', current_locale());
INSERT INTO db.event_type_text (type, name, locale) VALUES ('00000000-0000-4000-b002-000000000001', 'События класса родителя', GetLocale('ru'));

INSERT INTO db.event_type_text (type, name, locale) VALUES ('00000000-0000-4000-b002-000000000002', 'Event', current_locale());
INSERT INTO db.event_type_text (type, name, locale) VALUES ('00000000-0000-4000-b002-000000000002', 'Событие', GetLocale('ru'));

INSERT INTO db.event_type_text (type, name, locale) VALUES ('00000000-0000-4000-b002-000000000003', 'PL/pgSQL code', current_locale());
INSERT INTO db.event_type_text (type, name, locale) VALUES ('00000000-0000-4000-b002-000000000003', 'PL/pgSQL код', GetLocale('ru'));

--------------------------------------------------------------------------------

SELECT NewEntityText(id, name, description, current_locale()) FROM db.entity;
SELECT NewEntityText(id, name, description, GetLocale('ru')) FROM db.entity;

SELECT NewClassText(id, label, current_locale()) FROM db.class_tree;
SELECT NewClassText(id, label, GetLocale('ru')) FROM db.class_tree;

SELECT NewTypeText(id, name, description, current_locale()) FROM db.type;
SELECT NewTypeText(id, name, description, GetLocale('ru')) FROM db.type;

SELECT NewStateText(id, label, current_locale()) FROM db.state;
SELECT NewStateText(id, label, GetLocale('ru')) FROM db.state;

SELECT NewActionText(id, name, description, current_locale()) FROM db.action;
SELECT NewActionText(id, name, description, GetLocale('ru')) FROM db.action;

SELECT NewMethodText(id, label, current_locale()) FROM db.method;
SELECT NewMethodText(id, label, GetLocale('ru')) FROM db.method;

SELECT NewEventText(id, label, current_locale()) FROM db.event;
SELECT NewEventText(id, label, GetLocale('ru')) FROM db.event;

--------------------------------------------------------------------------------

ALTER TABLE db.entity
  DROP COLUMN name CASCADE,
  DROP COLUMN description CASCADE;

--------------------------------------------------------------------------------

ALTER TABLE db.class_tree
  DROP COLUMN label CASCADE;

--------------------------------------------------------------------------------

ALTER TABLE db.type
  DROP COLUMN name CASCADE,
  DROP COLUMN description CASCADE;

--------------------------------------------------------------------------------

ALTER TABLE db.state_type
  DROP COLUMN name CASCADE;

--------------------------------------------------------------------------------

ALTER TABLE db.state
  DROP COLUMN label CASCADE;

--------------------------------------------------------------------------------

ALTER TABLE db.action
  DROP COLUMN name CASCADE,
  DROP COLUMN description CASCADE;

--------------------------------------------------------------------------------

ALTER TABLE db.method
  DROP COLUMN label CASCADE;

--------------------------------------------------------------------------------

ALTER TABLE db.event_type
  DROP COLUMN name CASCADE;

--------------------------------------------------------------------------------

ALTER TABLE db.event
  DROP COLUMN label CASCADE;

--------------------------------------------------------------------------------

SELECT SignIn(CreateSystemOAuth2(), 'admin', :'admin');

SELECT GetErrorMessage();

SELECT SetSessionLocale('en');

SELECT EditAction('00000000-0000-4000-b003-000000000000', 'anything', 'Anything');

SELECT EditAction('00000000-0000-4000-b003-000000000001', 'abort', 'Abort');
SELECT EditAction('00000000-0000-4000-b003-000000000002', 'accept', 'Accept');
SELECT EditAction('00000000-0000-4000-b003-000000000003', 'add', 'Add');
SELECT EditAction('00000000-0000-4000-b003-000000000004', 'alarm', 'Alarm');
SELECT EditAction('00000000-0000-4000-b003-000000000005', 'approve', 'Approve');
SELECT EditAction('00000000-0000-4000-b003-000000000006', 'available', 'Available');
SELECT EditAction('00000000-0000-4000-b003-000000000007', 'cancel', 'Cancel');
SELECT EditAction('00000000-0000-4000-b003-000000000008', 'check', 'Check');
SELECT EditAction('00000000-0000-4000-b003-000000000009', 'complete', 'Complete');
SELECT EditAction('00000000-0000-4000-b003-000000000010', 'confirm', 'Confirm');
SELECT EditAction('00000000-0000-4000-b003-000000000011', 'create', 'Create');
SELECT EditAction('00000000-0000-4000-b003-000000000012', 'delete', 'Delete');
SELECT EditAction('00000000-0000-4000-b003-000000000013', 'disable', 'Disable');
SELECT EditAction('00000000-0000-4000-b003-000000000014', 'done', 'Done');
SELECT EditAction('00000000-0000-4000-b003-000000000015', 'drop', 'Drop');
SELECT EditAction('00000000-0000-4000-b003-000000000016', 'edit', 'Edit');
SELECT EditAction('00000000-0000-4000-b003-000000000017', 'enable', 'Enable');
SELECT EditAction('00000000-0000-4000-b003-000000000018', 'execute', 'Execute');
SELECT EditAction('00000000-0000-4000-b003-000000000019', 'expire', 'Истекло');
SELECT EditAction('00000000-0000-4000-b003-000000000020', 'fail', 'Fail');
SELECT EditAction('00000000-0000-4000-b003-000000000021', 'faulted', 'Faulted');
SELECT EditAction('00000000-0000-4000-b003-000000000022', 'finishing', 'Finishing');
SELECT EditAction('00000000-0000-4000-b003-000000000023', 'heartbeat', 'Heartbeat');
SELECT EditAction('00000000-0000-4000-b003-000000000024', 'invite', 'Invite');
SELECT EditAction('00000000-0000-4000-b003-000000000025', 'open', 'Open');
SELECT EditAction('00000000-0000-4000-b003-000000000026', 'plan', 'Plan');
SELECT EditAction('00000000-0000-4000-b003-000000000027', 'post', 'Post');
SELECT EditAction('00000000-0000-4000-b003-000000000028', 'postpone', 'Postpone');
SELECT EditAction('00000000-0000-4000-b003-000000000029', 'preparing', 'Preparing');
SELECT EditAction('00000000-0000-4000-b003-000000000030', 'reconfirm', 'Reconfirm');
SELECT EditAction('00000000-0000-4000-b003-000000000031', 'remove', 'Remove');
SELECT EditAction('00000000-0000-4000-b003-000000000032', 'repeat', 'Repeat');
SELECT EditAction('00000000-0000-4000-b003-000000000033', 'reserve', 'Reserve');
SELECT EditAction('00000000-0000-4000-b003-000000000034', 'reserved', 'Reserved');
SELECT EditAction('00000000-0000-4000-b003-000000000035', 'restore', 'Restore');
SELECT EditAction('00000000-0000-4000-b003-000000000036', 'return', 'Return');
SELECT EditAction('00000000-0000-4000-b003-000000000037', 'save', 'Save');
SELECT EditAction('00000000-0000-4000-b003-000000000038', 'send', 'Send');
SELECT EditAction('00000000-0000-4000-b003-000000000039', 'sign', 'Sign');
SELECT EditAction('00000000-0000-4000-b003-000000000040', 'start', 'Start');
SELECT EditAction('00000000-0000-4000-b003-000000000041', 'stop', 'Stop');
SELECT EditAction('00000000-0000-4000-b003-000000000042', 'submit', 'Submit');
SELECT EditAction('00000000-0000-4000-b003-000000000043', 'unavailable', 'Unavailable');
SELECT EditAction('00000000-0000-4000-b003-000000000044', 'update', 'Update');

SELECT EditAction('00000000-0000-4000-b003-000000000045', 'reject', 'Reject');

--------------------------------------------------------------------------------

SELECT EditEntityText(GetEntity('object'), 'Object', null, current_locale());
SELECT EditEntityText(GetEntity('document'), 'Document', null, current_locale());
SELECT EditEntityText(GetEntity('reference'), 'Reference', null, current_locale());
SELECT EditEntityText(GetEntity('message'), 'Message', null, current_locale());
SELECT EditEntityText(GetEntity('job'), 'Job', null, current_locale());
SELECT EditEntityText(GetEntity('agent'), 'Agent', null, current_locale());
SELECT EditEntityText(GetEntity('program'), 'Program', null, current_locale());
SELECT EditEntityText(GetEntity('scheduler'), 'Scheduler', null, current_locale());
SELECT EditEntityText(GetEntity('vendor'), 'Vendor', null, current_locale());
SELECT EditEntityText(GetEntity('version'), 'Version', null, current_locale());
SELECT EditEntityText(GetEntity('client'), 'Client', null, current_locale());
SELECT EditEntityText(GetEntity('calendar'), 'Calendar', null, current_locale());
SELECT EditEntityText(GetEntity('address'), 'Address', null, current_locale());
SELECT EditEntityText(GetEntity('account'), 'Account', null, current_locale());
SELECT EditEntityText(GetEntity('device'), 'Device', null, current_locale());

SELECT EditMethodText(id, actionname, current_locale()) FROM Method;

--------------------------------------------------------------------------------

SELECT SignOut();
