--------------------------------------------------------------------------------
-- SECURITY --------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.locale -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.locale (
    id		    numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    code	    varchar(30) NOT NULL,
    name	    varchar(50) NOT NULL,
    description	text
);

COMMENT ON TABLE db.locale IS 'Локаль.';

COMMENT ON COLUMN db.locale.id IS 'Идентификатор';
COMMENT ON COLUMN db.locale.code IS 'Код';
COMMENT ON COLUMN db.locale.name IS 'Наименование';
COMMENT ON COLUMN db.locale.description IS 'Описание';

CREATE UNIQUE INDEX ON db.locale(code);

INSERT INTO db.locale (code, name, description) VALUES ('ru', 'Русский', 'Русский язык');
INSERT INTO db.locale (code, name, description) VALUES ('en', 'English', 'English');

--------------------------------------------------------------------------------
-- FUNCTION GetLocale ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetLocale (
  pCode		varchar
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM db.locale WHERE code = pCode;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetLocaleCode ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetLocaleCode (
  pId		numeric
) RETURNS	varchar
AS $$
DECLARE
  vCode		varchar;
BEGIN
  SELECT code INTO vCode FROM db.locale WHERE id = pId;
  return vCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- Locale ----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Locale
as
  SELECT * FROM db.locale;

GRANT SELECT ON Locale TO administrator;

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

CREATE OR REPLACE FUNCTION db.ft_interface()
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

CREATE TRIGGER t_interface
  BEFORE INSERT ON db.interface
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_interface();

--------------------------------------------------------------------------------
-- Interface -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Interface
as
  SELECT * FROM db.interface;

GRANT SELECT ON Interface TO administrator;

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
-- AreaType --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW AreaType
AS
  SELECT * FROM db.area_type;

GRANT SELECT ON AreaType TO administrator;

--------------------------------------------------------------------------------
-- GetAreaType -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetAreaType (
  pCode		varchar
) RETURNS 	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT Id INTO nId FROM db.area_type WHERE Code = pCode;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

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
-- Area ------------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Area (Id, Parent, Type, TypeCode, TypeName,
  Code, Name, Description, validFromDate, validToDate
)
as
  SELECT d.id, d.parent, d.type, t.code, t.name, d.code, d.name,
         d.description, d.validFromDate, d.validToDate
    FROM db.area d INNER JOIN db.area_type t ON t.id = d.type;

GRANT SELECT ON Area TO administrator;

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
    INSERT INTO db.acl SELECT NEW.id, B'00000000000', B'10000000011';
  WHEN 'administrator' THEN
    INSERT INTO db.acl SELECT NEW.id, B'00000000000', B'01111111111';
  WHEN 'guest' THEN
    INSERT INTO db.acl SELECT NEW.id, B'11111111100', B'00000000011';
  ELSE
    INSERT INTO db.acl SELECT NEW.id, B'00000000000', B'00000000011';
  END CASE;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

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
COMMENT ON COLUMN db.profile.phone_verified IS 'Телефон адрес подтверждён.';
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
-- users -----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW users
AS
  SELECT u.id, u.username, u.name, p.given_name, p.family_name, p.patronymic_name,
         u.email, p.email_verified, u.phone, p.phone_verified, p.session_limit,
         u.created, l.code AS locale, a.code AS area, i.sid AS interface,
         u.description, p.picture, u.passwordchange, u.passwordnotchange,
         r.rolname IS NOT NULL AS system,
         readonly,
         status::int,
         CASE
         WHEN u.status & B'1100' = B'1100' THEN 'expired & locked'
         WHEN u.status & B'1000' = B'1000' THEN 'expired'
         WHEN u.status & B'0100' = B'0100' THEN 'locked'
         WHEN u.status & B'0010' = B'0010' THEN 'active'
         WHEN u.status & B'0001' = B'0001' THEN 'open'
         ELSE 'undefined'
         END AS statustext,
         state::int,
         CASE
         WHEN p.state & B'111' = B'111' THEN 'online (all)'
         WHEN p.state & B'110' = B'110' THEN 'online (local & trusted)'
         WHEN p.state & B'101' = B'101' THEN 'online (external & trusted)'
         WHEN p.state & B'011' = B'011' THEN 'online (external & local)'
         WHEN p.state & B'100' = B'100' THEN 'online (trusted)'
         WHEN p.state & B'010' = B'010' THEN 'online (local)'
         WHEN p.state & B'001' = B'001' THEN 'online (external)'
         ELSE 'offline'
         END AS statetext,
         u.lock_date, u.expiry_date, p.lc_ip,
         p.input_count, p.input_last, p.input_error, p.input_error_last, p.input_error_all
    FROM db.user u INNER JOIN db.profile p      ON p.userid = u.id
                    LEFT JOIN db.locale l       ON l.id = p.locale
                    LEFT JOIN db.area a         ON a.id = p.area
                    LEFT JOIN db.interface i    ON i.id = p.interface
                    LEFT JOIN pg_roles r        ON r.rolname = lower(u.username)
   WHERE u.type = 'U';

GRANT SELECT ON users TO administrator;

--------------------------------------------------------------------------------
-- groups ----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW groups (Id, UserName, Name, Description, System)
AS
  SELECT u.id, u.username, u.name, u.description, r.rolname IS NOT NULL
    FROM db.user u LEFT JOIN pg_roles r ON r.rolname = lower(u.username)
   WHERE u.type = 'G';

GRANT SELECT ON groups TO administrator;

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
-- MemberGroup -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW MemberGroup (Id, UserId, UserType, UserName, UserFullName, UserDesc,
  MemberId, MemberType, MemberName, MemberFullName, MemberDesc
)
AS
  SELECT mg.id, mg.userid,
         CASE g.type
         WHEN 'G' THEN 'group'
         WHEN 'U' THEN 'user'
         END, g.username, g.name, g.description,
         mg.member,
         CASE u.type
         WHEN 'G' THEN 'group'
         WHEN 'U' THEN 'user'
         END, u.username, u.name, u.description
    FROM db.member_group mg INNER JOIN db.user g ON g.id = mg.userid
                            INNER JOIN db.user u ON u.id = mg.member;

GRANT SELECT ON MemberGroup TO administrator;

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
-- MemberArea ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW MemberArea (Id, Area, Code, Name, Description,
  MemberId, MemberType, MemberName, MemberFullName, MemberDesc
)
AS
  SELECT md.id, md.area, d.code, d.name, d.description,
         md.member, u.type, u.username, u.name, u.description
    FROM db.member_area md INNER JOIN db.area d ON d.id = md.area
                           INNER JOIN db.user u ON u.id = md.member;

GRANT SELECT ON MemberArea TO administrator;

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
-- MemberInterface -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW MemberInterface (Id, Interface, SID, InterfaceName, InterfaceDesc,
  MemberId, MemberType, MemberName, MemberFullName, MemberDesc
)
AS
  SELECT mwp.id, mwp.interface, wp.sid, wp.name, wp.description,
         mwp.member, u.type, u.username, u.name, u.description
    FROM db.member_interface mwp INNER JOIN db.interface wp ON wp.id = mwp.interface
                                 INNER JOIN db.user u ON u.id = mwp.member;

GRANT SELECT ON MemberInterface TO administrator;

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
-- VIEW Auth -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Auth
AS
  SELECT * FROM db.auth;

GRANT SELECT ON Auth TO administrator;

--------------------------------------------------------------------------------
-- CreateAuth ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateAuth (
  pUserId       numeric,
  pAudience     numeric,
  pCode		    varchar
) RETURNS 	    numeric
AS $$
DECLARE
  nId		    numeric;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(GetGroup('administrator')) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  INSERT INTO db.auth (userId, audience, code) VALUES (pUserId, pAudience, pCode)
  RETURNING Id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetAuth ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetAuth (
  pCode		varchar
) RETURNS 	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM db.auth WHERE code = pCode;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

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
-- VIEW iptable ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW iptable (Id, Type, UserId, Addr, Range)
AS
  SELECT id, type, userid, addr, range
    FROM db.iptable;

GRANT SELECT ON iptable TO administrator;

--------------------------------------------------------------------------------
-- GetIPTableStr ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetIPTableStr (
  pUserId	numeric,
  pType		char DEFAULT 'A'
) RETURNS	text
AS $$
DECLARE
  r             record;
  ip		integer[4];
  vHost		text;
  aResult	text[];
BEGIN
  FOR r IN SELECT * FROM db.iptable WHERE userid = pUserId AND type = pType
  LOOP
    IF r.range IS NOT NULL THEN
      vHost := host(r.addr) || '-' || host(r.addr + r.range - 1);
    ELSE
      CASE masklen(r.addr)
      WHEN 8 THEN
        ip := inet_to_array(r.addr);
        ip[1] := null;
        ip[2] := null;
        ip[3] := null;
        vHost := array_to_string(ip, '.', '*');
      WHEN 16 THEN
        ip := inet_to_array(r.addr);
        ip[2] := null;
        ip[3] := null;
        vHost := array_to_string(ip, '.', '*');
      WHEN 24 THEN
        ip := inet_to_array(r.addr);
        ip[3] := null;
        vHost := array_to_string(ip, '.', '*');
      WHEN 32 THEN
        vHost := host(r.addr);
      ELSE
        vHost := text(r.addr);
      END CASE;
    END IF;

    aResult := array_append(aResult, vHost);
  END LOOP;

  RETURN array_to_string(aResult, ', ');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SetIPTableStr ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetIPTableStr (
  pUserId	numeric,
  pType		char,
  pIpTable	text
) RETURNS	void
AS $$
DECLARE
  i             int;

  vStr		text;
  arrIp		text[];

  iHost		inet;
  nRange	int;
BEGIN
  pType := coalesce(pType, 'A');

  DELETE FROM db.iptable WHERE type = pType AND userid = pUserId;

  vStr := NULLIF(pIpTable, '');
  IF vStr IS NOT NULL THEN

    arrIp := string_to_array_trim(vStr, ',');

    FOR i IN 1..array_length(arrIp, 1)
    LOOP
      SELECT host, range INTO iHost, nRange FROM str_to_inet(arrIp[i]);

      INSERT INTO db.iptable (type, userid, addr, range)
      VALUES (pType, pUserId, iHost, nRange);
    END LOOP;
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CheckIPTable ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckIPTable (
  pUserId	numeric,
  pType		char,
  pHost		inet
) RETURNS	boolean
AS $$
DECLARE
  r             record;
  passed	boolean;
BEGIN
  FOR r IN SELECT * FROM db.iptable WHERE type = pType AND userid = pUserId
  LOOP
    IF r.range IS NOT NULL THEN
      passed := (pHost >= r.addr) AND (pHost <= r.addr + (r.range - 1));
    ELSE
      passed := pHost <<= r.addr;
    END IF;

    EXIT WHEN coalesce(passed, false);
  END LOOP;

  RETURN passed;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CheckIPTable ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckIPTable (
  pUserId	numeric,
  pHost		inet
) RETURNS	boolean
AS $$
DECLARE
  denied	boolean;
  allow		boolean;
BEGIN
  denied := coalesce(CheckIPTable(pUserId, 'D', pHost), false);

  IF NOT denied THEN
    allow := coalesce(CheckIPTable(pUserId, 'A', pHost), true);
  ELSE
    allow := NOT denied;
  END IF;

  IF NOT allow THEN
    PERFORM SetErrorMessage('Ограничен доступ по IP-адресу.');
  END IF;

  RETURN allow;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CheckSessionLimit -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckSessionLimit (
  pUserId	numeric
) RETURNS	void
AS $$
DECLARE
  nCount	integer;
  nLimit	integer;

  r             record;
BEGIN
  SELECT session_limit INTO nLimit FROM db.profile WHERE userid = pUserId;

  IF coalesce(nLimit, 0) > 0 THEN

    SELECT count(*) INTO nCount FROM db.session WHERE userid = pUserId;

    FOR r IN SELECT code FROM db.session WHERE userid = pUserId ORDER BY created
    LOOP
      EXIT WHEN nCount = 0;
      EXIT WHEN nCount < nLimit;

      PERFORM SessionOut(r.code, false, 'Превышен лимит.');

      nCount := nCount - 1;
    END LOOP;
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION StrPwKey -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION StrPwKey (
  pUserId       numeric,
  pSecret       text,
  pCreated      timestamp
) RETURNS       text
AS $$
DECLARE
  vHash         text;
  vStrPwKey     text DEFAULT null;
BEGIN
  SELECT hash INTO vHash FROM db.user WHERE id = pUserId;

  IF found THEN
    vStrPwKey := '{' || IntToStr(pUserId) || '-' || vHash || '-' || pSecret || '-' || current_database() || '-' || DateToStr(pCreated, 'YYYYMMDDHH24MISS') || '}';
  END IF;

  RETURN encode(digest(vStrPwKey, 'sha1'), 'hex');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION CreateAccessToken --------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateAccessToken (
  pAudience     numeric,
  pSubject      text,
  pDateFrom     timestamptz DEFAULT Now(),
  pDateTo       timestamptz DEFAULT Now() + INTERVAL '60 min'
) RETURNS       text
AS $$
DECLARE
  token         json;
  nProvider     numeric;
  vSecret       text;
  iss           text;
  aud           text;
BEGIN
  SELECT provider, code, secret INTO nProvider, aud, vSecret FROM oauth2.audience WHERE id = pAudience;
  SELECT code INTO iss FROM oauth2.issuer WHERE provider = nProvider;

  token := json_build_object('iss', iss, 'aud', aud, 'sub', pSubject, 'iat', trunc(extract(EPOCH FROM pDateFrom)), 'exp', trunc(extract(EPOCH FROM pDateTo)));

  RETURN sign(token, vSecret);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION CreateIdToken ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateIdToken (
  pAudience     numeric,
  pUserId       numeric,
  pScopes       text[],
  pDateFrom     timestamptz DEFAULT Now(),
  pDateTo       timestamptz DEFAULT Now() + INTERVAL '60 min'
) RETURNS       text
AS $$
DECLARE
  p             record;

  nProvider     numeric;

  vSecret       text;

  iss           text;
  aud           text;

  payload       jsonb;
BEGIN
  SELECT provider, code, secret INTO nProvider, aud, vSecret FROM oauth2.audience WHERE id = pAudience;
  SELECT code INTO iss FROM oauth2.issuer WHERE provider = nProvider;

  SELECT id, username, name, given_name, family_name, patronymic_name,
         email, email_verified, phone, phone_verified, session_limit,
         created, locale, area, interface, description, picture
    INTO p
    FROM users WHERE id = pUserId;

  IF NOT FOUND THEN
    PERFORM UserNotFound(pUserId);
  END IF;

  payload := jsonb_build_object('iss', iss, 'aud', aud, 'sub', p.username, 'uid', p.id, 'iat', trunc(extract(EPOCH FROM pDateFrom)), 'exp', trunc(extract(EPOCH FROM pDateTo)));

  IF pScopes && ARRAY['profile'] THEN
    payload := payload || row_to_json(p)::jsonb;
  END IF;

  RETURN sign(payload::json, vSecret);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION CreateIdToken ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateIdToken (
  pAudience     numeric,
  pSession      text,
  pScopes       text[],
  pDateFrom     timestamptz DEFAULT Now(),
  pDateTo       timestamptz DEFAULT Now() + INTERVAL '1 hour'
) RETURNS       text
AS $$
DECLARE
  nUserId       numeric;
BEGIN
  SELECT userId INTO nUserId FROM db.session WHERE code = pSession;
  RETURN CreateIdToken(pAudience, nUserId, pScopes, pDateFrom, pDateTo);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
--------------------------------------------------------------------------------
-- FUNCTION SessionKey ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SessionKey (
  pPwKey        text,
  pPassKey      text
) RETURNS       text
AS $$
DECLARE
  vSession      text DEFAULT null;
BEGIN
  IF pPwKey IS NOT NULL THEN
    vSession := encode(hmac(pPwKey, pPassKey, 'sha1'), 'hex');
  END IF;

  RETURN vSession;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetTokenHash -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetTokenHash (
  pToken        text,
  pPassKey      text
) RETURNS       text
AS $$
BEGIN
  RETURN encode(hmac(pToken, pPassKey, 'sha1'), 'hex');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GenSecretKey -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GenSecretKey (
  pSize         integer DEFAULT 48
)
RETURNS         text
AS $$
BEGIN
  RETURN encode(gen_random_bytes(pSize), 'base64');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GenTokenKey --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GenTokenKey (
  pPassKey      text
) RETURNS       text
AS $$
BEGIN
  RETURN encode(hmac(GenSecretKey(), pPassKey, 'sha256'), 'hex');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetSignature ----------------------------------------------------------------
--------------------------------------------------------------------------------
/*
 * @param {text} pPath - Путь
 * @param {double precision} pNonce - Время в миллисекундах
 * @param {json} pJson - Данные
 * @param {text} pSecret - Секретный ключ
 * @return {text}
 */
CREATE OR REPLACE FUNCTION GetSignature (
  pPath	        text,
  pNonce        double precision,
  pJson         json,
  pSecret       text
) RETURNS	    text
AS $$
BEGIN
  RETURN encode(hmac(pPath || trim(to_char(pNonce, '9999999999999999')) || coalesce(pJson, 'null'), pSecret, 'sha256'), 'hex');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

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
-- CreateOAuth2 ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateOAuth2 (
  pAudience     numeric,
  pScopes       text[],
  pAccessType   text DEFAULT null,
  pRedirectURI  text DEFAULT null,
  pState        text DEFAULT null
) RETURNS       numeric
AS $$
DECLARE
  nId           numeric;
BEGIN
  pAccessType := coalesce(pAccessType, 'online');

  INSERT INTO db.oauth2 (audience, scopes, access_type, redirect_uri, state)
  VALUES (pAudience, pScopes, pAccessType, pRedirectURI, pState)
  RETURNING id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateSystemOAuth2 ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateSystemOAuth2 (
) RETURNS       numeric
AS $$
BEGIN
  RETURN CreateOAuth2(GetAudience(oauth2_system_client_id()), ARRAY['api']);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

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
-- Tokens ----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Tokens
AS
  SELECT h.id, h.created, h.updated, t.id as tokenId,
         CASE
         WHEN type = 'C' THEN 'authorization_code'
         WHEN type = 'A' THEN 'access_token'
         WHEN type = 'R' THEN 'refresh_token'
         WHEN type = 'I' THEN 'id_token'
         END AS grant_type,
         t.token, t.used, t.hash, h.session, h.agent, h.host, t.validFromDate, t.validToDate
    FROM db.token_header h INNER JOIN db.token t ON h.id = t.header;

GRANT SELECT ON Tokens TO administrator;

--------------------------------------------------------------------------------
-- CreateTokenHeader -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateTokenHeader (
  pOAuth2       numeric,
  pSession      text,
  pSalt         text,
  pAgent        text,
  pHost         inet
) RETURNS       numeric
AS $$
DECLARE
  nId           numeric;
BEGIN
  INSERT INTO db.token_header (oauth2, session, salt, agent, host)
  VALUES (pOAuth2, pSession, pSalt, pAgent, pHost)
  RETURNING id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AddToken --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddToken (
  pHeader       numeric,
  pType         char,
  pToken        text,
  pDateFrom     timestamptz,
  pDateTo       timestamptz DEFAULT null
) RETURNS       numeric
AS $$
DECLARE
  nId           numeric;
  dtDateFrom 	timestamp;
  dtDateTo      timestamp;
BEGIN
  -- получим дату значения в текущем диапозоне дат
  SELECT id, validFromDate, validToDate INTO nId, dtDateFrom, dtDateTo
    FROM db.token
   WHERE header = pHeader
     AND type = pType
     AND validFromDate <= pDateFrom
     AND validToDate > pDateFrom;

  IF coalesce(dtDateFrom, MINDATE()) = pDateFrom THEN
    -- обновим значение в текущем диапозоне дат
    UPDATE db.token SET token = pToken
     WHERE header = pHeader
       AND type = pType
       AND validFromDate <= pDateFrom
       AND validToDate > pDateFrom;
  ELSE
    -- обновим дату значения в текущем диапозоне дат
    UPDATE db.token SET validToDate = pDateFrom
     WHERE header = pHeader
       AND type = pType
       AND validFromDate <= pDateFrom
       AND validToDate > pDateFrom;

    INSERT INTO db.token (header, type, token, validFromDate, validtodate)
    VALUES (pHeader, pType, pToken, pDateFrom, pDateTo)
    RETURNING id INTO nId;
  END IF;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ScopeToArray ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ScopeToArray (
  pScope        text
) RETURNS       text[]
AS $$
DECLARE
  scopes        text[];
  arValid       text[];
  arInvalid     text[];
  arScopes      text[];
BEGIN
  IF NULLIF(pScope, '') IS NOT NULL THEN
    arScopes := array_cat(arScopes, ARRAY['api', 'openid', 'profile', 'email']);

    scopes := string_to_array(pScope, ' ');

    FOR i IN 1..array_length(scopes, 1)
    LOOP
      IF array_position(arScopes, scopes[i]) IS NULL THEN
        arInvalid := array_append(arInvalid, scopes[i]);
      ELSE
        arValid := array_append(arValid, scopes[i]);
      END IF;
    END LOOP;

    IF arInvalid IS NOT NULL THEN

      IF arValid IS NULL THEN
        arValid := array_append(arValid, '');
      END IF;

      PERFORM InvalidScope(arValid, arInvalid);
    END IF;

  ELSE
    arValid := array_append(arValid, 'api');
  END IF;

  RETURN arValid;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- NewTokenCode ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION NewTokenCode (
  pOAuth2       numeric,
  pSession      text,
  pSalt         text,
  pAgent        text,
  pHost         inet,
  pCreated      timestamptz
) RETURNS       numeric
AS $$
DECLARE
  nHeader       numeric;
BEGIN
  nHeader := CreateTokenHeader(pOAuth2, pSession, pSalt, pAgent, pHost);
  RETURN AddToken(nHeader, 'C', GenSecretKey(48), pCreated);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- NewToken --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION NewToken (
  pAudience     numeric,
  pHeader       numeric,
  pDateFrom     timestamptz DEFAULT Now(),
  pDateTo       timestamptz DEFAULT Now() + INTERVAL '1 hour'
) RETURNS       jsonb
AS $$
DECLARE
  nOauth2       numeric;

  access_token  text;
  refresh_token text;
  id_token      text;

  expires_in    double precision;

  arScopes      text[];

  vSession      text;

  vAccessType   text;
  vState        text;

  Token         jsonb;
BEGIN
  SELECT oauth2, session INTO nOauth2, vSession
    FROM db.token_header WHERE id = pHeader;

  SELECT access_type, scopes, state INTO vAccessType, arScopes, vState
    FROM db.oauth2 WHERE id = nOauth2;

  IF NOT FOUND THEN
    RETURN json_build_object('error', json_build_object('code', 400, 'error', 'invalid_request', 'message', 'The OAuth 2.0 params was not found.'));
  END IF;

  expires_in := trunc(extract(EPOCH FROM pDateTo)) - trunc(extract(EPOCH FROM pDateFrom));

  access_token := CreateAccessToken(pAudience, vSession, pDateFrom, pDateTo);
  PERFORM AddToken(pHeader, 'A', access_token, pDateFrom, pDateTo);

  Token := jsonb_build_object('session', vSession, 'secret', session_secret(vSession), 'access_token', access_token, 'token_type', 'Bearer', 'expires_in', expires_in, 'scope', array_to_string(arScopes, ' '));

  IF vState IS NOT NULL THEN
    Token := Token || jsonb_build_object('state', vState);
  END IF;

  IF vAccessType = 'offline' THEN
    refresh_token := GenSecretKey(54);
    PERFORM AddToken(pHeader, 'R', refresh_token, pDateFrom, MAXDATE());
    Token := Token || jsonb_build_object('refresh_token', refresh_token);
  END IF;

  IF arScopes && ARRAY['openid', 'profile'] THEN
    id_token := CreateIdToken(pAudience, vSession, arScopes, pDateFrom, pDateTo);
    PERFORM AddToken(pHeader, 'I', id_token, pDateFrom, pDateTo);
    Token := Token || jsonb_build_object('id_token', id_token);
  END IF;

  UPDATE db.token_header SET updated = Now() WHERE id = pHeader;

  RETURN Token;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ExchangeToken ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ExchangeToken (
  pAudience     numeric,
  pToken        text,
  pInterval     interval DEFAULT '1 hour',
  pType         char DEFAULT 'A'
) RETURNS       json
AS $$
DECLARE
  nHeader       numeric;
  nToken        numeric;
  vType         text;
BEGIN
  SELECT h.id, t.id INTO nHeader, nToken
    FROM db.token_header h INNER JOIN db.token t ON h.id = t.header AND t.type = pType AND NOT (pType = 'C' AND t.used)
   WHERE t.hash = GetTokenHash(pToken, GetSecretKey())
     AND t.validFromDate <= Now()
     AND t.validtoDate > Now();

  IF NOT FOUND THEN

    CASE pType
    WHEN 'C' THEN
      vType := 'authorization code.';
    WHEN 'A' THEN
      vType := 'access token.';
    WHEN 'R' THEN
      vType := 'refresh token.';
    WHEN 'I' THEN
      vType := 'id token.';
    END CASE;

    RETURN json_build_object('error', json_build_object('code', 400, 'error', 'invalid_grant', 'message', 'Malformed ' || vType));
  END IF;

  IF pType = 'C' THEN
    UPDATE db.token SET used = true WHERE id = nToken;
  END IF;

  RETURN NewToken(pAudience, nHeader, Now(), Now() + pInterval);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateToken -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateToken (
  pAudience     numeric,
  pCode         text,
  pInterval     interval DEFAULT '1 hour'
) RETURNS       jsonb
AS $$
BEGIN
  RETURN ExchangeToken(pAudience, pCode, pInterval, 'C');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- UpdateToken -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION UpdateToken (
  pAudience     numeric,
  pRefresh      text,
  pInterval     interval DEFAULT '1 hour'
) RETURNS       json
AS $$
BEGIN
  RETURN ExchangeToken(pAudience, pRefresh, pInterval, 'R');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetToken --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetToken (
  pId       numeric
) RETURNS   text
AS $$
DECLARE
  vToken    text;
BEGIN
  SELECT token INTO vToken FROM db.token WHERE id = pId;
  RETURN vToken;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

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

CREATE TRIGGER t_session_after
  AFTER UPDATE OR DELETE ON db.session
  FOR EACH ROW EXECUTE PROCEDURE db.ft_session_after();

--------------------------------------------------------------------------------
-- session ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW session
AS
  SELECT s.code, s.token, s.userid, s.suid, u.username, u.name,
         s.agent, s.host, s.area, s.interface, s.created, s.updated,
         u.input_last, u.lc_ip, u.status, u.state
    FROM db.session s INNER JOIN users u ON s.userid = u.id;

GRANT SELECT ON session TO administrator;

--------------------------------------------------------------------------------
-- FUNCTION SafeSetVar ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SafeSetVar (
  pName		text,
  pValue	text
) RETURNS	void
AS $$
BEGIN
  PERFORM set_config('current.' || pName, pValue, false);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SafeGetVar ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SafeGetVar (
  pName 	text
) RETURNS   text
AS $$
BEGIN
  RETURN NULLIF(current_setting('current.' || pName), '');
EXCEPTION
WHEN syntax_error_or_access_rule_violation THEN
  RETURN null;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetSecretKey -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetSecretKey (
  pName         text DEFAULT 'default'
) RETURNS       text
AS $$
DECLARE
  vDefaultKey	text DEFAULT 'MYXIWngoebYUkOPlGYdXuy6n';
  vSecretKey	text DEFAULT SafeGetVar(pName);
BEGIN
  RETURN coalesce(vSecretKey, vDefaultKey);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION oauth2_system_client_id --------------------------------------------
--------------------------------------------------------------------------------
/**
 * Системный клиент OAuth 2.0.
 * @return {text} - OAuth 2.0 Client Id
 */
CREATE OR REPLACE FUNCTION oauth2_system_client_id()
RETURNS		text
AS $$
BEGIN
  RETURN current_database();
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION oauth2_current_client_id -------------------------------------------
--------------------------------------------------------------------------------
/**
 * Текущий клиент OAuth 2.0.
 * @return {text} - OAuth 2.0 Client Id
 */
CREATE OR REPLACE FUNCTION oauth2_current_client_id()
RETURNS		text
AS $$
BEGIN
  RETURN SafeGetVar('client_id');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetDebugMode -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetDebugMode (
  pValue	boolean
) RETURNS	void
AS $$
BEGIN
  PERFORM SafeSetVar('debug', pValue::text);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetDebugMode -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetDebugMode()
RETURNS		boolean
AS $$
BEGIN
  RETURN coalesce(SafeGetVar('debug')::boolean, false);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetCurrentSession --------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetCurrentSession (
  pValue	text
) RETURNS	void
AS $$
BEGIN
  PERFORM SafeSetVar('session', pValue);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetCurrentSession --------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetCurrentSession()
RETURNS		text
AS $$
BEGIN
  RETURN SafeGetVar('session');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetCurrentUserId ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetCurrentUserId (
  pValue	numeric
) RETURNS	void
AS $$
BEGIN
  PERFORM SafeSetVar('user', trim(to_char(pValue, '999999990000')));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetCurrentUserId ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetCurrentUserId()
RETURNS		numeric
AS $$
BEGIN
  RETURN to_number(SafeGetVar('user'), '999999990000');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION current_session ----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает ключ текущей сессии.
 * @return {text} - Код сессии
 */
CREATE OR REPLACE FUNCTION current_session()
RETURNS		text
AS $$
DECLARE
  vCode		text;
  vSession	text;
BEGIN
  vCode := GetCurrentSession();
  IF vCode IS NOT NULL THEN
    SELECT code INTO vSession FROM db.session WHERE code = vCode;
    IF found THEN
      RETURN vSession;
    END IF;
  END IF;
  RETURN null;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION session_secret -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает секретный ключ сессии (тсс... никому не говорить 😉 !!!).
 * @param {text} pSession - Код сессии
 * @return {text}
 */
CREATE OR REPLACE FUNCTION session_secret (
  pSession	text DEFAULT current_session()
)
RETURNS		text
AS $$
DECLARE
  vSecret	text;
BEGIN
  IF pSession IS NOT NULL THEN
    SELECT secret INTO vSecret FROM db.session WHERE code = pSession;
  END IF;
  RETURN vSecret;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION session_area -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает зону сессии.
 * @param {text} pSession - Код сессии
 * @return {text}
 */
CREATE OR REPLACE FUNCTION session_area (
  pSession	text DEFAULT current_session()
)
RETURNS		text
AS $$
DECLARE
  vArea     text;
BEGIN
  IF pSession IS NOT NULL THEN
    SELECT area INTO vArea FROM db.session WHERE code = pSession;
  END IF;
  RETURN vArea;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION session_agent ------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает агента сессии.
 * @param {text} pSession - Код сессии
 * @return {text}
 */
CREATE OR REPLACE FUNCTION session_agent (
  pSession	text DEFAULT current_session()
)
RETURNS		text
AS $$
DECLARE
  vAgent	text;
BEGIN
  IF pSession IS NOT NULL THEN
    SELECT agent INTO vAgent FROM db.session WHERE code = pSession;
  END IF;
  RETURN vAgent;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION session_host -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает IP адрес подключения.
 * @param {text} pSession - Код сессии
 * @return {text} - IP адрес
 */
CREATE OR REPLACE FUNCTION session_host (
  pSession	text DEFAULT current_session()
)
RETURNS		text
AS $$
DECLARE
  iHost		inet;
BEGIN
  IF pSession IS NOT NULL THEN
    SELECT host INTO iHost FROM db.session WHERE code = pSession;
  END IF;
  RETURN host(iHost);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION session_userid -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает идентификатор пользователя сеанса.
 * @param {text} pSession - Код сессии
 * @return {id} - Идентификатор пользователя: users.id
 */
CREATE OR REPLACE FUNCTION session_userid (
  pSession	text DEFAULT current_session()
)
RETURNS		numeric
AS $$
DECLARE
  nUserId	numeric;
BEGIN
  IF pSession IS NOT NULL THEN
    SELECT suid INTO nUserId FROM db.session WHERE code = pSession;
  END IF;
  RETURN nUserId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION current_userid -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает идентификатор текущего пользователя.
 * @return {id} - Идентификатор пользователя: users.id
 */
CREATE OR REPLACE FUNCTION current_userid()
RETURNS		numeric
AS $$
DECLARE
  nUserId	numeric;
  vSession	text;
BEGIN
  nUserId := GetCurrentUserId();
  IF nUserId IS NULL THEN
    vSession := current_session();
    IF vSession IS NOT NULL THEN
      SELECT userid INTO nUserId FROM db.session WHERE code = vSession;
      PERFORM SetCurrentUserId(nUserId);
    END IF;
  END IF;
  RETURN nUserId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION session_username ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает имя пользователя сеанса.
 * @param {text} pSession - Код сессии
 * @return {text} - Имя (username) пользователя: users.username
 */
CREATE OR REPLACE FUNCTION session_username (
  pSession	text DEFAULT current_session()
)
RETURNS		text
AS $$
DECLARE
  vUserName	text;
BEGIN
  SELECT username INTO vUserName FROM users WHERE id = session_userid(pSession);
  RETURN vUserName;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION current_username ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает имя текущего пользователя.
 * @return {text} - Имя (username) пользователя: users.username
 */
CREATE OR REPLACE FUNCTION current_username()
RETURNS		text
AS $$
DECLARE
  vUserName	text;
BEGIN
  SELECT username INTO vUserName FROM users WHERE id = current_userid();
  RETURN vUserName;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION oauth2_current_code ------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает текущий код авторизации (OAuth 2.0).
 * @return {text} - Код авторизации
 */
CREATE OR REPLACE FUNCTION oauth2_current_code (
  pSession      text DEFAULT current_session()
)
RETURNS         text
AS $$
DECLARE
  vCode         text;
BEGIN
  SELECT t.token INTO vCode
    FROM db.token_header h INNER JOIN db.token t ON h.id = t.header AND t.type = 'C'
   WHERE h.session = pSession
     AND t.validFromDate <= Now()
     AND t.validToDate > Now();

  RETURN vCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- db.acl ----------------------------------------------------------------------
--------------------------------------------------------------------------------
/*
 Маска доступа:
   s - substitute user;
   L - unlock user;
   l - lock user;
   D - delete group;
   U - update group;
   C - create group;
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
COMMENT ON COLUMN db.acl.mask IS 'Маска доступа: {sLlDUCducoi}.';

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_acl_before()
RETURNS TRIGGER AS $$
BEGIN
  NEW.mask = NEW.allow & ~NEW.deny;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER t_acl_before
  BEFORE INSERT OR UPDATE ON db.acl
  FOR EACH ROW
  EXECUTE PROCEDURE ft_acl_before();

--------------------------------------------------------------------------------
-- FUNCTION acl ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION acl (
  pUserId       numeric,
  OUT deny      bit varying,
  OUT allow     bit varying,
  OUT mask      bit varying
) RETURNS       SETOF record
AS $$
  WITH mg AS (
      SELECT pUserId AS userid UNION SELECT userid FROM db.member_group WHERE member = pUserId
  )
  SELECT bit_or(a.deny), bit_or(a.allow), bit_or(a.mask)
    FROM db.acl a INNER JOIN mg ON a.userid = mg.userid;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetAccessControlListMask ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetAccessControlListMask (
  pUserId	numeric DEFAULT current_userid()
) RETURNS	bit varying
AS $$
  SELECT mask FROM acl(pUserId)
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CheckAccessControlList ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckAccessControlList (
  pMask		bit,
  pUserId	numeric DEFAULT current_userid()
) RETURNS	boolean
AS $$
BEGIN
  RETURN coalesce(GetAccessControlListMask(pUserId) & pMask = pMask, false);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- chmod -----------------------------------------------------------------------
--------------------------------------------------------------------------------
/*
 * Устанавливает битовую маску доступа для пользователя.
 * @param {bit varying} pMask - Маска доступа. (d:{sLlDUCducoi}a:{sLlDUCducoi})
 Где: d - запрещающие биты; a - разрешающие биты:
   s - substitute user;
   L - unlock user;
   l - lock user;
   D - delete group;
   U - update group;
   C - create group;
   d - delete user;
   u - update user;
   c - create user;
   o - logout;
   i - login
 * @param {numeric} pUserId - Идентификатор пользователя/группы
 * @return {void}
*/
CREATE OR REPLACE FUNCTION chmod (
  pMask         bit varying,
  pUserId       numeric DEFAULT current_userid()
) RETURNS       void
AS $$
DECLARE
  bDeny         bit varying;
  bAllow        bit varying;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(GetGroup('administrator')) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  pMask := NULLIF(pMask, B'0000000000000000000000');

  IF pMask IS NOT NULL THEN
    bDeny := coalesce(SubString(pMask FROM 1 FOR 8), B'00000000000');
    bAllow := coalesce(SubString(pMask FROM 9 FOR 8), B'00000000000');

	INSERT INTO db.acl SELECT pUserId, bDeny, bAllow
	  ON CONFLICT (userid) DO UPDATE SET deny = bDeny, allow = bAllow;
  ELSE
    DELETE FROM db.acl WHERE userid = pUserId;
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SubstituteUser -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Меняет идентификатор текущего пользователя в активном сеансе
 * @param {numeric} pUserId - Идентификатор нового пользователя
 * @param {text} pPassword - Пароль текущего пользователя
 * @param {text} pSession - Код сессии
 * @return {void}
 */
CREATE OR REPLACE FUNCTION SubstituteUser (
  pUserId	numeric,
  pPassword	text,
  pSession	text DEFAULT current_session()
) RETURNS	void
AS $$
BEGIN
  IF session_user <> 'kernel' THEN
	IF NOT CheckAccessControlList(B'10000000000', session_userid(pSession)) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  IF CheckPassword(session_username(pSession), pPassword) THEN

    UPDATE db.session
       SET userid = pUserId, area = GetDefaultArea(pUserId), interface = GetDefaultInterface(pUserId)
     WHERE code = pSession;

    IF FOUND THEN
      PERFORM SetCurrentUserId(pUserId);
    END IF;
  ELSE
    RAISE EXCEPTION 'ERR-40300: %', GetErrorMessage();
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SubstituteUser -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Меняет текущего пользователя в активном сеансе на указанного пользователя
 * @param {text} pRoleName - Имя пользователь для подстановки
 * @param {text} pPassword - Пароль текущего пользователя
 * @param {text} pSession - Код сессии
 * @return {void}
 */
CREATE OR REPLACE FUNCTION SubstituteUser (
  pRoleName	text,
  pPassword	text,
  pSession	text DEFAULT current_session()
) RETURNS	void
AS $$
BEGIN
  PERFORM SubstituteUser(GetUser(pRoleName), pPassword, pSession);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetSessionArea -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetSessionArea (
  pArea 	numeric,
  pSession	text DEFAULT current_session()
) RETURNS 	void
AS $$
BEGIN
  UPDATE db.session SET area = pArea WHERE code = pSession;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetSessionArea -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetSessionArea (
  pSession	text DEFAULT current_session()
)
RETURNS 	numeric
AS $$
DECLARE
  nArea	    numeric;
BEGIN
  IF pSession IS NOT NULL THEN
    SELECT area INTO nArea FROM db.session WHERE code = pSession;
  END IF;
  RETURN nArea;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION current_area_type --------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION current_area_type (
  pSession	text DEFAULT current_session()
)
RETURNS 	numeric
AS $$
DECLARE
  nType     numeric;
BEGIN
  SELECT type INTO nType FROM db.area WHERE id = GetSessionArea(pSession);
  RETURN nType;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION current_area -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION current_area (
  pSession	text DEFAULT current_session()
)
RETURNS 	numeric
AS $$
BEGIN
  RETURN GetSessionArea(pSession);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetSessionInterface ------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetSessionInterface (
  pInterface 	numeric,
  pSession	    text DEFAULT current_session()
) RETURNS 	    void
AS $$
BEGIN
  UPDATE db.session SET interface = pInterface WHERE code = pSession;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetSessionInterface ------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetSessionInterface (
  pSession	    text DEFAULT current_session()
)
RETURNS 	    numeric
AS $$
DECLARE
  nInterface    numeric;
BEGIN
  IF pSession IS NOT NULL THEN
    SELECT interface INTO nInterface FROM db.session WHERE code = pSession;
  END IF;
  RETURN nInterface;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION current_interface --------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION current_interface (
  pSession	text DEFAULT current_session()
)
RETURNS 	numeric
AS $$
BEGIN
  RETURN GetSessionInterface(pSession);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetOperDate --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Устанавливает дату операционного дня.
 * @param {timestamp} pOperDate - Дата операционного дня
 * @param {text} pSession - Код сессии
 * @return {void}
 */
CREATE OR REPLACE FUNCTION SetOperDate (
  pOperDate 	timestamp,
  pSession	    text DEFAULT current_session()
) RETURNS 	    void
AS $$
BEGIN
  UPDATE db.session SET oper_date = pOperDate WHERE code = pSession;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetOperDate --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Устанавливает дату операционного дня.
 * @param {timestamptz} pOperDate - Дата операционного дня
 * @param {text} pSession - Код сессии
 * @return {void}
 */
CREATE OR REPLACE FUNCTION SetOperDate (
  pOperDate 	timestamptz,
  pSession	    text DEFAULT current_session()
) RETURNS 	    void
AS $$
BEGIN
  UPDATE db.session SET oper_date = pOperDate WHERE code = pSession;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetOperDate --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает дату операционного дня.
 * @param {text} pSession - Код сессии
 * @return {timestamp} - Дата операционного дня
 */
CREATE OR REPLACE FUNCTION GetOperDate (
  pSession	text DEFAULT current_session()
)
RETURNS 	timestamp
AS $$
DECLARE
  dtOperDate	timestamp;
BEGIN
  IF pSession IS NOT NULL THEN
    SELECT oper_date INTO dtOperDate FROM db.session WHERE code = pSession;
  END IF;
  RETURN dtOperDate;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION oper_date ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает дату операционного дня.
 * @param {text} pSession - Код сессии
 * @return {timestamp} - Дата операционного дня
 */
CREATE OR REPLACE FUNCTION oper_date (
  pSession	text DEFAULT current_session()
)
RETURNS 	timestamp
AS $$
DECLARE
  dtOperDate	timestamp;
BEGIN
  dtOperDate := GetOperDate(pSession);
  IF dtOperDate IS NULL THEN
    dtOperDate := now();
  END IF;
  RETURN dtOperDate;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetLocale ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Устанавливает по идентификатору текущий язык.
 * @param {id} pLocale - Идентификатор языка
 * @param {text} pSession - Код сессии
 * @return {void}
 */
CREATE OR REPLACE FUNCTION SetLocale (
  pLocale   numeric,
  pSession	text DEFAULT current_session()
) RETURNS	void
AS $$
BEGIN
  UPDATE db.session SET locale = pLocale WHERE code = pSession;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SetLocale ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Устанавливает по коду текущий язык.
 * @param {text} pCode - Код языка
 * @param {text} pSession - Код сессии
 * @return {void}
 */
CREATE OR REPLACE FUNCTION SetLocale (
  pCode		text DEFAULT 'ru',
  pSession	text DEFAULT current_session()
) RETURNS	void
AS $$
DECLARE
  nLocale		numeric;
BEGIN
  SELECT id INTO nLocale FROM db.locale WHERE code = pCode;
  IF found THEN
    PERFORM SetLocale(nLocale, pSession);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetSessionLocale ---------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает идентификатор текущего языка.
 * @param {text} pSession - Код сессии
 * @return {numeric} - Идентификатор языка.
 */
CREATE OR REPLACE FUNCTION GetSessionLocale (
  pSession	text DEFAULT current_session()
)
RETURNS		numeric
AS $$
DECLARE
  nLocale		numeric;
BEGIN
  IF pSession IS NOT NULL THEN
    SELECT locale INTO nLocale FROM db.session WHERE code = pSession;
  END IF;
  RETURN nLocale;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION locale_code --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает код текущего языка.
 * @param {text} pSession - Код сессии
 * @return {text} - Код языка
 */
CREATE OR REPLACE FUNCTION locale_code (
  pSession	text DEFAULT current_session()
)
RETURNS		text
AS $$
DECLARE
  vCode		text;
BEGIN
  SELECT code INTO vCode FROM db.locale WHERE id = GetSessionLocale(pSession);
  RETURN vCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION current_locale -----------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает идентификатор текущего языка.
 * @param {text} pSession - Код сессии
 * @return {numeric} - Идентификатор языка.
 */
CREATE OR REPLACE FUNCTION current_locale (
  pSession	text DEFAULT current_session()
)
RETURNS		numeric
AS $$
BEGIN
  RETURN GetSessionLocale(pSession);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SECURITY --------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- IsUserRole ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Проверяет роль пользователя.
 * @param {numeric} pRole - Идентификатор роли (группы)
 * @param {numeric} pUser - Идентификатор пользователя (учётной записи)
 * @return {boolean}
 */
CREATE OR REPLACE FUNCTION IsUserRole (
  pRole		numeric,
  pUser		numeric DEFAULT current_userid()
) RETURNS	boolean
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM db.member_group WHERE userid = pRole AND member = pUser;

  RETURN nId IS NOT NULL;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- IsUserRole ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Проверяет роль пользователя.
 * @param {text} pRole - Код роли (группы)
 * @param {text} pUser - Код пользователя (учётной записи)
 * @return {boolean}
 */
CREATE OR REPLACE FUNCTION IsUserRole (
  pRole		text,
  pUser		text DEFAULT current_username()
) RETURNS	boolean
AS $$
DECLARE
  nUserId	numeric;
  nRoleId	numeric;
BEGIN
  SELECT id INTO nUserId FROM users WHERE username = lower(pUser);
  SELECT id INTO nRoleId FROM groups WHERE username = lower(pRole);

  RETURN IsUserRole(nRoleId, nUserId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateUser ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт учётную запись пользователя.
 * @param {text} pRoleName - Пользователь
 * @param {text} pPassword - Пароль
 * @param {text} pName - Полное имя
 * @param {text} pPhone - Телефон
 * @param {text} pEmail - Электронный адрес
 * @param {text} pDescription - Описание
 * @param {boolean} pPasswordChange - Сменить пароль при следующем входе в систему
 * @param {boolean} pPasswordNotChange - Установить запрет на смену пароля самим пользователем
 * @param {numeric} pArea - Зона
 * @return {(id|exception)} - Id учётной записи или ошибку
 */
CREATE OR REPLACE FUNCTION CreateUser (
  pRoleName             text,
  pPassword             text,
  pName                 text,
  pPhone                text DEFAULT null,
  pEmail                text DEFAULT null,
  pDescription          text DEFAULT null,
  pPasswordChange       boolean DEFAULT true,
  pPasswordNotChange    boolean DEFAULT false,
  pArea                 numeric DEFAULT current_area()
) RETURNS               numeric
AS $$
DECLARE
  nArea                 numeric;
  nUserId		        numeric;
  vSecret               text;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT CheckAccessControlList(B'00000000100') THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  nArea := coalesce(pArea, GetArea('guest'));

  SELECT id INTO nUserId FROM users WHERE username = lower(pRoleName);

  IF found THEN
    PERFORM RoleExists(pRoleName);
  END IF;

  INSERT INTO db.user (type, username, name, phone, email, description, passwordchange, passwordnotchange)
  VALUES ('U', pRoleName, pName, pPhone, pEmail, pDescription, pPasswordChange, pPasswordNotChange)
  RETURNING id, secret INTO nUserId, vSecret;

  PERFORM AddMemberToInterface(nUserId, GetInterface('I:1:0:0'));
  PERFORM AddMemberToArea(nUserId, nArea);

  INSERT INTO db.profile (userid, area) VALUES (nUserId, nArea);

  IF NULLIF(pPassword, '') IS NULL THEN
    pPassword := encode(hmac(vSecret, GetSecretKey(), 'sha1'), 'hex');
  END IF;

  PERFORM SetPassword(nUserId, pPassword);

  RETURN nUserId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateGroup -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт группу.
 * @param {text} pRoleName - Группа
 * @param {text} pName - Полное имя
 * @param {text} pDescription - Описание
 * @return {(id|exception)} - Id группы или ошибку
 */
CREATE OR REPLACE FUNCTION CreateGroup (
  pRoleName     text,
  pName         text,
  pDescription	text
) RETURNS	    numeric
AS $$
DECLARE
  nGroupId	    numeric;
BEGIN
  IF session_user <> 'kernel' THEN
	IF NOT CheckAccessControlList(B'00000100000') THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  SELECT id INTO nGroupId FROM groups WHERE username = lower(pRoleName);

  IF found THEN
    PERFORM RoleExists(pRoleName);
  END IF;

  INSERT INTO db.user (type, username, name, description)
  VALUES ('G', pRoleName, pName, pDescription) RETURNING Id INTO nGroupId;

  RETURN nGroupId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- UpdateUser ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Обновляет учётную запись пользователя.
 * @param {id} pId - Идентификатор учетной записи пользователя
 * @param {text} pRoleName - Пользователь
 * @param {text} pPassword - Пароль
 * @param {text} pName - Полное имя
 * @param {text} pPhone - Телефон
 * @param {text} pEmail - Электронный адрес
 * @param {text} pDescription - Описание
 * @param {boolean} pPasswordChange - Сменить пароль при следующем входе в систему
 * @param {boolean} pPasswordNotChange - Установить запрет на смену пароля самим пользователем
 * @return {(void|exception)}
 */
CREATE OR REPLACE FUNCTION UpdateUser (
  pId                   numeric,
  pRoleName             text,
  pPassword             text DEFAULT null,
  pName                 text DEFAULT null,
  pPhone                text DEFAULT null,
  pEmail                text DEFAULT null,
  pDescription          text DEFAULT null,
  pPasswordChange       boolean DEFAULT null,
  pPasswordNotChange    boolean DEFAULT null
) RETURNS		        void
AS $$
DECLARE
  r			            db.user%rowtype;
BEGIN
  SELECT * INTO r FROM db.user WHERE id = pId AND type = 'U';
  IF NOT FOUND THEN
    PERFORM UserNotFound(pId);
  END IF;

  IF session_user <> 'kernel' THEN
    IF pId <> current_userid() THEN
	  IF NOT CheckAccessControlList(B'00000001000') THEN
		PERFORM AccessDenied();
	  END IF;
    END IF;
  END IF;

  IF coalesce((SELECT true FROM pg_roles WHERE rolname = lower(r.username)), false) THEN
    IF lower(r.username) <> lower(pRoleName) THEN
      PERFORM SystemRoleError();
    END IF;
  END IF;

  pName := coalesce(NULLIF(pName, ''), r.name);
  pPhone := coalesce(NULLIF(pPhone, ''), r.phone);
  pEmail := coalesce(NULLIF(pEmail, ''), r.email);
  pDescription := coalesce(NULLIF(pDescription, ''), r.description);
  pPasswordChange := coalesce(pPasswordChange, r.passwordchange);
  pPasswordNotChange := coalesce(pPasswordNotChange, r.passwordnotchange);

  UPDATE db.user
     SET username = coalesce(pRoleName, username),
         name = coalesce(pName, username),
         phone = CheckNull(pPhone),
         email = CheckNull(pEmail),
         description = CheckNull(pDescription),
         passwordchange = pPasswordChange,
         passwordnotchange = pPasswordNotChange
   WHERE id = pId;

  IF NULLIF(pPassword, '') IS NOT NULL THEN
    PERFORM SetPassword(pId, pPassword);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- UpdateGroup -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Обновляет учётные данные группы.
 * @param {id} pId - Идентификатор группы
 * @param {text} pRoleName - Группа
 * @param {text} pName - Полное имя
 * @param {text} pDescription - Описание
 * @return {(void|exception)}
 */
CREATE OR REPLACE FUNCTION UpdateGroup (
  pId           numeric,
  pRoleName     text,
  pName         text,
  pDescription  text
) RETURNS       void
AS $$
DECLARE
  r             db.user%rowtype;
BEGIN
  SELECT * INTO r FROM db.user WHERE id = pId AND type = 'G';
  IF NOT FOUND THEN
    PERFORM UserNotFound(pId);
  END IF;

  IF session_user <> 'kernel' THEN
    IF NOT CheckAccessControlList(B'00001000000') OR r.readonly THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  IF coalesce((SELECT true FROM pg_roles WHERE rolname = lower(r.username)), false) THEN
    IF lower(r.username) <> lower(pRoleName) THEN
      PERFORM SystemRoleError();
    END IF;
  END IF;

  UPDATE db.user
     SET username = coalesce(pRoleName, username),
         name = coalesce(pName, name),
         description = coalesce(pDescription, description)
   WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteUser ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет учётную запись пользователя.
 * @param {id} pId - Идентификатор учётной записи пользователя
 * @return {(void|exception)}
 */
CREATE OR REPLACE FUNCTION DeleteUser (
  pId		numeric
) RETURNS	void
AS $$
DECLARE
  vUserName	varchar;
BEGIN
  IF session_user <> 'kernel' THEN
	IF NOT CheckAccessControlList(B'00000010000') THEN
	  PERFORM AccessDenied();
	END IF;
  END IF;

  IF pId = current_userid() THEN
    PERFORM DeleteUserError();
  END IF;

  SELECT username INTO vUserName FROM db.user WHERE id = pId;

  IF coalesce((SELECT true FROM pg_roles WHERE rolname = lower(vUserName)), false) THEN
    PERFORM SystemRoleError();
  END IF;

  IF FOUND THEN

    UPDATE db.object SET oper = GetUser('admin') WHERE oper = pId;
    UPDATE db.object SET owner = GetUser('admin') WHERE owner = pId;

    DELETE FROM db.acl WHERE userid = pId;
    DELETE FROM db.aou WHERE userid = pId;

    DELETE FROM db.member_area WHERE member = pId;
    DELETE FROM db.member_interface WHERE member = pId;
    DELETE FROM db.member_group WHERE member = pId;
    DELETE FROM db.auth WHERE userid = pId;
    DELETE FROM db.session WHERE userid = pId;
    DELETE FROM db.profile WHERE userid = pId;
    DELETE FROM db.user WHERE id = pId;
  ELSE
    PERFORM UserNotFound(pId);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteUser ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет учётную запись пользователя.
 * @param {text} pRoleName - Пользователь (login)
 * @return {(void|exception)}
 */
CREATE OR REPLACE FUNCTION DeleteUser (
  pRoleName	text
) RETURNS	void
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM db.user WHERE type = 'U' AND username = lower(pRoleName);

  IF NOT FOUND THEN
    PERFORM UserNotFound(pRoleName);
  END IF;

  PERFORM DeleteUser(nId);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteGroup -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет группу.
 * @param {id} pId - Идентификатор группы
 * @return {(void|exception)}
 */
CREATE OR REPLACE FUNCTION DeleteGroup (
  pId		    numeric
) RETURNS	    void
AS $$
DECLARE
  vGroupName    varchar;
BEGIN
  IF session_user <> 'kernel' THEN
	IF NOT CheckAccessControlList(B'00001000000') THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  SELECT username INTO vGroupName FROM db.user WHERE id = pId;

  IF coalesce((SELECT true FROM pg_roles WHERE rolname = lower(vGroupName)), false) THEN
    PERFORM SystemRoleError();
  END IF;

  DELETE FROM db.member_area WHERE member = pId;
  DELETE FROM db.member_interface WHERE member = pId;
  DELETE FROM db.member_group WHERE userid = pId;
  DELETE FROM db.profile WHERE userid = pId;
  DELETE FROM db.user WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteGroup -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет группу.
 * @param {text} pRoleName - Группа
 * @return {(void|exception)}
 */
CREATE OR REPLACE FUNCTION DeleteGroup (
  pRoleName     text
) RETURNS       void
AS $$
BEGIN
  PERFORM DeleteGroup(GetGroup(pRoleName));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetUser ---------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает идентификатор пользователя по имени пользователя.
 * @param {text} pRoleName - Пользователь
 * @return {id}
 */
CREATE OR REPLACE FUNCTION GetUser (
  pRoleName	text
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM db.user WHERE type = 'U' AND username = lower(pRoleName);

  IF NOT found THEN
    PERFORM UserNotFound(pRoleName);
  END IF;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetGroup --------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает идентификатор группы по наименованию.
 * @param {text} pRoleName - Группа
 * @return {id}
 */
CREATE OR REPLACE FUNCTION GetGroup (
  pRoleName     text
) RETURNS	    numeric
AS $$
DECLARE
  nId		    numeric;
BEGIN
  SELECT id INTO nId FROM db.user WHERE type = 'G' AND username = lower(pRoleName);

  IF NOT found THEN
    PERFORM UnknownRoleName(pRoleName);
  END IF;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SetPassword -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Устанавливает пароль пользователя.
 * @param {id} pId - Идентификатор пользователя
 * @param {text} pPassword - Пароль
 * @return {void}
 */
CREATE OR REPLACE FUNCTION SetPassword (
  pId			    numeric,
  pPassword		    text
) RETURNS		    void
AS $$
DECLARE
  nUserId		    numeric;
  bPasswordChange	boolean;
  r			        record;
BEGIN
  nUserId := current_userid();

  IF session_user <> 'kernel' THEN
    IF pId <> nUserId THEN
      IF NOT IsUserRole(GetGroup('administrator')) THEN
        PERFORM AccessDenied();
      END IF;
    END IF;
  END IF;

  SELECT username, passwordchange, passwordnotchange INTO r FROM users WHERE id = pId;

  IF found THEN
    bPasswordChange := r.PasswordChange;

    IF pId = nUserId THEN
      IF r.PasswordNotChange THEN
        PERFORM UserPasswordChange();
      END IF;

      IF r.PasswordChange THEN
        bPasswordChange := false;
      END IF;
    END IF;

    UPDATE db.user
       SET passwordchange = bPasswordChange,
           pswhash = crypt(pPassword, gen_salt('md5'))
     WHERE id = pId;
  ELSE
    PERFORM UserNotFound(pId);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ChangePassword --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Меняет пароль пользователя.
 * @param {numeric} pId - Идентификатор учетной записи
 * @param {text} pOldPass - Старый пароль
 * @param {text} pNewPass - Новый пароль
 * @return {void}
 */
CREATE OR REPLACE FUNCTION ChangePassword (
  pId		numeric,
  pOldPass	text,
  pNewPass	text
) RETURNS	boolean
AS $$
DECLARE
  r		record;
BEGIN
  SELECT username, system INTO r FROM users WHERE id = pId;

  IF found THEN
    IF CheckPassword(r.username, pOldPass) THEN

      PERFORM SetPassword(pId, pNewPass);

      IF r.system THEN
        EXECUTE 'ALTER ROLE ' || r.username || ' WITH PASSWORD ' || quote_literal(pNewPass);
      END IF;

      RETURN true;
    END IF;
  ELSE
    PERFORM UserNotFound(pId);
  END IF;

  RETURN false;
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- UserLock --------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Блокирует учётную запись пользователя.
 * @param {id} pId - Идентификатор учётной записи пользователя
 * @return {void}
 */
CREATE OR REPLACE FUNCTION UserLock (
  pId		numeric
) RETURNS	void
AS $$
DECLARE
  nId		numeric;
BEGIN
  IF session_user <> 'kernel' THEN
    IF pId <> current_userid() THEN
	  IF NOT CheckAccessControlList(B'00100000000') THEN
		PERFORM AccessDenied();
	  END IF;
    END IF;
  END IF;

  SELECT id INTO nId FROM users WHERE id = pId;

  IF found THEN
    UPDATE db.user SET status = set_bit(set_bit(status, 3, 0), 1, 1), lock_date = now() WHERE id = pId;
  ELSE
    PERFORM UserNotFound(pId);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- UserUnLock ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Снимает блокировку с учётной записи пользователя.
 * @param {id} pId - Идентификатор учётной записи пользователя
 * @return {void}
 */
CREATE OR REPLACE FUNCTION UserUnLock (
  pId		numeric
) RETURNS	void
AS $$
DECLARE
  nId		numeric;
BEGIN
  IF session_user <> 'kernel' THEN
	IF NOT CheckAccessControlList(B'01000000000') THEN
	  PERFORM AccessDenied();
	END IF;
  END IF;

  SELECT id INTO nId FROM users WHERE id = pId;

  IF found THEN
    UPDATE db.user SET status = B'0001', lock_date = null, expiry_date = null WHERE id = pId;
  ELSE
    PERFORM UserNotFound(pId);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AddMemberToGroup ------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Добавляет пользователя в группу.
 * @param {id} pMember - Идентификатор пользователя
 * @param {id} pGroup - Идентификатор группы
 * @return {numeric}
 */
CREATE OR REPLACE FUNCTION AddMemberToGroup (
  pMember	numeric,
  pGroup	numeric
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(GetGroup('administrator')) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  SELECT id INTO nId FROM db.member_group WHERE userid = pGroup AND member = pMember;

  IF NOT FOUND THEN
    INSERT INTO db.member_group (userid, member) VALUES (pGroup, pMember)
    RETURNING id INTO nId;
  END IF;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteGroupForMember --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет группу для пользователя.
 * @param {id} pMember - Идентификатор пользователя
 * @param {id} pGroup - Идентификатор группы, при null удаляет все группы для указанного пользователя
 * @return {void}
 */
CREATE OR REPLACE FUNCTION DeleteGroupForMember (
  pMember	numeric,
  pGroup	numeric DEFAULT null
) RETURNS	void
AS $$
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(GetGroup('administrator')) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  DELETE FROM db.member_group WHERE userid = coalesce(pGroup, userid) AND member = pMember;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteMemberFromGroup -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет пользователя из группу.
 * @param {id} pGroup - Идентификатор группы
 * @param {id} pMember - Идентификатор пользователя, при null удаляет всех пользователей из указанной группы
 * @return {void}
 */
CREATE OR REPLACE FUNCTION DeleteMemberFromGroup (
  pGroup	numeric,
  pMember	numeric DEFAULT null
) RETURNS	void
AS $$
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(GetGroup('administrator')) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  DELETE FROM db.member_group WHERE userid = pGroup AND member = coalesce(pMember, member);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetUserName -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetUserName (
  pId		numeric
) RETURNS	text
AS $$
DECLARE
  vUserName	text;
BEGIN
  SELECT username INTO vUserName FROM db.user WHERE id = pId AND type = 'U';
  RETURN vUserName;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetGroupName ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetGroupName (
  pId		numeric
) RETURNS	text
AS $$
DECLARE
  vGroupName	text;
BEGIN
  SELECT username INTO vGroupName FROM db.user WHERE id = pId AND type = 'G';
  RETURN vGroupName;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateArea ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateArea (
  pParent	    numeric,
  pType		    numeric,
  pCode		    varchar,
  pName		    varchar,
  pDescription	text DEFAULT null
) RETURNS 	    numeric
AS $$
DECLARE
  nId		    numeric;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(GetGroup('administrator')) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  SELECT id INTO nId FROM db.area WHERE code = pCode;
  IF FOUND THEN
    PERFORM RecordExists(pCode);
  END IF;

  INSERT INTO db.area (parent, type, code, name, description)
  VALUES (coalesce(pParent, GetArea('root')), pType, pCode, pName, pDescription) RETURNING Id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditArea --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditArea (
  pId			    numeric,
  pParent		    numeric DEFAULT null,
  pType			    numeric DEFAULT null,
  pCode			    varchar DEFAULT null,
  pName			    varchar DEFAULT null,
  pDescription		text DEFAULT null,
  pValidFromDate	timestamp DEFAULT null,
  pValidToDate		timestamp DEFAULT null
) RETURNS void
AS $$
DECLARE
  vCode             varchar;
  nType             numeric;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(GetGroup('administrator')) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  SELECT type, code INTO nType, vCode FROM db.area WHERE id = pId;
  IF NOT FOUND THEN
    PERFORM AreaError();
  END IF;

  pCode := coalesce(pCode, vCode);
  IF pCode <> vCode THEN
    SELECT code INTO vCode FROM db.area WHERE code = pCode;
    IF FOUND THEN
      PERFORM RecordExists(pCode);
    END IF;
  END IF;

  IF nType = GetAreaType('root') THEN
    UPDATE db.area
       SET name = coalesce(pName, name),
           description = coalesce(pDescription, description)
     WHERE id = pId;
  ELSE
    UPDATE db.area
       SET parent = coalesce(pParent, parent),
           type = coalesce(pType, type),
           code = coalesce(pCode, code),
           name = coalesce(pName, name),
           description = coalesce(pDescription, description),
           validFromDate = coalesce(pValidFromDate, validFromDate),
           validToDate = coalesce(pValidToDate, validToDate)
     WHERE id = pId;
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteArea ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteArea (
  pId			numeric
) RETURNS       void
AS $$
DECLARE
  nId           numeric;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(GetGroup('administrator')) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  SELECT id INTO nId FROM db.area WHERE id = pId;
  IF NOT FOUND THEN
    PERFORM ObjectNotFound('подразделение', 'id', pId);
  END IF;

  DELETE FROM db.area WHERE Id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetArea ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetArea (
  pCode		text
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM db.area WHERE code = pCode;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetAreaCode -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetAreaCode (
  pId		numeric
) RETURNS	varchar
AS $$
DECLARE
  vCode		varchar;
BEGIN
  SELECT code INTO vCode FROM db.area WHERE id = pId;
  RETURN vCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetAreaName -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetAreaName (
  pId		numeric
) RETURNS	varchar
AS $$
DECLARE
  vName		varchar;
BEGIN
  SELECT name INTO vName FROM db.area WHERE id = pId;
  RETURN vName;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AddMemberToArea -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddMemberToArea (
  pMember	numeric,
  pArea		numeric
) RETURNS   numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(GetGroup('administrator')) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  SELECT id INTO nId FROM db.member_area WHERE area = pArea AND member = pMember;

  IF NOT FOUND THEN
    INSERT INTO db.member_area (area, member) VALUES (pArea, pMember)
    RETURNING id INTO nId;
  END IF;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteAreaForMember ---------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет подразделение для пользователя.
 * @param {id} pMember - Идентификатор пользователя
 * @param {id} pArea - Идентификатор подразделения, при null удаляет все подразделения для указанного пользователя
 * @return {void}
 */
CREATE OR REPLACE FUNCTION DeleteAreaForMember (
  pMember	numeric,
  pArea		numeric DEFAULT null
) RETURNS   void
AS $$
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(GetGroup('administrator')) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  DELETE FROM db.member_area WHERE area = coalesce(pArea, area) AND member = pMember;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteMemberFromArea --------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удаляет пользователя из подразделения.
 * @param {id} pArea - Идентификатор подразделения
 * @param {id} pMember - Идентификатор пользователя, при null удаляет всех пользователей из указанного подразделения
 * @return {void}
 */
CREATE OR REPLACE FUNCTION DeleteMemberFromArea (
  pArea		numeric,
  pMember	numeric DEFAULT null
) RETURNS   void
AS $$
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(GetGroup('administrator')) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  DELETE FROM db.member_area WHERE area = pArea AND member = coalesce(pMember, member);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SetArea ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetArea (
  pArea	        numeric,
  pMember	    numeric DEFAULT current_userid(),
  pSession	    text DEFAULT current_session()
) RETURNS	    void
AS $$
DECLARE
  vUserName     varchar;
  vDepName      text;
BEGIN
  vDepName := GetAreaName(pArea);
  IF vDepName IS NULL THEN
    PERFORM AreaError();
  END IF;

  vUserName := GetUserName(pMember);
  IF vDepName IS NULL THEN
    PERFORM UserNotFound(pMember);
  END IF;

  IF NOT IsMemberArea(pArea, pMember) THEN
    PERFORM UserNotMemberArea(vUserName, vDepName);
  END IF;

  UPDATE db.session SET area = pArea WHERE code = pSession;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- IsMemberArea ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Проверяет доступ к зоне.
 * @param {numeric} pArea - Идентификатор зоны
 * @param {numeric} pMember - Идентификатор роли (группы/учётной записи)
 * @return {boolean}
 */
CREATE OR REPLACE FUNCTION IsMemberArea (
  pArea		numeric,
  pMember   numeric DEFAULT current_userid()
) RETURNS	boolean
AS $$
DECLARE
  nCount    bigint;
BEGIN
  IF pArea IS NULL OR pMember IS NULL THEN
    RETURN false;
  END IF;

  WITH RECURSIVE area_tree(id, parent) AS (
    SELECT id, parent FROM db.area WHERE id = pArea
     UNION ALL
    SELECT a.id, a.parent
      FROM db.area a, area_tree t
     WHERE a.id = t.parent
  ) SELECT count(a.id) INTO nCount
      FROM db.member_area m INNER JOIN area_tree a ON m.area = a.id
       AND member IN (
         SELECT pMember
         UNION ALL
         SELECT userid FROM db.member_group WHERE member = pMember
       );

  RETURN coalesce(nCount, 0) <> 0;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SetDefaultArea --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetDefaultArea (
  pArea	    numeric DEFAULT current_area(),
  pMember	numeric DEFAULT current_userid()
) RETURNS	void
AS $$
BEGIN
  UPDATE db.profile SET area = pArea WHERE userid = pMember;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetDefaultArea --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetDefaultArea (
  pMember   numeric DEFAULT current_userid()
) RETURNS	numeric
AS $$
DECLARE
  nArea	    numeric;
BEGIN
  SELECT area INTO nArea FROM db.profile WHERE userid = pMember;
  RETURN nArea;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateInterface -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateInterface (
  pName		    varchar,
  pDescription	text
) RETURNS 	    numeric
AS $$
DECLARE
  nId		    numeric;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(GetGroup('administrator')) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  INSERT INTO db.interface (name, description)
  VALUES (pName, pDescription) RETURNING Id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- UpdateInterface -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION UpdateInterface (
  pId		    numeric,
  pName		    varchar,
  pDescription	text
) RETURNS 	    void
AS $$
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(GetGroup('administrator')) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  UPDATE db.interface SET Name = pName, Description = pDescription WHERE Id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteInterface -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteInterface (
  pId		numeric
) RETURNS 	void
AS $$
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(GetGroup('administrator')) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  DELETE FROM db.interface WHERE Id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AddMemberToInterface --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddMemberToInterface (
  pMember       numeric,
  pInterface    numeric
) RETURNS       numeric
AS $$
DECLARE
  nId		    numeric;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(GetGroup('administrator')) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  SELECT id INTO nId FROM db.member_interface WHERE interface = pInterface AND member = pMember;

  IF NOT FOUND THEN
    INSERT INTO db.member_interface (interface, member) VALUES (pInterface, pMember)
    RETURNING id INTO nId;
  END IF;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteInterfaceForMember ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteInterfaceForMember (
  pMember	    numeric,
  pInterface	numeric DEFAULT null
) RETURNS       void
AS $$
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(GetGroup('administrator')) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  DELETE FROM db.member_interface WHERE interface = coalesce(pInterface, interface) AND member = pMember;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- DeleteMemberFromInterface ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteMemberFromInterface (
  pInterface	numeric,
  pMember	    numeric DEFAULT null
) RETURNS       void
AS $$
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(GetGroup('administrator')) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  DELETE FROM db.member_interface WHERE interface = pInterface AND member = coalesce(pMember, member);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetInterfaceSID -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetInterfaceSID (
  pId		numeric
) RETURNS 	text
AS $$
DECLARE
  vSID		text;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(GetGroup('administrator')) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  SELECT sid INTO vSID FROM db.interface WHERE id = pId;

  RETURN vSID;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetInterface ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetInterface (
  pSID		text
) RETURNS 	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM db.interface WHERE SID = pSID;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetInterfaceName ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetInterfaceName (
  pId		numeric
) RETURNS 	varchar
AS $$
DECLARE
  vName		varchar;
BEGIN
  SELECT name INTO vName FROM db.interface WHERE id = pId;

  RETURN vName;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SetInterface ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetInterface (
  pInterface	numeric,
  pMember	    numeric DEFAULT current_userid(),
  pSession	    text DEFAULT current_session()
) RETURNS	    void
AS $$
DECLARE
  vUserName     varchar;
  vInterface    text;
BEGIN
  vInterface := GetInterfaceName(pInterface);
  IF vInterface IS NULL THEN
    PERFORM InterfaceError();
  END IF;

  vUserName := GetUserName(pMember);
  IF vUserName IS NULL THEN
    PERFORM UserNotFound(pMember);
  END IF;

  IF NOT IsMemberInterface(pInterface, pMember) THEN
    PERFORM UserNotMemberInterface(vUserName, vInterface);
  END IF;

  UPDATE db.session SET interface = pInterface WHERE code = pSession;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- IsMemberInterface -----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Проверяет доступ к интерфейсу.
 * @param {numeric} pInterface - Идентификатор интерфейса
 * @param {numeric} pMember - Идентификатор роли (группы/учётной записи)
 * @return {boolean}
 */
CREATE OR REPLACE FUNCTION IsMemberInterface (
  pInterface    numeric,
  pMember       numeric DEFAULT current_userid()
) RETURNS       boolean
AS $$
DECLARE
  nCount        bigint;
BEGIN
  IF pInterface IS NULL OR pMember IS NULL THEN
    RETURN false;
  END IF;

  SELECT count(id) INTO nCount
    FROM db.member_interface
   WHERE interface = pInterface
     AND member IN (
       SELECT pMember
        UNION ALL
       SELECT userid FROM db.member_group WHERE member = pMember
     );

  RETURN coalesce(nCount, 0) <> 0;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SetDefaultInterface ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetDefaultInterface (
  pInterface	numeric DEFAULT current_interface(),
  pMember	    numeric DEFAULT current_userid()
) RETURNS	    void
AS $$
BEGIN
  UPDATE db.profile SET interface = pInterface WHERE userid = pMember;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetDefaultInterface ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetDefaultInterface (
  pMember	    numeric DEFAULT current_userid()
) RETURNS	    numeric
AS $$
DECLARE
  nInterface	numeric;
BEGIN
  SELECT interface INTO nInterface FROM db.profile WHERE userid = pMember;
  RETURN nInterface;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CheckOffline ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckOffline (
  pOffTime	INTERVAL DEFAULT '5 minute'
) RETURNS	void
AS $$
BEGIN
  UPDATE db.profile
     SET state = B'000'
   WHERE state <> B'000'
     AND userid IN (
       SELECT userid FROM db.session
        WHERE userid <> (SELECT id FROM db.user WHERE username = session_user)
          AND updated < now() - pOffTime
     );
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- AUTHENTICATE ----------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- CheckPassword ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckPassword (
  pUserId	numeric,
  pPassword	text
) RETURNS 	boolean
AS $$
DECLARE
  passed 	boolean;
BEGIN
  SELECT (pswhash = crypt(pPassword, pswhash)) INTO passed
    FROM db.user
   WHERE id = pUserId;

  IF found THEN
    IF passed THEN
      PERFORM SetErrorMessage('Успешно.');
    ELSE
      PERFORM SetErrorMessage('Пароль не прошёл проверку.');
    END IF;
  ELSE
    PERFORM SetErrorMessage('Пользователь не найден.');
  END IF;

  RETURN coalesce(passed, false);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CheckPassword ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CheckPassword (
  pRoleName	text,
  pPassword	text
) RETURNS 	boolean
AS $$
BEGIN
  RETURN CheckPassword(GetUser(pRoleName), pPassword);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ValidSession ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ValidSession (
  pSession	    text DEFAULT current_session()
) RETURNS 	    boolean
AS $$
DECLARE
  passed 	    boolean;
BEGIN
  SELECT (pwkey = crypt(StrPwKey(suid, secret, created), pwkey)) INTO passed
    FROM db.session
   WHERE code = pSession;

  IF found THEN
    IF coalesce(passed, false) THEN
      PERFORM SetErrorMessage('Успешно.');
    ELSE
      PERFORM SetErrorMessage('Код сессии не прошёл проверку.');
    END IF;
  ELSE
    PERFORM SetErrorMessage('Код сессии не найден.');
  END IF;

  RETURN coalesce(passed, false);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ValidSecret -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ValidSecret (
  pSecret       text,
  pSession	    text DEFAULT current_session()
) RETURNS 	    boolean
AS $$
DECLARE
  passed 	    boolean;
BEGIN
  SELECT (pSecret = secret) INTO passed
    FROM db.session
   WHERE code = pSession;

  IF found THEN
    IF coalesce(passed, false) THEN
      PERFORM SetErrorMessage('Успешно.');
    ELSE
      PERFORM SetErrorMessage('Секретный код сессии не прошёл проверку.');
    END IF;
  ELSE
    PERFORM SetErrorMessage('Код сессии не найден.');
  END IF;

  RETURN coalesce(passed, false);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SessionIn ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Вход в систему по ключу сессии.
 * @param {text} pSession - Сессия
 * @param {text} pAgent - Агент
 * @param {inet} pHost - IP адрес
 * @param {text} pSalt - Случайное значение соли для ключа аутентификации
 * @return {text} - Код авторизации. Если вернёт null вызвать GetErrorMessage для просмотра сообщения об ошибке.
 */
CREATE OR REPLACE FUNCTION SessionIn (
  pSession      text,
  pAgent        text DEFAULT null,
  pHost         inet DEFAULT null,
  pSalt         text DEFAULT null
)
RETURNS         text
AS $$
DECLARE
  up	        db.user%rowtype;

  nUserId       numeric DEFAULT null;
  nToken        numeric DEFAULT null;
  nArea	        numeric DEFAULT null;
  nInterface    numeric DEFAULT null;
BEGIN
  IF ValidSession(pSession) THEN

	SELECT userid, area, interface
	  INTO nUserId, nArea, nInterface
	  FROM db.session
	 WHERE code = pSession;

	SELECT * INTO up FROM db.user WHERE id = nUserId;

	IF NOT found THEN
	  PERFORM LoginError();
	END IF;

	IF get_bit(up.status, 1) = 1 THEN
	  PERFORM UserLockError();
	END IF;

	IF up.lock_date IS NOT NULL AND up.lock_date <= now() THEN
	  PERFORM UserLockError();
	END IF;

	IF get_bit(up.status, 0) = 1 THEN
	  PERFORM PasswordExpired();
	END IF;

	IF up.expiry_date IS NOT NULL AND up.expiry_date <= now() THEN
	  PERFORM PasswordExpired();
	END IF;

	IF NOT CheckIPTable(up.id, pHost) THEN
	  PERFORM LoginIPTableError(pHost);
	END IF;

	PERFORM SetCurrentSession(pSession);
	PERFORM SetCurrentUserId(up.id);

	UPDATE db.user SET status = set_bit(set_bit(status, 3, 0), 2, 1) WHERE id = up.id;

	UPDATE db.profile
	   SET input_last = now(),
		   lc_ip = coalesce(pHost, lc_ip)
	 WHERE userid = up.id;

	UPDATE db.session
	   SET updated = localtimestamp,
		   agent = coalesce(pAgent, agent),
		   host = coalesce(pHost, host),
		   salt = coalesce(pSalt, salt)
	 WHERE code = pSession
    RETURNING token INTO nToken;

    RETURN GetToken(nToken);
  END IF;

  RETURN null;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- Login -----------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Вход в систему по паре имя пользователя и пароль.
 * @param {numeric} pOAuth2 - Параметры авторизации через OAuth 2.0
 * @param {text} pRoleName - Пользователь (login)
 * @param {text} pPassword - Пароль
 * @param {text} pAgent - Агент
 * @param {inet} pHost - IP адрес
 * @return {text} - Сессия. Если вернёт null вызвать GetErrorMessage для просмотра сообщения об ошибке.
 */
CREATE OR REPLACE FUNCTION Login (
  pOAuth2       numeric,
  pRoleName     text,
  pPassword     text,
  pAgent        text DEFAULT null,
  pHost         inet DEFAULT null
) RETURNS       text
AS $$
DECLARE
  up            db.user%rowtype;

  nArea         numeric DEFAULT null;
  nInterface    numeric DEFAULT null;

  vSession      text DEFAULT null;
BEGIN
  IF NULLIF(pRoleName, '') IS NULL THEN
    PERFORM LoginError();
  END IF;

  IF NULLIF(pPassword, '') IS NULL THEN
    PERFORM LoginError();
  END IF;

  SELECT * INTO up FROM db.user WHERE type = 'U' AND username = pRoleName;

  IF NOT found THEN
    PERFORM LoginError();
  END IF;

  IF NOT CheckAccessControlList(B'00000000001', up.id) THEN
    PERFORM AccessDenied();
  END IF;

  IF get_bit(up.status, 1) = 1 THEN
    PERFORM UserLockError();
  END IF;

  IF up.lock_date IS NOT NULL AND up.lock_date <= now() THEN
    PERFORM UserLockError();
  END IF;

  IF get_bit(up.status, 0) = 1 THEN
    PERFORM PasswordExpired();
  END IF;

  IF up.expiry_date IS NOT NULL AND up.expiry_date <= now() THEN
    PERFORM PasswordExpired();
  END IF;

  nArea := GetDefaultArea(up.id);
  nInterface := GetDefaultInterface(up.id);

  IF NOT CheckIPTable(up.id, pHost) THEN
    PERFORM LoginIPTableError(pHost);
  END IF;

  IF CheckPassword(pRoleName, pPassword) THEN

    PERFORM CheckSessionLimit(up.id);

    INSERT INTO db.session (userid, area, interface, agent, host, oauth2)
    VALUES (up.id, nArea, nInterface, pAgent, pHost, pOAuth2)
    RETURNING code INTO vSession;

    IF vSession IS NULL THEN
      PERFORM AccessDenied();
    END IF;

    PERFORM SetCurrentSession(vSession);
    PERFORM SetCurrentUserId(up.id);

    UPDATE db.user SET status = set_bit(set_bit(status, 3, 0), 2, 1) WHERE id = up.id;

    UPDATE db.profile
       SET input_error = 0,
           input_count = input_count + 1,
           input_last = now(),
           lc_ip = pHost
     WHERE userid = up.id;

  ELSE

    PERFORM SetCurrentSession(null);
    PERFORM SetCurrentUserId(null);

    PERFORM LoginError();

  END IF;

  INSERT INTO db.log (type, code, username, session, text)
  VALUES ('M', 1001, pRoleName, vSession, 'Вход в систему.');

  RETURN vSession;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SignIn ----------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Вход в систему по имени и паролю пользователя.
 * @param {numeric} pOAuth2 - Параметры авторизации через OAuth 2.0
 * @param {text} pRoleName - Пользователь (login)
 * @param {text} pPassword - Пароль
 * @param {text} pAgent - Агент
 * @param {inet} pHost - IP адрес
 * @return {text} - Сессия. Если вернёт null вызвать GetErrorMessage для просмотра сообщения об ошибке.
 */
CREATE OR REPLACE FUNCTION SignIn (
  pOAuth2       numeric,
  pRoleName     text,
  pPassword     text,
  pAgent        text DEFAULT null,
  pHost         inet DEFAULT null
) RETURNS       text
AS $$
DECLARE
  up            db.user%rowtype;

  nInputError   integer;

  message       text;
BEGIN
  PERFORM SetErrorMessage('Успешно.');

  BEGIN
    RETURN Login(pOAuth2, pRoleName, pPassword, pAgent, pHost);
  EXCEPTION
  WHEN others THEN
    GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;

    PERFORM SetCurrentSession(null);
    PERFORM SetCurrentUserId(null);

    PERFORM SetErrorMessage(message);

    SELECT * INTO up FROM db.user WHERE type = 'U' AND username = pRoleName;

    IF found THEN
      UPDATE db.profile
         SET input_error = input_error + 1,
             input_error_last = now(),
             input_error_all = input_error_all + 1
       WHERE userid = up.id;

      SELECT input_error INTO nInputError FROM db.profile WHERE userid = up.id;

      IF found THEN
        IF nInputError >= 3 THEN
          PERFORM UserLock(up.id);
        END IF;
      END IF;

      INSERT INTO db.log (type, code, username, text)
      VALUES ('E', 3001, pRoleName, message);
    END IF;

    RETURN null;
  END;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SessionOut ------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Выход из системы по ключу сессии.
 * @param {text} pSession - Сессия
 * @param {boolean} pCloseAll - Закрыть все сессии
 * @param {text} pMessage - Сообщение
 * @return {void}
 */
CREATE OR REPLACE FUNCTION SessionOut (
  pSession      text,
  pCloseAll     boolean,
  pMessage      text DEFAULT null
) RETURNS 	    boolean
AS $$
DECLARE
  nUserId	    numeric;
  nCount	    integer;

  message	    text;
BEGIN
  IF ValidSession(pSession) THEN

    message := 'Выход из системы';

    SELECT userid INTO nUserId FROM db.session WHERE code = pSession;

	IF NOT CheckAccessControlList(B'00000000010', nUserId) THEN
	  PERFORM AccessDenied();
	END IF;

    IF pCloseAll THEN
      DELETE FROM db.session WHERE userid = nUserId;
      message := message || ' (с закрытием всех активных сессий)';
    ELSE
      DELETE FROM db.session WHERE code = pSession;
    END IF;

    SELECT count(code) INTO nCount FROM db.session WHERE userid = nUserId;

    IF nCount = 0 THEN
      UPDATE db.user SET status = set_bit(set_bit(status, 3, 1), 2, 0) WHERE id = nUserId;
    END IF;

    UPDATE db.profile SET state = B'000' WHERE userid = nUserId;

    message := message || coalesce('. ' || pMessage, '.');

    INSERT INTO db.log (type, code, username, session, text)
    VALUES ('M', 1002, GetUserName(nUserId), pSession, message);

    PERFORM SetErrorMessage(message);
    PERFORM SetCurrentSession(null);
    PERFORM SetCurrentUserId(null);

    RETURN true;
  END IF;

  RAISE EXCEPTION 'ERR-40000: %', GetErrorMessage();
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SignOut ---------------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Выход из системы по ключу сессии.
 * @param {text} pSession - Сессия
 * @param {boolean} pCloseAll - Закрыть все сессии
 * @return {void}
 */
CREATE OR REPLACE FUNCTION SignOut (
  pSession      text DEFAULT current_session(),
  pCloseAll     boolean DEFAULT false
) RETURNS       boolean
AS $$
DECLARE
  nUserId       numeric;
  message       text;
BEGIN
  RETURN SessionOut(pSession, pCloseAll);
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;

  PERFORM SetCurrentSession(null);
  PERFORM SetCurrentUserId(null);

  PERFORM SetErrorMessage(message);

  IF pSession IS NOT NULL THEN
	SELECT userid INTO nUserId FROM db.session WHERE code = pSession;

	IF found THEN
	  INSERT INTO db.log (type, code, username, session, text)
	  VALUES ('E', 3002, GetUserName(nUserId), pSession, 'Выход из системы. ' || message);
	END IF;
  END IF;

  RETURN false;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION Authenticate -------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * @brief Аутентификация.
 * @param {text} pSession - Сессия
 * @param {text} pSecret - Секретный код
 * @param {text} pAgent - Агент
 * @param {inet} pHost - IP адрес
 * @return {text} - Новый код аутентификации. Если вернёт null вызвать GetErrorMessage для просмотра сообщения об ошибке.
 */
CREATE OR REPLACE FUNCTION Authenticate (
  pSession      text,
  pSecret       text,
  pAgent        text DEFAULT null,
  pHost         inet DEFAULT null
)
RETURNS         text
AS $$
DECLARE
  vCode         text;
BEGIN
  IF ValidSecret(pSecret, pSession) THEN
    vCode := SessionIn(pSession, pAgent, pHost, gen_salt('md5'));
  ELSE
    PERFORM SessionOut(pSession, false, GetErrorMessage());
  END IF;

  RETURN vCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION Authorize ----------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Авторизовать.
 * @param {text} pSession - Сессия
 * @param {text} pAgent - Агент
 * @param {inet} pHost - IP адрес
 * @return {boolean} Если вернёт false вызвать GetErrorMessage для просмотра сообщения об ошибке.
 */
CREATE OR REPLACE FUNCTION Authorize (
  pSession      text,
  pAgent        text DEFAULT null,
  pHost         inet DEFAULT null
)
RETURNS         boolean
AS $$
BEGIN
  RETURN SessionIn(pSession, pAgent, pHost) IS NOT NULL;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetSession ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetSession (
  pUserId       numeric,
  pOAuth2       numeric DEFAULT CreateSystemOAuth2(),
  pAgent        text DEFAULT null,
  pHost         inet DEFAULT null,
  pNew          bool DEFAULT false
) RETURNS       text
AS $$
DECLARE
  up            db.user%rowtype;

  nArea         numeric;
  nInterface	numeric;

  nSUID         numeric;

  vSession      text;
BEGIN
  IF session_user <> 'kernel' THEN
    nSUID := coalesce(session_userid(), GetUser(session_user));
	IF NOT CheckAccessControlList(B'10000000000', nSUID) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  SELECT * INTO up FROM db.user WHERE id = pUserId;

  IF NOT found THEN
    PERFORM LoginError();
  END IF;

  IF get_bit(up.status, 1) = 1 THEN
    PERFORM UserLockError();
  END IF;

  IF up.lock_date IS NOT NULL AND up.lock_date <= now() THEN
    PERFORM UserLockError();
  END IF;

  IF get_bit(up.status, 0) = 1 THEN
    PERFORM PasswordExpired();
  END IF;

  IF up.expiry_date IS NOT NULL AND up.expiry_date <= now() THEN
    PERFORM PasswordExpired();
  END IF;

  IF NOT CheckIPTable(up.id, pHost) THEN
    PERFORM LoginIPTableError(pHost);
  END IF;

  SELECT code INTO vSession FROM db.session WHERE userid = up.id;

  IF NOT FOUND OR pNew THEN
    nArea := GetDefaultArea(up.id);
    nInterface := GetDefaultInterface(up.id);

    INSERT INTO db.session (oauth2, suid, userid, area, interface, agent, host)
    VALUES (pOAuth2, nSUID, up.id, nArea, nInterface, pAgent, pHost)
    RETURNING code INTO vSession;
  END IF;

  PERFORM SetCurrentSession(vSession);
  PERFORM SetCurrentUserId(up.id);

  RETURN vSession;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
