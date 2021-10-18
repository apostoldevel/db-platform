--------------------------------------------------------------------------------
-- db.scope --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.scope (
    id              uuid PRIMARY KEY DEFAULT gen_kernel_uuid('8'),
    code            text NOT NULL,
    name            text NOT NULL,
    description     text
);

COMMENT ON TABLE db.scope IS 'Область видимости базы данных.';

COMMENT ON COLUMN db.scope.id IS 'Идентификатор';
COMMENT ON COLUMN db.scope.code IS 'Код';
COMMENT ON COLUMN db.scope.name IS 'Наименование';
COMMENT ON COLUMN db.scope.description IS 'Описание';

CREATE UNIQUE INDEX ON db.scope (code);

--------------------------------------------------------------------------------
-- db.area_type ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.area_type (
    id        uuid PRIMARY KEY,
    code      text NOT NULL,
    name      text
);

COMMENT ON TABLE db.area_type IS 'Тип области видимости.';

COMMENT ON COLUMN db.area_type.id IS 'Идентификатор';
COMMENT ON COLUMN db.area_type.code IS 'Код';
COMMENT ON COLUMN db.area_type.name IS 'Наименование';

CREATE UNIQUE INDEX ON db.area_type (code);

--------------------------------------------------------------------------------
-- db.area ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.area (
    id              uuid PRIMARY KEY DEFAULT gen_kernel_uuid('8'),
    parent          uuid DEFAULT NULL REFERENCES db.area(id),
    type            uuid NOT NULL REFERENCES db.area_type(id),
    scope           uuid NOT NULL REFERENCES db.scope(id),
    code            text NOT NULL,
    name            text NOT NULL,
    description     text,
    level           integer NOT NULL,
    sequence		integer NOT NULL,
    validFromDate   timestamp DEFAULT Now() NOT NULL,
    validToDate     timestamp DEFAULT TO_DATE('4433-12-31', 'YYYY-MM-DD') NOT NULL
);

COMMENT ON TABLE db.area IS 'Область видимости документов.';

COMMENT ON COLUMN db.area.id IS 'Идентификатор';
COMMENT ON COLUMN db.area.parent IS 'Ссылка на родительский узел';
COMMENT ON COLUMN db.area.type IS 'Тип';
COMMENT ON COLUMN db.area.scope IS 'Область видимости базы данных';
COMMENT ON COLUMN db.area.code IS 'Код';
COMMENT ON COLUMN db.area.name IS 'Наименование';
COMMENT ON COLUMN db.area.description IS 'Описание';
COMMENT ON COLUMN db.area.level IS 'Уровень вложенности.';
COMMENT ON COLUMN db.area.sequence IS 'Очерёдность';
COMMENT ON COLUMN db.area.validFromDate IS 'Дата начала действаия';
COMMENT ON COLUMN db.area.validToDate IS 'Дата окончания действия';

CREATE INDEX ON db.area (parent);
CREATE INDEX ON db.area (type);
CREATE INDEX ON db.area (scope);

CREATE UNIQUE INDEX ON db.area (scope, code);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_area_before_insert()
RETURNS	trigger AS $$
BEGIN
  IF NEW.id IS NULL THEN
	NEW.id := gen_kernel_uuid('8');
  END IF;

  IF NEW.scope IS NULL THEN
    NEW.scope := current_scope();
  END IF;

  IF NEW.id = NEW.parent THEN
    NEW.parent := GetAreaRoot(NEW.scope);
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
-- db.interface ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.interface (
    id              uuid PRIMARY KEY DEFAULT gen_kernel_uuid('8'),
    code            text NOT NULL,
    name            text NOT NULL,
    description     text
);

COMMENT ON TABLE db.interface IS 'Интерфейс.';

COMMENT ON COLUMN db.interface.id IS 'Идентификатор';
COMMENT ON COLUMN db.interface.code IS 'Код';
COMMENT ON COLUMN db.interface.name IS 'Наименование';
COMMENT ON COLUMN db.interface.description IS 'Описание';

