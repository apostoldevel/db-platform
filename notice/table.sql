--------------------------------------------------------------------------------
-- NOTICE ----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.notice -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.notice (
    id			uuid PRIMARY KEY DEFAULT gen_kernel_uuid('8'),
    userid		uuid NOT NULL REFERENCES db.user(id),
    object		uuid REFERENCES db.object(id),
    text		text NOT NULL,
    category	text NOT NULL,
    status		integer DEFAULT 0 NOT NULL CHECK (status BETWEEN 0 AND 4),
    created		timestamp DEFAULT Now() NOT NULL,
    updated		timestamp DEFAULT Now() NOT NULL,
    data        json
);

COMMENT ON TABLE db.notice IS 'Извещение.';

COMMENT ON COLUMN db.notice.id IS 'Идентификатор';
COMMENT ON COLUMN db.notice.userid IS 'Идентификатор пользователя';
COMMENT ON COLUMN db.notice.object IS 'Идентификатор объекта';
COMMENT ON COLUMN db.notice.text IS 'Текст извещения';
COMMENT ON COLUMN db.notice.category IS 'Категория извещения';
COMMENT ON COLUMN db.notice.status IS 'Статус: 0 - создано; 1 - доставлено; 2 - прочитано; 3 - принято; 4 - отказано.';
COMMENT ON COLUMN db.notice.created IS 'Дата создания';
COMMENT ON COLUMN db.notice.updated IS 'Дата обновления';
COMMENT ON COLUMN db.notice.data IS 'Данные в произвольном формате.';

CREATE INDEX ON db.notice (userid);
CREATE INDEX ON db.notice (object);
CREATE INDEX ON db.notice (category);
CREATE INDEX ON db.notice (status);

--------------------------------------------------------------------------------

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
