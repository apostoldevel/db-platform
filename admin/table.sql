--------------------------------------------------------------------------------
-- db.interface ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.interface (
    id              numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    sid             varchar(18) NOT NULL,
    name            varchar(50) NOT NULL,
    description     text
);

COMMENT ON TABLE db.interface IS 'Интерфейсы.';

COMMENT ON COLUMN db.interface.id IS 'Идентификатор';
COMMENT ON COLUMN db.interface.sid IS 'Строковый идентификатор';
COMMENT ON COLUMN db.interface.name IS 'Наименование';
COMMENT ON COLUMN db.interface.description IS 'Описание';

CREATE UNIQUE INDEX ON db.interface (sid);
CREATE INDEX ON db.interface (name);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_interface_before_insert()
RETURNS trigger AS $$
BEGIN
  IF NEW.SID IS NULL THEN
    SELECT 'I:1:1:' || TRIM(TO_CHAR(NEW.ID, '999999999999')) INTO NEW.SID;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_interface
  BEFORE INSERT ON db.interface
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_interface_before_insert();

--------------------------------------------------------------------------------
-- db.area_type ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.area_type (
    id        numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    code      varchar(30) NOT NULL,
    name      varchar(50)
);

COMMENT ON TABLE db.area_type IS 'Тип зоны.';

COMMENT ON COLUMN db.area_type.id IS 'Идентификатор';
COMMENT ON COLUMN db.area_type.code IS 'Код';
COMMENT ON COLUMN db.area_type.name IS 'Наименование';

CREATE UNIQUE INDEX ON db.area_type (code);

INSERT INTO db.area_type (code, name) VALUES ('root', 'Корень');
INSERT INTO db.area_type (code, name) VALUES ('system', 'Система');
INSERT INTO db.area_type (code, name) VALUES ('guest', 'Гость');
INSERT INTO db.area_type (code, name) VALUES ('default', 'По умолчанию');
INSERT INTO db.area_type (code, name) VALUES ('main', 'Главный');
INSERT INTO db.area_type (code, name) VALUES ('remote', 'Удаленный');
INSERT INTO db.area_type (code, name) VALUES ('mobile', 'Мобильный');

--------------------------------------------------------------------------------
-- db.area ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.area (
    id              numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    parent          numeric(12) DEFAULT NULL,
    type            numeric(12) NOT NULL,
    code            varchar(30) NOT NULL,
    name            varchar(50) NOT NULL,
    description     text,
    validFromDate   timestamp DEFAULT Now() NOT NULL,
    validToDate     timestamp,
    CONSTRAINT fk_area_parent FOREIGN KEY (parent) REFERENCES db.area(id),
    CONSTRAINT fk_area_type FOREIGN KEY (type) REFERENCES db.area_type(id)
);

COMMENT ON TABLE db.area IS 'Зона.';

COMMENT ON COLUMN db.area.id IS 'Идентификатор';
COMMENT ON COLUMN db.area.parent IS 'Ссылка на родительский узел';
COMMENT ON COLUMN db.area.type IS 'Тип';
COMMENT ON COLUMN db.area.code IS 'Код';
COMMENT ON COLUMN db.area.name IS 'Наименование';
COMMENT ON COLUMN db.area.description IS 'Описание';
COMMENT ON COLUMN db.area.validFromDate IS 'Дата начала действаия';
COMMENT ON COLUMN db.area.validToDate IS 'Дата окончания действия';

CREATE INDEX ON db.area (parent);
CREATE INDEX ON db.area (type);

CREATE UNIQUE INDEX ON db.area (code);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_area_before_insert()
RETURNS trigger AS $$
DECLARE
BEGIN
  IF NEW.ID = NEW.PARENT THEN
    NEW.PARENT := GetArea('all');
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_area_before_insert
  BEFORE INSERT ON db.area
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_area_before_insert();

--------------------------------------------------------------------------------
-- db.user ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.user (
    id					numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_USER'),
    type				char NOT NULL,
    username			text NOT NULL,
    name				text NOT NULL,
    phone				text,
    email				text,
    description			text,
    secret				bytea NOT NULL,
    hash				text NOT NULL,
    status				bit(4) DEFAULT B'0001' NOT NULL,
    created             timestamp DEFAULT Now() NOT NULL,
    lock_date           timestamp DEFAULT NULL,
    expiry_date         timestamp DEFAULT NULL,
    pswhash             text DEFAULT NULL,
    passwordchange		boolean DEFAULT true NOT NULL,
    passwordnotchange	boolean DEFAULT false NOT NULL,
    readonly            boolean DEFAULT false NOT NULL,
    CONSTRAINT ch_user_type CHECK (type IN ('G', 'U'))
);

COMMENT ON TABLE db.user IS 'Пользователи и группы системы.';

