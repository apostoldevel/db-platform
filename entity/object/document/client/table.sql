--------------------------------------------------------------------------------
-- db.client -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.client (
    id			uuid PRIMARY KEY,
    document	uuid NOT NULL REFERENCES db.document(id) ON DELETE CASCADE,
    code		text NOT NULL,
    creation    timestamp,
    userId		uuid REFERENCES db.user(id) ON DELETE RESTRICT,
    phone		jsonb,
    email		jsonb,
    info		jsonb
);

--------------------------------------------------------------------------------

COMMENT ON TABLE db.client IS 'Клиент.';

COMMENT ON COLUMN db.client.id IS 'Идентификатор';
COMMENT ON COLUMN db.client.document IS 'Документ';
COMMENT ON COLUMN db.client.code IS 'Код клиента';
COMMENT ON COLUMN db.client.creation IS 'Дата создания (день рождения)';
COMMENT ON COLUMN db.client.userid IS 'Учетная запись клиента';
COMMENT ON COLUMN db.client.phone IS 'Справочник телефонов';
COMMENT ON COLUMN db.client.email IS 'Электронные адреса';
COMMENT ON COLUMN db.client.info IS 'Дополнительная информация';

--------------------------------------------------------------------------------

CREATE INDEX ON db.client (document);

CREATE UNIQUE INDEX ON db.client (userid);
CREATE UNIQUE INDEX ON db.client (code);

CREATE INDEX ON db.client USING GIN (phone jsonb_path_ops);
CREATE INDEX ON db.client USING GIN (email jsonb_path_ops);
CREATE INDEX ON db.client USING GIN (info jsonb_path_ops);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_client_insert()
RETURNS trigger AS $$
BEGIN
  IF NEW.id IS NULL THEN
    SELECT NEW.document INTO NEW.id;
  END IF;

  IF NULLIF(NEW.code, '') IS NULL THEN
    NEW.code := encode(gen_random_bytes(12), 'hex');
  END IF;

  IF NEW.userid IS NOT NULL THEN
    UPDATE db.object SET owner = NEW.userid WHERE id = NEW.document;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_client_insert
  BEFORE INSERT ON db.client
  FOR EACH ROW
  EXECUTE PROCEDURE ft_client_insert();

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_client_update()
RETURNS trigger AS $$
DECLARE
  vStr    text;
BEGIN
  IF NOT CheckObjectAccess(NEW.document, B'010') THEN
    PERFORM AccessDenied();
  END IF;

  IF OLD.userid IS NULL AND NEW.userid IS NOT NULL THEN
    UPDATE db.object SET owner = NEW.userid WHERE id = NEW.document;
  END IF;

  IF NEW.userid IS NOT NULL AND OLD.code IS DISTINCT FROM NEW.code THEN
    UPDATE db.user SET username = NEW.code WHERE id = NEW.userid;
  END IF;

  IF NEW.email IS NOT NULL THEN
    IF jsonb_typeof(NEW.email) = 'array' THEN
      vStr = NULLIF(NEW.email->>0, '');
    ELSE
      vStr = NULLIF(NEW.email->>'default', '');
    END IF;

    IF vStr IS NOT NULL THEN
      UPDATE db.user SET email = vStr WHERE id = NEW.userid;
    END IF;
  END IF;

  IF NEW.phone IS NOT NULL THEN
    IF jsonb_typeof(NEW.phone) = 'array' THEN
      vStr = NULLIF(NEW.phone->>0, '');
    ELSE
      vStr = NULLIF(NEW.phone->>'mobile', '');
    END IF;

    IF vStr IS NOT NULL THEN
      UPDATE db.user SET phone = vStr WHERE id = NEW.userid;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_client_update
  BEFORE UPDATE ON db.client
  FOR EACH ROW
  EXECUTE PROCEDURE ft_client_update();

