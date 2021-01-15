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

--------------------------------------------------------------------------------
-- CreateNotice ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт новое извещение
 * @param {numeric} pUserId - Идентификатор пользователя
 * @param {numeric} pObject - Идентификатор объекта
 * @param {text} pText - Текст извещения
 * @param {text} pCategory - Категория извещения
 * @param {integer} pStatus - Статус: 0 - создано; 1 - доставлено; 2 - прочитано; 3 - принято; 4 - отказано
 * @return {numeric} - Идентификатор извещения
 */
CREATE OR REPLACE FUNCTION CreateNotice (
  pUserId		numeric,
  pObject		numeric,
  pText			text,
  pCategory		text default null,
  pStatus		integer default null
) RETURNS		numeric
AS $$
DECLARE
  nNotice		numeric;
BEGIN
  INSERT INTO db.notice (userid, object, text, category, status)
  VALUES (pUserId, pObject, pText, coalesce(pCategory, 'notice'), coalesce(pStatus, 0))
  RETURNING id INTO nNotice;

  RETURN nNotice;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditNotice ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Меняет извещение.
 * @param {numeric} pId - Идентификатор извещения
 * @param {numeric} pUserId - Идентификатор пользователя
 * @param {numeric} pObject - Идентификатор объекта
 * @param {text} pText - Текст извещения
 * @param {text} pCategory - Категория извещения
 * @param {integer} pStatus - Статус: 0 - создано; 1 - доставлено; 2 - прочитано; 3 - принято; 4 - отказано
 * @return {void}
 */
CREATE OR REPLACE FUNCTION EditNotice (
  pId			numeric,
  pUserId		numeric default null,
  pObject		numeric default null,
  pText			text default null,
  pCategory		text default null,
  pStatus		integer default null
) RETURNS		void
AS $$
BEGIN
  UPDATE db.notice
     SET userid = coalesce(pUserId, userid),
         object = coalesce(pObject, object),
         text = coalesce(pText, text),
         category = coalesce(pCategory, category),
         status = coalesce(pStatus, status),
         updated = Now()
   WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SetNotice -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetNotice (
  pId			numeric,
  pUserId		numeric default null,
  pObject		numeric default null,
  pText			text default null,
  pCategory		text default null,
  pStatus		integer default null
) RETURNS		numeric
AS $$
BEGIN
  IF pId IS NULL THEN
    pId := CreateNotice(pUserId, pObject, pText, pCategory, pStatus);
  ELSE
    PERFORM EditNotice(pId, pUserId, pObject, pText, pCategory, pStatus);
  END IF;

  RETURN pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteNotice ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет извещение.
 * @param {numeric} pId - Идентификатор извещения
 * @return {boolean}
 */
CREATE OR REPLACE FUNCTION DeleteNotice (
  pId			numeric
) RETURNS		boolean
AS $$
BEGIN
  DELETE FROM db.notice WHERE id = pId;
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- Notice ----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Notice
AS
  SELECT n.id, n.userid, n.object,
         o.entity, o.entitycode, o.entityname,
         o.class, o.classcode, o.classlabel,
         o.type, o.typecode, o.typename, o.typedescription,
         n.text, n.category, n.status,
         CASE
         WHEN n.status = 0 THEN 'created'
         WHEN n.status = 1 THEN 'delivered'
         WHEN n.status = 2 THEN 'read'
         WHEN n.status = 3 THEN 'accepted'
         WHEN n.status = 4 THEN 'refused'
         ELSE 'undefined'
         END AS StatusCode,
         n.created, n.updated
    FROM db.notice n LEFT JOIN Object o ON n.object = o.id;

GRANT SELECT ON Notice TO administrator;
