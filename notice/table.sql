--------------------------------------------------------------------------------
-- NOTICE ----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.notice -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.notice (
    id			bigserial PRIMARY KEY,
    userid		numeric(12) NOT NULL,
    object		numeric(12),
    text		text NOT NULL,
    category	text NOT NULL,
    status		integer DEFAULT 0 NOT NULL,
    created		timestamp DEFAULT Now() NOT NULL,
    updated		timestamp DEFAULT Now() NOT NULL,
    CONSTRAINT ch_notice_status CHECK (status BETWEEN 0 AND 4),
    CONSTRAINT fk_notice_userid FOREIGN KEY (userid) REFERENCES db.user(id),
    CONSTRAINT fk_notice_object FOREIGN KEY (object) REFERENCES db.object(id)
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