--------------------------------------------------------------------------------
-- db.user ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.user (
    id					uuid PRIMARY KEY,
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
CREATE INDEX ON db.user (username text_pattern_ops);
CREATE INDEX ON db.user (phone text_pattern_ops);
CREATE INDEX ON db.user (email text_pattern_ops);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_user_before_insert()
RETURNS trigger AS $$
BEGIN
  IF NEW.id IS NULL THEN
    SELECT gen_kernel_uuid('a') INTO NEW.id;
  END IF;

  IF NEW.secret IS NULL THEN
    SELECT gen_random_bytes(64) INTO NEW.secret;
  END IF;

  SELECT encode(digest(encode(hmac(NEW.secret::text, GetSecretKey(), 'sha512'), 'hex'), 'sha1'), 'hex') INTO NEW.hash;

  IF NEW.phone IS NOT NULL THEN
    NEW.phone := TrimPhone(nullif(trim(NEW.phone), ''));
  END IF;

  NEW.readonly := NEW.username IN ('system', 'administrator', 'guest', 'daemon', 'apibot', 'mailbot');
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
  WHEN 'apibot' THEN
    INSERT INTO db.acl SELECT NEW.id, B'10000000000011', B'01111111111100';
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
  IF OLD.email IS DISTINCT FROM NEW.email THEN
	UPDATE db.profile SET email_verified = false WHERE userid = NEW.id;
  END IF;

  IF NEW.phone IS NOT NULL THEN
    NEW.phone := TrimPhone(NEW.phone);
  END IF;

  IF OLD.phone IS DISTINCT FROM NEW.phone THEN
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
    userId              uuid REFERENCES db.user(id) ON DELETE CASCADE,
    scope               uuid REFERENCES db.scope(id) ON DELETE RESTRICT,
    family_name         text,
    given_name          text,
    patronymic_name     text,
    input_count         integer DEFAULT 0 NOT NULL,
    input_last          timestamp DEFAULT NULL,
    input_error         integer DEFAULT 0 NOT NULL,
    input_error_last    timestamp DEFAULT NULL,
    input_error_all     integer DEFAULT 0 NOT NULL,
    lc_ip               inet,
    locale              uuid NOT NULL REFERENCES db.locale(id),
    area                uuid NOT NULL REFERENCES db.area(id),
    interface           uuid NOT NULL REFERENCES db.interface(id),
    state               bit(3) DEFAULT B'000' NOT NULL,
    session_limit       integer DEFAULT 0 NOT NULL,
    email_verified      bool DEFAULT false,
    phone_verified      bool DEFAULT false,
    picture             text,
    PRIMARY KEY (userid, scope)
);

COMMENT ON TABLE db.profile IS 'Дополнительная информация о пользователе системы.';

COMMENT ON COLUMN db.profile.userid IS 'Пользователь';
COMMENT ON COLUMN db.profile.scope IS 'Область видимости базы данных';
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

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_profile_before()
RETURNS trigger AS $$
BEGIN
  IF NEW.locale IS NULL THEN
    SELECT id INTO NEW.locale FROM db.locale WHERE code = locale_code();
  END IF;

  IF NEW.scope IS NULL THEN
    SELECT current_scope() INTO NEW.scope;
  END IF;

  SELECT id INTO NEW.area FROM db.area WHERE id = NEW.area AND scope = NEW.scope;

  IF NOT IsMemberArea(NEW.area, NEW.userid) THEN
    SELECT GetAreaGuest(NEW.scope) INTO NEW.area; -- guest
  END IF;

  IF NEW.area IS NULL THEN
    SELECT OLD.area INTO NEW.area;
  END IF;

  IF NOT IsMemberInterface(NEW.interface, NEW.userid) THEN
    SELECT '00000000-0000-4004-a000-000000000003' INTO NEW.interface; -- guest
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

  vCode		text;

  nOnLine	int;
  nLocal	int;
  nTrust	int;

  bSuccess	boolean;

  uUserId	uuid;

  vData		Variant;

  r         record;
BEGIN
  uUserId := current_userid();

  IF uUserId IS NULL THEN
    RETURN NEW;
  END IF;

  nOnLine := 0;
  nLocal := 0;
  nTrust := 0;

  NEW.state := B'000';

  FOR r IN SELECT area, host FROM db.session WHERE userid = uUserId GROUP BY area, host
  LOOP
    r.host := coalesce(NEW.lc_ip, r.host);

    IF r.host IS NOT NULL THEN

      SELECT code INTO vCode FROM db.area WHERE id = r.area;

      IF FOUND THEN

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
  WHEN (OLD.lc_ip IS DISTINCT FROM NEW.lc_ip)
  EXECUTE PROCEDURE ft_profile_login_state();