COMMENT ON COLUMN db.user.id IS 'Идентификатор';
COMMENT ON COLUMN db.user.type IS 'Тип пользователя: "U" - пользователь; "G" - группа';
COMMENT ON COLUMN db.user.username IS 'Наименование пользователя (login)';
COMMENT ON COLUMN db.user.name IS 'Полное имя';
COMMENT ON COLUMN db.user.phone IS 'Телефон';
COMMENT ON COLUMN db.user.email IS 'Электронный адрес';
COMMENT ON COLUMN db.user.description IS 'Описание пользователя';
COMMENT ON COLUMN db.user.secret IS 'Секрет пользователя';
COMMENT ON COLUMN db.user.hash IS 'Хеш секрета пользователя';
COMMENT ON COLUMN db.user.status IS 'Статус пользователя';
COMMENT ON COLUMN db.user.created IS 'Дата создания пользователя';
COMMENT ON COLUMN db.user.lock_date IS 'Дата блокировки пользователя';
COMMENT ON COLUMN db.user.expiry_date IS 'Дата окончания срока действия пароля';
COMMENT ON COLUMN db.user.pswhash IS 'Хеш пароля';
COMMENT ON COLUMN db.user.passwordchange IS 'Сменить пароль при следующем входе в систему (да/нет)';
COMMENT ON COLUMN db.user.passwordnotchange IS 'Установлен запрет на смену пароля самим пользователем (да/нет)';
COMMENT ON COLUMN db.user.readonly IS 'Только чтение (запрешено изменение)';

CREATE UNIQUE INDEX ON db.user (type, username);
CREATE UNIQUE INDEX ON db.user (hash);
CREATE UNIQUE INDEX ON db.user (phone);
CREATE UNIQUE INDEX ON db.user (email);

CREATE INDEX ON db.user (type);
CREATE INDEX ON db.user (username);
CREATE INDEX ON db.user (username varchar_pattern_ops);
CREATE INDEX ON db.user (phone varchar_pattern_ops);
CREATE INDEX ON db.user (email varchar_pattern_ops);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_user_before_insert()
RETURNS trigger AS $$
BEGIN
  IF NEW.secret IS NULL THEN
    SELECT gen_random_bytes(64) INTO NEW.secret;
  END IF;

  SELECT encode(digest(encode(hmac(NEW.secret::text, GetSecretKey(), 'sha512'), 'hex'), 'sha1'), 'hex') INTO NEW.hash;

  IF NEW.phone IS NOT NULL THEN
    NEW.phone := TrimPhone(NEW.phone);
  END IF;

  NEW.readonly := NEW.username IN ('system', 'administrator', 'guest');
  NEW.readonly := NEW.readonly OR coalesce((SELECT a.name = NEW.username FROM oauth2.audience a WHERE a.name = NEW.username), false);

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_user_before_insert
  BEFORE INSERT ON db.user
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_user_before_insert();

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_user_after_insert()
RETURNS trigger AS $$
BEGIN
  CASE NEW.username
  WHEN 'system' THEN
    INSERT INTO db.acl SELECT NEW.id, B'00000000000000', B'10000000000011';
  WHEN 'administrator' THEN
    INSERT INTO db.acl SELECT NEW.id, B'00000000000000', B'01111111111111';
  WHEN 'guest' THEN
    INSERT INTO db.acl SELECT NEW.id, B'11111111111100', B'00000000000011';
  ELSE
    INSERT INTO db.acl SELECT NEW.id, B'00000000000000', B'00000000000011';
  END CASE;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_user_after_insert
  AFTER INSERT ON db.user
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_user_after_insert();

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_user_after_update()
RETURNS trigger AS $$
BEGIN
  IF OLD.email <> NEW.email THEN
	UPDATE db.profile SET email_verified = false WHERE userid = NEW.id;
  END IF;

  IF NEW.phone IS NOT NULL THEN
    NEW.phone := TrimPhone(NEW.phone);
  END IF;

  IF OLD.phone <> NEW.phone THEN
	UPDATE db.profile SET phone_verified = false WHERE userid = NEW.id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_user_after_update
  AFTER UPDATE ON db.user
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_user_after_update();

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_user_before_delete()
RETURNS trigger AS $$
BEGIN
  DELETE FROM db.iptable WHERE userid = OLD.ID;
  DELETE FROM db.profile WHERE userid = OLD.ID;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_user_before_delete
  BEFORE DELETE ON db.user
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_user_before_delete();

