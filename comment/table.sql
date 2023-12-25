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

COMMENT ON TABLE db.comment IS 'Комментарий.';

COMMENT ON COLUMN db.comment.id IS 'Идентификатор.';
COMMENT ON COLUMN db.comment.parent IS 'Идентификатор родителя.';
COMMENT ON COLUMN db.comment.object IS 'Идентификатор объекта.';
COMMENT ON COLUMN db.comment.owner IS 'Владелец.';
COMMENT ON COLUMN db.comment.created IS 'Дата создания.';
COMMENT ON COLUMN db.comment.updated IS 'Дата обновления.';
COMMENT ON COLUMN db.comment.priority IS 'Приоритет.';
COMMENT ON COLUMN db.comment.text IS 'Текст.';
COMMENT ON COLUMN db.comment.data IS 'Данные.';

CREATE INDEX ON db.comment (parent);
CREATE INDEX ON db.comment (object);
CREATE INDEX ON db.comment (owner);

--------------------------------------------------------------------------------

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