--------------------------------------------------------------------------------
-- member_group ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.member_group (
    userid		uuid NOT NULL REFERENCES db.user(id),
    member		uuid NOT NULL REFERENCES db.user(id),
    PRIMARY KEY (userid, member)
);

COMMENT ON TABLE db.member_group IS 'Членство в группах.';

COMMENT ON COLUMN db.member_group.userid IS 'Группа';
COMMENT ON COLUMN db.member_group.member IS 'Участник';

CREATE INDEX ON db.member_group (userid);
CREATE INDEX ON db.member_group (member);

--------------------------------------------------------------------------------
-- db.member_area --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.member_area (
    area		uuid NOT NULL REFERENCES db.area(id),
    member		uuid NOT NULL REFERENCES db.user(id),
    PRIMARY KEY (area, member)
);

COMMENT ON TABLE db.member_area IS 'Участники области видимости документов.';

COMMENT ON COLUMN db.member_area.area IS 'Область видимости документов';
COMMENT ON COLUMN db.member_area.member IS 'Учётная запись пользователя';

CREATE INDEX ON db.member_area (area);
CREATE INDEX ON db.member_area (member);

--------------------------------------------------------------------------------
-- db.member_interface ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.member_interface (
    interface   uuid NOT NULL REFERENCES db.interface(id),
    member      uuid NOT NULL REFERENCES db.user(id),
    PRIMARY KEY (interface, member)
);

COMMENT ON TABLE db.member_interface IS 'Участники интерфеса.';

COMMENT ON COLUMN db.member_interface.interface IS 'Интерфейс';
COMMENT ON COLUMN db.member_interface.member IS 'Участник';

CREATE INDEX ON db.member_interface (interface);
CREATE INDEX ON db.member_interface (member);