--------------------------------------------------------------------------------
-- db.profile ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.profile (
    userId              numeric(12) PRIMARY KEY,
    family_name         text,
    given_name          text,
    patronymic_name     text,
    input_count         numeric DEFAULT 0 NOT NULL,
    input_last          timestamp DEFAULT NULL,
    input_error         numeric DEFAULT 0 NOT NULL,
    input_error_last    timestamp DEFAULT NULL,
    input_error_all     numeric DEFAULT 0 NOT NULL,
    lc_ip               inet,
    locale              numeric(12) NOT NULL,
    area                numeric(12) NOT NULL,
    interface           numeric(12) NOT NULL,
    state               bit(3) DEFAULT B'000' NOT NULL,
    session_limit       integer DEFAULT 0 NOT NULL,
    email_verified      bool DEFAULT false,
    phone_verified      bool DEFAULT false,
    picture             text,
    CONSTRAINT fk_profile_userid FOREIGN KEY (userid) REFERENCES db.user(id),
    CONSTRAINT fk_profile_locale FOREIGN KEY (locale) REFERENCES db.locale(id),
    CONSTRAINT fk_profile_area FOREIGN KEY (area) REFERENCES db.area(id),
    CONSTRAINT fk_profile_interface FOREIGN KEY (interface) REFERENCES db.interface(id)
);

COMMENT ON TABLE db.profile IS 'Дополнительная информация о пользователе системы.';

COMMENT ON COLUMN db.profile.userid IS 'Пользователь';
COMMENT ON COLUMN db.profile.family_name IS 'Фамилия';
COMMENT ON COLUMN db.profile.given_name IS 'Имя';
COMMENT ON COLUMN db.profile.patronymic_name IS 'Отчество';
COMMENT ON COLUMN db.profile.input_count IS 'Счетчик входов';
COMMENT ON COLUMN db.profile.input_last IS 'Последний вход';
COMMENT ON COLUMN db.profile.input_error IS 'Текущие неудавшиеся входы';
COMMENT ON COLUMN db.profile.input_error_last IS 'Последний неудавшийся вход в систему';
COMMENT ON COLUMN db.profile.input_error_all IS 'Общее количество неудачных входов';
COMMENT ON COLUMN db.profile.lc_ip IS 'IP адрес последнего подключения';
COMMENT ON COLUMN db.profile.locale IS 'Идентификатор локали по умолчанию';
COMMENT ON COLUMN db.profile.area IS 'Идентификатор подразделения по умолчанию';
COMMENT ON COLUMN db.profile.interface IS 'Идентификатор рабочего места по умолчанию';
COMMENT ON COLUMN db.profile.state IS 'Состояние: 000 - Отключен; 001 - Подключен; 010 - локальный IP; 100 - доверительный IP';
COMMENT ON COLUMN db.profile.session_limit IS 'Максимально допустимое количество одновременно открытых сессий.';
COMMENT ON COLUMN db.profile.email_verified IS 'Электронный адрес подтверждён.';
COMMENT ON COLUMN db.profile.phone_verified IS 'Телефон подтверждён.';
COMMENT ON COLUMN db.profile.picture IS 'Логотип.';

CREATE OR REPLACE FUNCTION db.ft_profile_before()
RETURNS trigger AS $$
BEGIN
  IF NEW.locale IS NULL THEN
    SELECT id INTO NEW.locale FROM db.locale WHERE code = 'ru';
  END IF;

  IF NOT IsMemberArea(NEW.area, NEW.userid) THEN
    SELECT id INTO NEW.area FROM db.area WHERE code = 'guest';
  END IF;

  IF NOT IsMemberInterface(NEW.interface, NEW.userid) THEN
    SELECT id INTO NEW.interface FROM db.interface WHERE sid = 'I:1:0:0';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_profile_before
  BEFORE INSERT OR UPDATE ON db.profile
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_profile_before();

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_profile_login_state()
RETURNS trigger AS $$
DECLARE
  i         int;

  arrIp		text[];

  lHost		inet;

  nRange	int;

  vCode		varchar;

  nOnLine	int;
  nLocal	int;
  nTrust	int;

  bSuccess	boolean;

  nUserId	numeric;

  vData		Variant;

  r         record;
