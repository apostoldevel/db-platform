--------------------------------------------------------------------------------
-- db.log ----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.log (
    id          bigserial PRIMARY KEY NOT NULL,
    type        char DEFAULT 'M' NOT NULL CHECK (type IN ('M', 'W', 'E', 'D')),
    datetime    timestamptz DEFAULT clock_timestamp() NOT NULL,
    timestamp   timestamptz DEFAULT Now() NOT NULL,
    username    text NOT NULL,
    session     char(40),
    code        integer NOT NULL,
    event       text NOT NULL,
    text        text NOT NULL,
    category    text,
    object      uuid
);

COMMENT ON TABLE db.log IS 'Event log: structured audit trail for messages, warnings, errors, and debug entries.';

COMMENT ON COLUMN db.log.id IS 'Unique auto-generated event identifier.';
COMMENT ON COLUMN db.log.type IS 'Event severity: M=message, W=warning, E=error, D=debug.';
COMMENT ON COLUMN db.log.datetime IS 'Wall-clock time when the row was physically inserted (clock_timestamp).';
COMMENT ON COLUMN db.log.timestamp IS 'Transaction time when the event was created (Now).';
COMMENT ON COLUMN db.log.username IS 'Login name of the user who triggered the event.';
COMMENT ON COLUMN db.log.session IS 'Session token (40-char) active at the time of the event.';
COMMENT ON COLUMN db.log.code IS 'Application-defined numeric event code.';
COMMENT ON COLUMN db.log.event IS 'Event name or subsystem label (e.g. log, exception).';
COMMENT ON COLUMN db.log.text IS 'Human-readable event description or error message.';
COMMENT ON COLUMN db.log.category IS 'Object class code for categorization (resolved from db.object).';
COMMENT ON COLUMN db.log.object IS 'UUID of the related business object, if any.';

CREATE INDEX ON db.log (type);
CREATE INDEX ON db.log (datetime);
CREATE INDEX ON db.log (timestamp);
CREATE INDEX ON db.log (username);
CREATE INDEX ON db.log (code);
CREATE INDEX ON db.log (event);
CREATE INDEX ON db.log (category);

--------------------------------------------------------------------------------

/**
 * @brief Populate default columns on log row insertion.
 * @return {trigger} - Modified NEW row with datetime, username, and session filled in
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION db.ft_log_insert()
RETURNS trigger AS $$
BEGIN
  NEW.datetime := clock_timestamp();

  IF NULLIF(NEW.username, '') IS NULL THEN
     NEW.username := coalesce(current_username(), session_user);
  END IF;

  IF NEW.session IS NULL THEN
    NEW.session := current_session();
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_log_insert
  BEFORE INSERT ON db.log
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_log_insert();

--------------------------------------------------------------------------------

/**
 * @brief Broadcast a pg_notify event after a log row is inserted.
 * @return {trigger} - Unchanged NEW row (notification is a side effect)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION db.ft_log_after_insert()
RETURNS trigger AS $$
BEGIN
  PERFORM pg_notify('log', json_build_object('id', NEW.id, 'type', NEW.type, 'code', NEW.code, 'username', NEW.username, 'event', NEW.event, 'category', NEW.category)::text);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_log_after_insert
  AFTER INSERT ON db.log
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_log_after_insert();
