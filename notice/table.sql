--------------------------------------------------------------------------------
-- NOTICE ----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.notice -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.notice (
    id          uuid PRIMARY KEY DEFAULT gen_kernel_uuid('8'),
    userid      uuid NOT NULL REFERENCES db.user(id),
    object      uuid REFERENCES db.object(id),
    text        text NOT NULL,
    category    text NOT NULL,
    status      integer DEFAULT 0 NOT NULL CHECK (status BETWEEN 0 AND 4),
    created     timestamp DEFAULT Now() NOT NULL,
    updated     timestamp DEFAULT Now() NOT NULL,
    data        jsonb
);

COMMENT ON TABLE db.notice IS 'User notice (alert/notification sent to a specific user).';

COMMENT ON COLUMN db.notice.id IS 'Notice identifier (UUID).';
COMMENT ON COLUMN db.notice.userid IS 'Recipient user identifier.';
COMMENT ON COLUMN db.notice.object IS 'Related object identifier (nullable).';
COMMENT ON COLUMN db.notice.text IS 'Notice message text.';
COMMENT ON COLUMN db.notice.category IS 'Notice category tag (e.g. notice, warning, error).';
COMMENT ON COLUMN db.notice.status IS 'Delivery status: 0=created, 1=delivered, 2=read, 3=accepted, 4=refused.';
COMMENT ON COLUMN db.notice.created IS 'Timestamp when the notice was created.';
COMMENT ON COLUMN db.notice.updated IS 'Timestamp of the last update.';
COMMENT ON COLUMN db.notice.data IS 'Arbitrary JSON payload attached to the notice.';

CREATE INDEX ON db.notice (userid);
CREATE INDEX ON db.notice (object);
CREATE INDEX ON db.notice (category);
CREATE INDEX ON db.notice (status);

--------------------------------------------------------------------------------

/**
 * @brief Fire a pg_notify on the 'notice' channel after a new notice is inserted.
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION db.ft_notice_after_insert()
RETURNS trigger AS $$
BEGIN
  PERFORM pg_notify('notice', json_build_object('id', NEW.id, 'userid', NEW.userid, 'object', NEW.object, 'category', NEW.category)::text);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_notice_after_insert
  AFTER INSERT ON db.notice
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_notice_after_insert();