BEGIN
  nUserId := current_userid();

  IF nUserId IS NULL THEN
    RETURN NEW;
  END IF;

  nOnLine := 0;
  nLocal := 0;
  nTrust := 0;

  NEW.state := B'000';

  FOR r IN SELECT area, host FROM db.session WHERE userid = nUserId GROUP BY area, host
  LOOP
    r.host := coalesce(NEW.LC_IP, r.host);

    IF r.host IS NOT NULL THEN

      SELECT code INTO vCode FROM db.area WHERE id = r.area;

      IF found THEN

        vData := RegGetValue(RegOpenKey('CURRENT_CONFIG', 'CONFIG\Department' || E'\u005C' || vCode || E'\u005C' || 'IPTable'), 'LocalIP');

        IF vData.vString IS NOT NULL THEN
          arrIp := string_to_array_trim(vData.vString, ',');
        ELSE
          arrIp := string_to_array_trim('127.0.0.1, ::1', ',');
        END IF;

        bSuccess := false;
        FOR i IN 1..array_length(arrIp, 1)
        LOOP
          SELECT host INTO lHost FROM str_to_inet(arrIp[i]);

          bSuccess := r.host <<= lHost;

          EXIT WHEN coalesce(bSuccess, false);
        END LOOP;

        IF bSuccess THEN
          nLocal := nLocal + 1;
        END IF;

        vData := RegGetValue(RegOpenKey('CURRENT_CONFIG', 'CONFIG\Department' || E'\u005C' || vCode || E'\u005C' || 'IPTable'), 'EntrustedIP');

        IF vData.vString IS NOT NULL THEN
          arrIp := string_to_array_trim(vData.vString, ',');

          bSuccess := false;
          FOR i IN 1..array_length(arrIp, 1)
          LOOP
            SELECT host, range INTO lHost, nRange FROM str_to_inet(arrIp[i]);

            IF nRange IS NOT NULL THEN
              bSuccess := (r.host >= lHost) AND (r.host <= lHost + (nRange - 1));
            ELSE
              bSuccess := r.host <<= lHost;
            END IF;

            EXIT WHEN coalesce(bSuccess, false);
          END LOOP;

          IF bSuccess THEN
            nTrust := nTrust + 1;
          END IF;

        END IF;
      END IF;
    END IF;

    nOnLine := nOnLine + 1;
  END LOOP;

  IF nTrust > 0 THEN
    NEW.state := set_bit(NEW.state, 0, 1);
  END IF;

  IF nLocal > 0 THEN
    NEW.state := set_bit(NEW.state, 1, 1);
  END IF;

  IF (nOnLine - (nTrust + nLocal)) > 0 THEN
    NEW.state := set_bit(NEW.state, 2, 1);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_profile_login_state
  BEFORE UPDATE ON db.profile
  FOR EACH ROW
  EXECUTE PROCEDURE ft_profile_login_state();

--------------------------------------------------------------------------------
-- member_group ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.member_group (
    id			numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    userid		numeric(12) NOT NULL,
    member		numeric(12) NOT NULL,
    CONSTRAINT fk_mg_userid FOREIGN KEY (userid) REFERENCES db.user(id),
    CONSTRAINT fk_mg_member FOREIGN KEY (member) REFERENCES db.user(id)
);

COMMENT ON TABLE db.member_group IS 'Членство в группах.';

COMMENT ON COLUMN db.member_group.id IS 'Идентификатор';
COMMENT ON COLUMN db.member_group.userid IS 'Группа';
COMMENT ON COLUMN db.member_group.member IS 'Участник';

CREATE INDEX ON db.member_group (userid);
CREATE INDEX ON db.member_group (member);

CREATE UNIQUE INDEX ON db.member_group (userid, member);

--------------------------------------------------------------------------------
-- RECOVERY TICKET -------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.recovery_ticket ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.recovery_ticket (
    ticket			uuid PRIMARY KEY,
    userId          numeric(12) NOT NULL,
    securityAnswer	text NOT NULL,
    used            boolean NOT NULL DEFAULT false,
    validFromDate   timestamptz NOT NULL,
    validToDate     timestamptz NOT NULL
);

COMMENT ON TABLE db.recovery_ticket IS 'Талон восстановления пароля.';

COMMENT ON COLUMN db.recovery_ticket.ticket IS 'Талон';
COMMENT ON COLUMN db.recovery_ticket.userId IS 'Идентификатор учётной записи';
COMMENT ON COLUMN db.recovery_ticket.securityAnswer IS 'Секретный ответ';
COMMENT ON COLUMN db.recovery_ticket.used IS 'Использован';
COMMENT ON COLUMN db.recovery_ticket.validFromDate IS 'Дата начала действаия';
COMMENT ON COLUMN db.recovery_ticket.validToDate IS 'Дата окончания действия';

--------------------------------------------------------------------------------

CREATE UNIQUE INDEX ON db.recovery_ticket (userid, validFromDate, validToDate);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_recovery_ticket_before()
RETURNS TRIGGER
AS $$
BEGIN
  IF (TG_OP = 'UPDATE') THEN

    IF OLD.securityAnswer <> NEW.securityAnswer THEN
      RAISE DEBUG 'Hacking alert: security answer (% <> %).', OLD.securityAnswer, NEW.securityAnswer;
      RETURN NULL;
    END IF;

  ELSIF (TG_OP = 'INSERT') THEN

    IF NEW.ticket IS NULL THEN
      NEW.ticket := gen_random_uuid();
    END IF;

    IF NEW.validFromDate IS NULL THEN
      NEW.validFromDate := Now();
    END IF;

    IF NEW.validToDate IS NULL THEN
      NEW.validToDate := NEW.validFromDate + INTERVAL '1 hour';
    END IF;

  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = db, kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_recovery_ticket_before
  BEFORE INSERT OR UPDATE ON db.recovery_ticket
  FOR EACH ROW EXECUTE PROCEDURE db.ft_recovery_ticket_before();

--------------------------------------------------------------------------------
-- db.member_area --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.member_area (
    id			numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    area		numeric(12) NOT NULL,
    member		numeric(12) NOT NULL,
    CONSTRAINT fk_md_area FOREIGN KEY (area) REFERENCES db.area(id),
    CONSTRAINT fk_md_member FOREIGN KEY (member) REFERENCES db.user(id)
);