--------------------------------------------------------------------------------
-- RECOVERY TICKET -------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.recovery_ticket ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.recovery_ticket (
    ticket			uuid PRIMARY KEY,
    userId          uuid NOT NULL,
    securityAnswer	text NOT NULL,
    used            timestamptz,
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
-- db.auth ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.auth (
    userId      uuid NOT NULL REFERENCES db.user(id) ON DELETE CASCADE,
    audience    integer NOT NULL REFERENCES oauth2.audience(id) ON DELETE CASCADE,
    code        text NOT NULL,
    created     timestamp DEFAULT Now() NOT NULL,
    PRIMARY KEY (userId, audience)
);

COMMENT ON TABLE db.auth IS 'Авторизаия пользователей из внешних систем.';

COMMENT ON COLUMN db.auth.userId IS 'Пользователь';
COMMENT ON COLUMN db.auth.audience IS 'Аудитория';
COMMENT ON COLUMN db.auth.code IS 'Идентификатор внешнего пользователя';
COMMENT ON COLUMN db.auth.created IS 'Дата создания';

CREATE INDEX ON db.auth (userId);
CREATE INDEX ON db.auth (audience);
CREATE INDEX ON db.auth (code);

--------------------------------------------------------------------------------
-- TABLE db.iptable ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.iptable (
    id			serial PRIMARY KEY,
    type		char DEFAULT 'A' NOT NULL,
    userid		uuid NOT NULL REFERENCES db.user(id),
    addr		inet NOT NULL,
    range		int,
    CHECK (type IN ('A', 'D')),
    CHECK (range BETWEEN 1 AND 255)
);

COMMENT ON TABLE db.iptable IS 'Таблица IP адресов.';

COMMENT ON COLUMN db.iptable.id IS 'Идентификатор';
COMMENT ON COLUMN db.iptable.type IS 'Тип: A - allow; D - denied';
COMMENT ON COLUMN db.iptable.userid IS 'Пользователь';
COMMENT ON COLUMN db.iptable.addr IS 'IP-адрес';
COMMENT ON COLUMN db.iptable.range IS 'Диапазон. Количество адресов.';

CREATE INDEX ON db.iptable (type);
CREATE INDEX ON db.iptable (userid);

--------------------------------------------------------------------------------
-- db.oauth2 -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.oauth2 (
    id              bigserial PRIMARY KEY,
    audience        integer NOT NULL REFERENCES oauth2.audience(id),
    scopes          text[] NOT NULL,
    access_type     text NOT NULL DEFAULT 'online',
    redirect_uri    text,
    state           text,
    CHECK (access_type IN ('online', 'offline'))
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
    id              bigserial PRIMARY KEY,
    oauth2          bigint NOT NULL REFERENCES db.oauth2,
    session         varchar(40) NOT NULL,
    salt            text NOT NULL,
    agent           text NOT NULL,
    host            inet,
    created         timestamptz NOT NULL DEFAULT Now(),
    updated         timestamptz NOT NULL DEFAULT Now()
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
    id              bigserial PRIMARY KEY,
    header          bigint NOT NULL REFERENCES db.token_header(id) ON DELETE CASCADE,
    type            char NOT NULL,
    token           text NOT NULL,
    hash            varchar(40) NOT NULL,
    used            timestamptz,
    validFromDate   timestamptz DEFAULT Now() NOT NULL,
    validToDate     timestamptz DEFAULT TO_DATE('4433-12-31', 'YYYY-MM-DD') NOT NULL,
    CHECK (type IN ('C', 'A', 'R', 'I'))
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
    code        varchar(40) PRIMARY KEY,
    oauth2      bigint NOT NULL REFERENCES db.oauth2(id),
    token       bigint NOT NULL REFERENCES db.token(id),
    suid        uuid NOT NULL REFERENCES db.user(id),
    userid      uuid NOT NULL REFERENCES db.user(id),
    locale      uuid NOT NULL REFERENCES db.locale(id),
    area        uuid NOT NULL REFERENCES db.area(id),
    interface   uuid NOT NULL REFERENCES db.interface(id),
    oper_date   timestamp DEFAULT NULL,
    created     timestamp DEFAULT Now() NOT NULL,
    updated     timestamp DEFAULT Now() NOT NULL,
    pwkey       text NOT NULL,
    secret      text NOT NULL,
    salt        text NOT NULL,
    agent       text NOT NULL,
    host        inet
);

COMMENT ON TABLE db.session IS 'Сессии пользователей.';

COMMENT ON COLUMN db.session.code IS 'Код сессии (хеш ключа сессии)';
COMMENT ON COLUMN db.session.oauth2 IS 'Параметры авторизации через OAuth 2.0';
COMMENT ON COLUMN db.session.token IS 'Идентификатор маркера';
COMMENT ON COLUMN db.session.suid IS 'Пользователь сессии';
COMMENT ON COLUMN db.session.userid IS 'Пользователь';
COMMENT ON COLUMN db.session.locale IS 'Язык';
COMMENT ON COLUMN db.session.area IS 'Область видимости документов';
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

    IF NEW.salt IS DISTINCT FROM OLD.salt THEN
      NEW.token := NewTokenCode(NEW.oauth2, NEW.code, NEW.salt, NEW.agent, NEW.host, NEW.updated);
    END IF;

    IF NEW.area IS DISTINCT FROM OLD.area THEN
      IF NOT IsMemberArea(NEW.area, NEW.userid) THEN
        NEW.area := OLD.area;
      END IF;
    END IF;

    IF OLD.interface IS DISTINCT FROM NEW.interface THEN
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
      NEW.locale := GetDefaultLocale(NEW.userid);
    END IF;

    IF NEW.area IS NULL THEN
      NEW.area := GetDefaultArea(NEW.userid);
    END IF;

    IF NOT IsMemberArea(NEW.area, NEW.userid) THEN
      PERFORM AccessDenied();
    END IF;

    IF NEW.interface IS NULL THEN
      NEW.interface := GetDefaultInterface(NEW.userid);
    END IF;

    IF NOT IsMemberInterface(NEW.interface, NEW.userid) THEN
      PERFORM AccessDenied();
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
    userId		uuid REFERENCES db.user ON DELETE CASCADE,
    deny		bit varying NOT NULL,
    allow		bit varying NOT NULL,
    mask		bit varying NOT NULL,
    PRIMARY KEY (userId)
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
