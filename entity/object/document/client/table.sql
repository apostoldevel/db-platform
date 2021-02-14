--------------------------------------------------------------------------------
-- db.client -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.client (
    id			numeric(12) PRIMARY KEY,
    document	numeric(12) NOT NULL,
    code		text NOT NULL,
    creation    timestamp,
    userId		numeric(12),
    phone		jsonb,
    email		jsonb,
    info		jsonb,
    CONSTRAINT fk_client_document FOREIGN KEY (document) REFERENCES db.document(id),
    CONSTRAINT fk_client_user FOREIGN KEY (userid) REFERENCES db.user(id)
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
  IF NULLIF(NEW.id, 0) IS NULL THEN
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
    id			    numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    client		    numeric(12) NOT NULL,
    locale		    numeric(12) NOT NULL,
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
  nUserId	NUMERIC;
BEGIN
  IF NEW.Locale IS NULL THEN
    NEW.Locale := current_locale();
  END IF;

  IF NEW.Name IS NULL THEN
    IF NEW.Last IS NOT NULL THEN
      NEW.Name := NEW.Last;
    END IF;

    IF NEW.First IS NOT NULL THEN
      IF NEW.Name IS NULL THEN
        NEW.Name := NEW.First;
      ELSE
        NEW.Name := NEW.Name || ' ' || NEW.First;
      END IF;
    END IF;

    IF NEW.Middle IS NOT NULL THEN
      IF NEW.Name IS NOT NULL THEN
        NEW.Name := NEW.Name || ' ' || NEW.Middle;
      END IF;
    END IF;
  END IF;

  IF NEW.Name IS NULL THEN
    SELECT code INTO NEW.Name FROM db.client WHERE id = NEW.Client;
  END IF;

  UPDATE db.object SET label = NEW.Name WHERE Id = NEW.Client;

  SELECT UserId INTO nUserId FROM db.client WHERE Id = NEW.Client;
  IF nUserId IS NOT NULL THEN
    UPDATE db.user SET name = NEW.name WHERE Id = nUserId;
    UPDATE db.profile
       SET given_name = NEW.first,
           family_name = NEW.last,
           patronymic_name = NEW.middle
     WHERE userId = nUserId;
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

--------------------------------------------------------------------------------
-- BALANCE ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.balance (
    id			    numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    type            integer NOT NULL DEFAULT 0,
    client          numeric(12) NOT NULL,
    amount		    numeric NOT NULL,
    validFromDate	timestamptz DEFAULT Now() NOT NULL,
    validToDate		timestamptz DEFAULT MAXDATE() NOT NULL,
    CONSTRAINT ch_balance_type CHECK (type BETWEEN 0 AND 3),
    CONSTRAINT fk_balance_client FOREIGN KEY (client) REFERENCES db.client(id)
);

--------------------------------------------------------------------------------

COMMENT ON TABLE db.balance IS 'Баланс клиента.';

COMMENT ON COLUMN db.balance.id IS 'Идентификатор';
COMMENT ON COLUMN db.balance.type IS 'Тип: 0 - на момент открытия; 1 - реальный; 2 - плановый; 3 - эквивалент';
COMMENT ON COLUMN db.balance.client IS 'Клиент';
COMMENT ON COLUMN db.balance.amount IS 'Сумма';
COMMENT ON COLUMN db.balance.validFromDate IS 'Дата начала периода действия';
COMMENT ON COLUMN db.balance.validToDate IS 'Дата окончания периода действия';

--------------------------------------------------------------------------------

CREATE INDEX ON db.balance (type);
CREATE INDEX ON db.balance (client);

CREATE UNIQUE INDEX ON db.balance (type, client, validFromDate, validToDate);

--------------------------------------------------------------------------------
-- TURN OVER -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.turn_over (
    id			    numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    type            integer NOT NULL DEFAULT 0,
    client          numeric(12) NOT NULL,
    debit		    numeric NOT NULL,
    credit          numeric NOT NULL,
    turn_date       timestamptz NOT NULL,
    updated         timestamptz NOT NULL DEFAULT Now(),
    CONSTRAINT ch_turn_over_type CHECK (type BETWEEN 0 AND 3),
    CONSTRAINT fk_turn_over_client FOREIGN KEY (client) REFERENCES db.client(id)
);

COMMENT ON TABLE db.turn_over IS 'Остаток.';

COMMENT ON COLUMN db.turn_over.id IS 'Идентификатор';
COMMENT ON COLUMN db.turn_over.type IS 'Тип: 0 - на момент открытия; 1 - реальный; 2 - плановый; 3 - эквивалент';
COMMENT ON COLUMN db.turn_over.client IS 'Клиент';
COMMENT ON COLUMN db.turn_over.debit IS 'Сумма обота по дебету';
COMMENT ON COLUMN db.turn_over.credit IS 'Сумма обота по кредиту';
COMMENT ON COLUMN db.turn_over.turn_date IS 'Дата начала периода действия';
COMMENT ON COLUMN db.turn_over.updated IS 'Дата окончания периода действия';

CREATE INDEX ON db.turn_over (type);
CREATE INDEX ON db.turn_over (client);

CREATE INDEX ON db.turn_over (type, client, turn_date);