COMMENT ON TABLE db.member_area IS 'Участники зоны.';

COMMENT ON COLUMN db.member_area.id IS 'Идентификатор';
COMMENT ON COLUMN db.member_area.area IS 'Подразделение';
COMMENT ON COLUMN db.member_area.member IS 'Участник';

CREATE INDEX ON db.member_area (area);
CREATE INDEX ON db.member_area (member);

CREATE UNIQUE INDEX ON db.member_area (area, member);

--------------------------------------------------------------------------------
-- db.member_interface ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.member_interface (
    id          numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    interface   numeric(12) NOT NULL,
    member      numeric(12) NOT NULL,
    CONSTRAINT fk_mi_interface FOREIGN KEY (interface) REFERENCES db.interface(id),
    CONSTRAINT fk_mi_member FOREIGN KEY (member) REFERENCES db.user(id)
);

COMMENT ON TABLE db.member_interface IS 'Участники интерфеса.';

COMMENT ON COLUMN db.member_interface.id IS 'Идентификатор';
COMMENT ON COLUMN db.member_interface.interface IS 'Интерфейс';
COMMENT ON COLUMN db.member_interface.member IS 'Участник';

CREATE INDEX ON db.member_interface (interface);
CREATE INDEX ON db.member_interface (member);

CREATE UNIQUE INDEX ON db.member_interface (interface, member);

--------------------------------------------------------------------------------
-- db.auth ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.auth (
    id          numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    userId      numeric(12) NOT NULL,
    audience    numeric(12) NOT NULL,
    code        text NOT NULL,
    created     timestamp DEFAULT Now() NOT NULL,
    CONSTRAINT fk_auth_userid FOREIGN KEY (userid) REFERENCES db.user(id),
    CONSTRAINT fk_auth_audience FOREIGN KEY (audience) REFERENCES oauth2.audience(id)
);

COMMENT ON TABLE db.auth IS 'Авторизаия пользователей из внешних систем.';

COMMENT ON COLUMN db.auth.id IS 'Идентификатор';
COMMENT ON COLUMN db.auth.userId IS 'Пользователь';
COMMENT ON COLUMN db.auth.audience IS 'Аудитория';
COMMENT ON COLUMN db.auth.code IS 'Идентификатор внешнего пользователя';
COMMENT ON COLUMN db.auth.created IS 'Дата создания';

CREATE UNIQUE INDEX ON db.auth (audience, code);

CREATE INDEX ON db.auth (userId);
CREATE INDEX ON db.auth (audience);
CREATE INDEX ON db.auth (code);

--------------------------------------------------------------------------------
-- TABLE db.iptable ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.iptable (
    id			numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    type		char DEFAULT 'A' NOT NULL,
    userid		numeric(12) NOT NULL,
    addr		inet NOT NULL,
    range		int,
    CONSTRAINT ch_ip_table_type CHECK (type IN ('A', 'D')),
    CONSTRAINT ch_ip_table_range CHECK (range BETWEEN 1 AND 255),
    CONSTRAINT fk_ip_table_userid FOREIGN KEY (userid) REFERENCES db.user(id)
);

COMMENT ON TABLE db.iptable IS 'Таблица IP адресов.';

COMMENT ON COLUMN db.iptable.id IS 'Идентификатор';
COMMENT ON COLUMN db.iptable.type IS 'Тип: A - allow; D - denied';
COMMENT ON COLUMN db.iptable.userid IS 'Пользователь';
COMMENT ON COLUMN db.iptable.addr IS 'IP-адрес';
COMMENT ON COLUMN db.iptable.range IS 'Диапазон. Количество адресов.';

CREATE INDEX idx_ip_table_type ON db.iptable (type);
CREATE INDEX idx_ip_table_userid ON db.iptable (userid);

--------------------------------------------------------------------------------
-- db.oauth2 -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.oauth2 (
    id              bigserial PRIMARY KEY,
    audience        numeric(12) NOT NULL,
    scopes          text[] NOT NULL,
    access_type     text NOT NULL DEFAULT 'online',
    redirect_uri    text,
    state           text,
    CONSTRAINT ch_oauth2_access_type CHECK (access_type IN ('online', 'offline')),
    CONSTRAINT fk_oauth2_audience FOREIGN KEY (audience) REFERENCES oauth2.audience(id)
);

COMMENT ON TABLE db.oauth2 IS 'Параметры арторизации через OAuth 2.0.';

COMMENT ON COLUMN db.oauth2.id IS 'Идентификатор';
COMMENT ON COLUMN db.oauth2.audience IS 'Идентификатор клиента OAuth 2.0 (audience)';
COMMENT ON COLUMN db.oauth2.scopes IS 'Список областей';
COMMENT ON COLUMN db.oauth2.access_type IS 'Тип доступа: online, offline';
COMMENT ON COLUMN db.oauth2.redirect_uri IS 'URL перенаправления';
COMMENT ON COLUMN db.oauth2.state IS 'Строковое значение пользователя';