--------------------------------------------------------------------------------
-- db.client_name --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.client_name (
    id			    uuid PRIMARY KEY DEFAULT gen_kernel_uuid('8'),
    client		    uuid NOT NULL,
    locale		    uuid NOT NULL,
    name		    text NOT NULL,
    short		    text,
    first		    text,
    last		    text,
    middle		    text,
    validFromDate	timestamp DEFAULT Now() NOT NULL,
    validToDate		timestamp DEFAULT TO_DATE('4433-12-31', 'YYYY-MM-DD') NOT NULL,
    CONSTRAINT fk_client_name_client FOREIGN KEY (client) REFERENCES db.client(id),
    CONSTRAINT fk_client_name_locale FOREIGN KEY (locale) REFERENCES db.locale(id)
);

--------------------------------------------------------------------------------

COMMENT ON TABLE db.client_name IS 'Наименование клиента.';

COMMENT ON COLUMN db.client_name.client IS 'Идентификатор клиента';
COMMENT ON COLUMN db.client_name.locale IS 'Язык';
COMMENT ON COLUMN db.client_name.name IS 'Полное наименование компании/Ф.И.О.';
COMMENT ON COLUMN db.client_name.short IS 'Краткое наименование компании';
COMMENT ON COLUMN db.client_name.first IS 'Имя';
COMMENT ON COLUMN db.client_name.last IS 'Фамилия';
COMMENT ON COLUMN db.client_name.middle IS 'Отчество';
COMMENT ON COLUMN db.client_name.validFromDate IS 'Дата начала периода действия';
COMMENT ON COLUMN db.client_name.validToDate IS 'Дата окончания периода действия';

--------------------------------------------------------------------------------

CREATE INDEX ON db.client_name (client);
CREATE INDEX ON db.client_name (locale);
CREATE INDEX ON db.client_name (name);
CREATE INDEX ON db.client_name (name text_pattern_ops);
CREATE INDEX ON db.client_name (short);
CREATE INDEX ON db.client_name (short text_pattern_ops);
CREATE INDEX ON db.client_name (first);
CREATE INDEX ON db.client_name (first text_pattern_ops);
CREATE INDEX ON db.client_name (last);
CREATE INDEX ON db.client_name (last text_pattern_ops);
CREATE INDEX ON db.client_name (middle);
CREATE INDEX ON db.client_name (middle text_pattern_ops);
CREATE INDEX ON db.client_name (first, last, middle);

CREATE INDEX ON db.client_name (locale, validFromDate, validToDate);

CREATE UNIQUE INDEX ON db.client_name (client, locale, validFromDate, validToDate);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_client_name_insert_update()
RETURNS trigger AS $$
DECLARE
  uUserId	uuid;
BEGIN
  IF NEW.locale IS NULL THEN
    NEW.locale := current_locale();
  END IF;

  IF NEW.name IS NULL THEN
    IF NEW.last IS NOT NULL THEN
      NEW.name := NEW.last;
    END IF;

    IF NEW.first IS NOT NULL THEN
      IF NEW.name IS NULL THEN
        NEW.name := NEW.first;
      ELSE
        NEW.name := NEW.name || ' ' || NEW.first;
      END IF;
    END IF;

    IF NEW.middle IS NOT NULL THEN
      IF NEW.name IS NOT NULL THEN
        NEW.name := NEW.name || ' ' || NEW.middle;
      END IF;
    END IF;
  END IF;

  IF NEW.name IS NULL THEN
    SELECT code INTO NEW.name FROM db.client WHERE id = NEW.client;
  END IF;

  UPDATE db.object_text SET label = NEW.name WHERE object = NEW.client AND locale = NEW.locale;

  SELECT UserId INTO uUserId FROM db.client WHERE id = NEW.client;
  IF uUserId IS NOT NULL THEN
    UPDATE db.user SET name = NEW.name WHERE id = uUserId;
    UPDATE db.profile
       SET given_name = NEW.first,
           family_name = NEW.last,
           patronymic_name = NEW.middle
     WHERE userId = uUserId;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_client_name_insert_update
  BEFORE INSERT OR UPDATE ON db.client_name
  FOR EACH ROW
  EXECUTE PROCEDURE ft_client_name_insert_update();
