--------------------------------------------------------------------------------
-- COMMENT ---------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.comment ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.comment (
    id          uuid PRIMARY KEY DEFAULT gen_kernel_uuid('8'),
    parent      uuid REFERENCES db.comment(id),
    object      uuid NOT NULL REFERENCES db.object(id),
    owner       uuid NOT NULL REFERENCES db.user(id),
    created     timestamptz DEFAULT Now() NOT NULL,
    updated     timestamptz DEFAULT Now() NOT NULL,
    priority    integer NOT NULL DEFAULT 0,
    text        text NOT NULL,
    data        jsonb
);

COMMENT ON TABLE db.comment IS 'Threaded comment attached to an object.';

COMMENT ON COLUMN db.comment.id IS 'Comment identifier (UUID).';
COMMENT ON COLUMN db.comment.parent IS 'Parent comment identifier for threading (NULL = top-level).';
COMMENT ON COLUMN db.comment.object IS 'Target object this comment belongs to.';
COMMENT ON COLUMN db.comment.owner IS 'User who authored the comment.';
COMMENT ON COLUMN db.comment.created IS 'Timestamp when the comment was created.';
COMMENT ON COLUMN db.comment.updated IS 'Timestamp of the last edit.';
COMMENT ON COLUMN db.comment.priority IS 'Sort priority (higher values appear first).';
COMMENT ON COLUMN db.comment.text IS 'Comment body text.';
COMMENT ON COLUMN db.comment.data IS 'Arbitrary JSON payload.';

CREATE INDEX ON db.comment (parent);
CREATE INDEX ON db.comment (object);
CREATE INDEX ON db.comment (owner);

--------------------------------------------------------------------------------

/**
 * @brief Refresh the updated timestamp before every comment update.
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION db.ft_comment_before_update()
RETURNS trigger AS $$
BEGIN
  NEW.updated := Now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_comment_before_update
  BEFORE UPDATE ON db.comment
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_comment_before_update();