CREATE INDEX ON db.oauth2 (audience);

--------------------------------------------------------------------------------
-- db.token_header -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.token_header (
    id              numeric PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_TOKEN'),
    oauth2          bigint NOT NULL,
    session         varchar(40) NOT NULL,
    salt            text NOT NULL,
    agent           text NOT NULL,
    host            inet,
    created         timestamptz NOT NULL DEFAULT Now(),
    updated         timestamptz NOT NULL DEFAULT Now(),
    CONSTRAINT fk_token_header_oauth2 FOREIGN KEY (oauth2) REFERENCES db.oauth2(id)
);

COMMENT ON TABLE db.token_header IS 'Заголовок маркера.';

COMMENT ON COLUMN db.token_header.id IS 'Идентификатор';
COMMENT ON COLUMN db.token_header.oauth2 IS 'Параметры авторизации через OAuth 2.0';
COMMENT ON COLUMN db.token_header.session IS 'Сессия';
COMMENT ON COLUMN db.token_header.salt IS 'Случайное значение соли для ключа';
COMMENT ON COLUMN db.token_header.agent IS 'Клиентское приложение';
COMMENT ON COLUMN db.token_header.host IS 'IP адрес подключения';
COMMENT ON COLUMN db.token_header.created IS 'Создан';
COMMENT ON COLUMN db.token_header.updated IS 'Обновлён';

CREATE INDEX ON db.token_header (oauth2);
CREATE INDEX ON db.token_header (session);

--------------------------------------------------------------------------------
-- FUNCTION ft_token_header_before_delete --------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_token_header_before_delete()
RETURNS TRIGGER
AS $$
BEGIN
  DELETE FROM db.token WHERE header = OLD.id;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = db, kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_token_header_before_delete
  BEFORE DELETE ON db.token_header
  FOR EACH ROW EXECUTE PROCEDURE db.ft_token_header_before_delete();

--------------------------------------------------------------------------------
-- db.token --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.token (
    id              numeric PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_TOKEN'),
    header          numeric NOT NULL,
    type            char NOT NULL,
    token           text NOT NULL,
    hash            varchar(40) NOT NULL,
    used            boolean NOT NULL DEFAULT false,
    validFromDate   timestamptz DEFAULT Now() NOT NULL,
    validToDate     timestamptz DEFAULT TO_DATE('4433-12-31', 'YYYY-MM-DD') NOT NULL,
    CONSTRAINT ch_token_type CHECK (type IN ('C', 'A', 'R', 'I')),
    CONSTRAINT fk_token_header FOREIGN KEY (header) REFERENCES db.token_header(id)
);

COMMENT ON TABLE db.token IS 'Токены.';

COMMENT ON COLUMN db.token.id IS 'Идентификатор';
COMMENT ON COLUMN db.token.header IS 'Заголовок';
COMMENT ON COLUMN db.token.type IS 'Тип: [С]ode - Код авторизации; [A]ccess - Маркер доступа; [R]efresh - Маркер обновления; [I]d - Маркер пользователя;';
COMMENT ON COLUMN db.token.token IS 'Маркер';
COMMENT ON COLUMN db.token.hash IS 'Хеш маркера';
COMMENT ON COLUMN db.token.used IS 'Использован';
COMMENT ON COLUMN db.token.validFromDate IS 'Дата начала действаия';
COMMENT ON COLUMN db.token.validToDate IS 'Дата окончания действия';

CREATE UNIQUE INDEX ON db.token (hash, validFromDate, validToDate);
CREATE UNIQUE INDEX ON db.token (header, type, validFromDate, validToDate);

CREATE INDEX ON db.token (header);
CREATE INDEX ON db.token (type);
CREATE INDEX ON db.token (used);

--------------------------------------------------------------------------------
-- FUNCTION ft_token_before ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_token_before()
RETURNS TRIGGER
AS $$
DECLARE
  delta   interval;
BEGIN
  IF (TG_OP = 'DELETE') THEN
    RETURN OLD;
  ELSIF (TG_OP = 'UPDATE') THEN
    IF OLD.header <> NEW.header THEN
      RAISE DEBUG 'Hacking alert: header (% <> %).', OLD.header, NEW.header;
      RETURN NULL;
    END IF;

    IF OLD.type <> NEW.type THEN
      RAISE DEBUG 'Hacking alert: type (% <> %).', OLD.type, NEW.type;
      RETURN NULL;
    END IF;

    NEW.hash := GetTokenHash(NEW.token, GetSecretKey());

    RETURN NEW;
  ELSIF (TG_OP = 'INSERT') THEN
    IF NEW.hash IS NULL THEN
      NEW.hash := GetTokenHash(NEW.token, GetSecretKey());
    END IF;

    IF NEW.validFromDate IS NULL THEN
      NEW.validFromDate := Now();
    END IF;

    IF NEW.validToDate IS NULL THEN
      IF NEW.type = 'R' THEN
        delta := INTERVAL '60 day';
      ELSIF NEW.type = 'A' THEN
        delta := INTERVAL '60 min';
      ELSIF NEW.type = 'I' THEN
        delta := INTERVAL '60 min';
      ELSE
        delta := INTERVAL '10 min';
      END IF;

      NEW.validToDate := NEW.validFromDate + delta;
    END IF;

    RETURN NEW;
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = db, kernel, pg_temp;

CREATE TRIGGER t_token_before
  BEFORE INSERT OR UPDATE OR DELETE ON db.token
  FOR EACH ROW EXECUTE PROCEDURE db.ft_token_before();

--------------------------------------------------------------------------------
-- db.session ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.session (
    code        varchar(40) PRIMARY KEY NOT NULL,
    oauth2      bigint NOT NULL,
    token       numeric(12) NOT NULL,
    suid        numeric(12) NOT NULL,
    userid      numeric(12) NOT NULL,
    locale      numeric(12) NOT NULL,
    area        numeric(12) NOT NULL,
    interface   numeric(12) NOT NULL,
    oper_date   timestamp DEFAULT NULL,
    created     timestamp DEFAULT Now() NOT NULL,
    updated     timestamp DEFAULT Now() NOT NULL,
    pwkey       text NOT NULL,
    secret      text NOT NULL,
    salt        text NOT NULL,
    agent       text NOT NULL,
    host        inet,
    CONSTRAINT fk_session_oauth2 FOREIGN KEY (oauth2) REFERENCES db.oauth2(id),
    CONSTRAINT fk_session_token FOREIGN KEY (token) REFERENCES db.token(id),
    CONSTRAINT fk_session_suid FOREIGN KEY (suid) REFERENCES db.user(id),
    CONSTRAINT fk_session_userid FOREIGN KEY (userid) REFERENCES db.user(id),
    CONSTRAINT fk_session_locale FOREIGN KEY (locale) REFERENCES db.locale(id),
    CONSTRAINT fk_session_area FOREIGN KEY (area) REFERENCES db.area(id),
    CONSTRAINT fk_session_interface FOREIGN KEY (interface) REFERENCES db.interface(id)
);

COMMENT ON TABLE db.session IS 'Сессии пользователей.';

COMMENT ON COLUMN db.session.code IS 'Код сессии (хеш ключа сессии)';
COMMENT ON COLUMN db.session.oauth2 IS 'Параметры авторизации через OAuth 2.0';
COMMENT ON COLUMN db.session.token IS 'Идентификатор маркера';
COMMENT ON COLUMN db.session.suid IS 'Пользователь сессии';
COMMENT ON COLUMN db.session.userid IS 'Пользователь';
COMMENT ON COLUMN db.session.locale IS 'Язык';
COMMENT ON COLUMN db.session.area IS 'Зона';
COMMENT ON COLUMN db.session.interface IS 'Рабочие место';
COMMENT ON COLUMN db.session.oper_date IS 'Дата операционного дня';
COMMENT ON COLUMN db.session.created IS 'Дата и время создания сессии';
COMMENT ON COLUMN db.session.updated IS 'Дата и время последнего обновления сессии';
COMMENT ON COLUMN db.session.pwkey IS 'Ключ сессии';
COMMENT ON COLUMN db.session.salt IS 'Случайное значение соли для ключа аутентификации';
COMMENT ON COLUMN db.session.agent IS 'Клиентское приложение';
COMMENT ON COLUMN db.session.host IS 'IP адрес подключения';

CREATE UNIQUE INDEX ON db.session (token);
CREATE UNIQUE INDEX ON db.session (oauth2);

CREATE INDEX ON db.session (suid);
CREATE INDEX ON db.session (userid);
CREATE INDEX ON db.session (created);
CREATE INDEX ON db.session (updated);

--------------------------------------------------------------------------------
-- FUNCTION ft_session_before --------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_session_before()
RETURNS TRIGGER
AS $$
DECLARE
  vAgent    text;
BEGIN
  IF (TG_OP = 'DELETE') THEN
    DELETE FROM db.listener WHERE session = OLD.code;
    RETURN OLD;
  ELSIF (TG_OP = 'UPDATE') THEN
    IF OLD.code <> NEW.code THEN
      RAISE DEBUG 'Hacking alert: code (% <> %).', OLD.code, NEW.code;
      RETURN NULL;
    END IF;

    IF OLD.secret <> NEW.secret THEN
      RAISE DEBUG 'Hacking alert: secret (% <> %).', OLD.secret, NEW.secret;
      RETURN NULL;
    END IF;

    IF OLD.pwkey <> NEW.pwkey THEN
      RAISE DEBUG 'Hacking alert: pwkey (% <> %).', OLD.pwkey, NEW.pwkey;
      RETURN NULL;
    END IF;

    IF OLD.suid <> NEW.suid THEN
      RAISE DEBUG 'Hacking alert: suid (% <> %).', OLD.suid, NEW.suid;
      RETURN NULL;
    END IF;

    IF OLD.created <> NEW.created THEN
      RAISE DEBUG 'Hacking alert: created (% <> %).', OLD.created, NEW.created;
      RETURN NULL;
    END IF;

    IF NEW.salt IS NULL THEN
      NEW.salt := OLD.salt;
    END IF;

    IF (NEW.updated - OLD.updated) > INTERVAL '1 hour' THEN
      NEW.salt := gen_salt('md5');
    END IF;

    IF NEW.salt <> OLD.salt THEN
      NEW.token := NewTokenCode(NEW.oauth2, NEW.code, NEW.salt, NEW.agent, NEW.host, NEW.updated);
    END IF;

    IF NEW.area <> OLD.area THEN
      IF NOT IsMemberArea(NEW.area, NEW.userid) THEN
        NEW.area := OLD.area;
      END IF;
    END IF;

    IF OLD.interface <> NEW.interface THEN
      IF NOT IsMemberInterface(NEW.interface, NEW.userid) THEN
        NEW.interface := OLD.interface;
      END IF;
    END IF;

    RETURN NEW;
  ELSIF (TG_OP = 'INSERT') THEN
    IF NEW.suid IS NULL THEN
      NEW.suid := NEW.userid;
    END IF;

    IF NEW.secret IS NULL THEN
      NEW.secret := GenSecretKey();
    END IF;

    IF NEW.agent IS NULL THEN
      SELECT application_name INTO vAgent FROM pg_stat_activity WHERE pid = pg_backend_pid();
      NEW.agent := coalesce(vAgent, current_database());
    END IF;

    NEW.salt := gen_salt('md5');

    IF NEW.pwkey IS NULL THEN
      NEW.pwkey := crypt(StrPwKey(NEW.suid, NEW.secret, NEW.created), NEW.salt);
    END IF;

    NEW.code := SessionKey(NEW.pwkey, GetSecretKey());

    IF NEW.token IS NULL THEN
      NEW.token := NewTokenCode(NEW.oauth2, NEW.code, NEW.salt, NEW.agent, NEW.host, NEW.updated);
    END IF;

    IF NEW.locale IS NULL THEN
      SELECT id INTO NEW.locale FROM db.locale WHERE code = 'ru';
    END IF;

    IF NOT IsMemberArea(NEW.area, NEW.userid) THEN
      NEW.area := GetDefaultArea(NEW.userid);
    END IF;

    IF NOT IsMemberInterface(NEW.interface, NEW.userid) THEN
      NEW.interface := GetDefaultInterface(NEW.userid);
    END IF;

    RETURN NEW;
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = db, kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_session_before
  BEFORE INSERT OR UPDATE OR DELETE ON db.session
  FOR EACH ROW EXECUTE PROCEDURE db.ft_session_before();

--------------------------------------------------------------------------------
-- FUNCTION ft_session_after ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_session_after()
RETURNS TRIGGER
AS $$
BEGIN
  IF (TG_OP = 'DELETE') THEN
    DELETE FROM db.token_header WHERE session = OLD.code;
    RETURN OLD;
  ELSIF (TG_OP = 'UPDATE') THEN
    IF OLD.userid <> NEW.userid THEN
      PERFORM SetCurrentUserId(NEW.userid);
    END IF;
    RETURN NEW;
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_session_after
  AFTER UPDATE OR DELETE ON db.session
  FOR EACH ROW EXECUTE PROCEDURE db.ft_session_after();

--------------------------------------------------------------------------------
-- SECURITY --------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.acl ----------------------------------------------------------------------
--------------------------------------------------------------------------------
/*
 Маска доступа:
   s - substitute user;
   L - unlock user;
   l - lock user;
   E - exclude user from group;
   I - include user to group;
   D - delete group;
   U - update group;
   C - create group;
   p - set user password;
   d - delete user;
   u - update user;
   c - create user;
   o - logout;
   i - login
 */
CREATE TABLE db.acl (
    userId		numeric(12) PRIMARY KEY,
    deny		bit varying NOT NULL,
    allow		bit varying NOT NULL,
    mask		bit varying NOT NULL
);

COMMENT ON TABLE db.acl IS 'Список контроля доступа.';

COMMENT ON COLUMN db.acl.userid IS 'Пользователь';
COMMENT ON COLUMN db.acl.deny IS 'Запрещающие биты';
COMMENT ON COLUMN db.acl.allow IS 'Разрешающие биты';
COMMENT ON COLUMN db.acl.mask IS 'Маска доступа: {sLlEIDUCpducoi}.';

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_acl_before()
RETURNS TRIGGER AS $$
BEGIN
  NEW.mask = NEW.allow & ~NEW.deny;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------

CREATE TRIGGER t_acl_before
  BEFORE INSERT OR UPDATE ON db.acl
  FOR EACH ROW
  EXECUTE PROCEDURE ft_acl_before();

