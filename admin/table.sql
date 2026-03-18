--------------------------------------------------------------------------------
-- db.scope --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.scope (
    id              uuid PRIMARY KEY DEFAULT gen_kernel_uuid('8'),
    code            text NOT NULL,
    name            text NOT NULL,
    description     text
);

COMMENT ON TABLE db.scope IS 'Database visibility scope for multi-tenant isolation.';

COMMENT ON COLUMN db.scope.id IS 'Unique identifier.';
COMMENT ON COLUMN db.scope.code IS 'Short unique code used in lookups and URLs.';
COMMENT ON COLUMN db.scope.name IS 'Human-readable display name.';
COMMENT ON COLUMN db.scope.description IS 'Free-text description of the scope purpose.';

CREATE UNIQUE INDEX ON db.scope (code);

--------------------------------------------------------------------------------
-- db.scope_alias --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.scope_alias (
    scope           uuid NOT NULL REFERENCES db.scope(id) ON DELETE CASCADE,
    code            text NOT NULL,
    PRIMARY KEY (scope, code)
);

COMMENT ON TABLE db.scope_alias IS 'Alternative code names that resolve to a given scope.';

COMMENT ON COLUMN db.scope_alias.scope IS 'Reference to the parent scope.';
COMMENT ON COLUMN db.scope_alias.code IS 'Alias code that maps to the scope.';

CREATE INDEX ON db.scope_alias (scope);
CREATE INDEX ON db.scope_alias (code);

--------------------------------------------------------------------------------
-- db.area_type ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.area_type (
    id        uuid PRIMARY KEY,
    code      text NOT NULL,
    name      text
);

COMMENT ON TABLE db.area_type IS 'Classifies functional areas (root, system, guest, default, etc.).';

COMMENT ON COLUMN db.area_type.id IS 'Unique identifier (well-known UUID).';
COMMENT ON COLUMN db.area_type.code IS 'Short unique code (e.g. root, system, guest).';
COMMENT ON COLUMN db.area_type.name IS 'Human-readable display name.';

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
    sequence        integer NOT NULL,
    validFromDate   timestamptz DEFAULT Now() NOT NULL,
    validToDate     timestamptz DEFAULT TO_DATE('4433-12-31', 'YYYY-MM-DD') NOT NULL
);

COMMENT ON TABLE db.area IS 'Functional area within a scope; forms a tree hierarchy for document visibility.';

COMMENT ON COLUMN db.area.id IS 'Unique identifier.';
COMMENT ON COLUMN db.area.parent IS 'Parent area forming the tree hierarchy; NULL for root nodes.';
COMMENT ON COLUMN db.area.type IS 'Area type (root, system, guest, default, etc.).';
COMMENT ON COLUMN db.area.scope IS 'Owning database scope.';
COMMENT ON COLUMN db.area.code IS 'Short unique code within the scope.';
COMMENT ON COLUMN db.area.name IS 'Human-readable display name.';
COMMENT ON COLUMN db.area.description IS 'Free-text description.';
COMMENT ON COLUMN db.area.level IS 'Nesting depth in the tree (0 = root).';
COMMENT ON COLUMN db.area.sequence IS 'Sort order among siblings.';
COMMENT ON COLUMN db.area.validFromDate IS 'Date from which the area is active.';
COMMENT ON COLUMN db.area.validToDate IS 'Date after which the area is inactive.';

CREATE INDEX ON db.area (parent);
CREATE INDEX ON db.area (type);
CREATE INDEX ON db.area (scope);

CREATE UNIQUE INDEX ON db.area (scope, code);

--------------------------------------------------------------------------------

/**
 * @brief Populate defaults for a new area row before insert.
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION db.ft_area_before_insert()
RETURNS    trigger AS $$
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

COMMENT ON TABLE db.interface IS 'UI / workspace interface that users can be assigned to.';

COMMENT ON COLUMN db.interface.id IS 'Unique identifier.';
COMMENT ON COLUMN db.interface.code IS 'Short unique code (e.g. administrator, operator, guest).';
COMMENT ON COLUMN db.interface.name IS 'Human-readable display name.';
COMMENT ON COLUMN db.interface.description IS 'Free-text description.';

--------------------------------------------------------------------------------
-- db.user ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.user (
    id                  uuid PRIMARY KEY,
    type                char NOT NULL CHECK (type IN ('G', 'U')),
    username            text NOT NULL,
    name                text NOT NULL,
    phone               text,
    email               text,
    description         text,
    secret              bytea NOT NULL,
    hash                text NOT NULL,
    status              bit(4) DEFAULT B'0001' NOT NULL,
    created             timestamptz DEFAULT Now() NOT NULL,
    lock_date           timestamptz DEFAULT NULL,
    expiry_date         timestamptz DEFAULT NULL,
    pswhash             text DEFAULT NULL,
    passwordchange      boolean DEFAULT true NOT NULL,
    passwordnotchange   boolean DEFAULT false NOT NULL,
    readonly            boolean DEFAULT false NOT NULL
);

COMMENT ON TABLE db.user IS 'User accounts and groups; type distinguishes individual users from groups.';

COMMENT ON COLUMN db.user.id IS 'Unique identifier.';
COMMENT ON COLUMN db.user.type IS 'Account type: U = user, G = group.';
COMMENT ON COLUMN db.user.username IS 'Login name (unique per type).';
COMMENT ON COLUMN db.user.name IS 'Full display name.';
COMMENT ON COLUMN db.user.phone IS 'Phone number (unique, E.164 recommended).';
COMMENT ON COLUMN db.user.email IS 'Email address (unique).';
COMMENT ON COLUMN db.user.description IS 'Free-text description of the account.';
COMMENT ON COLUMN db.user.secret IS 'Random 64-byte secret used for HMAC-based hashing.';
COMMENT ON COLUMN db.user.hash IS 'SHA-1 fingerprint derived from the secret; used for token signing.';
COMMENT ON COLUMN db.user.status IS 'Bitmask: bit 0 = password expired, bit 1 = locked, bit 2 = active, bit 3 = open.';
COMMENT ON COLUMN db.user.created IS 'Timestamp when the account was created.';
COMMENT ON COLUMN db.user.lock_date IS 'Timestamp when the account was locked (NULL = not locked).';
COMMENT ON COLUMN db.user.expiry_date IS 'Password expiration date (NULL = never expires).';
COMMENT ON COLUMN db.user.pswhash IS 'Bcrypt hash of the password.';
COMMENT ON COLUMN db.user.passwordchange IS 'Force password change on next login.';
COMMENT ON COLUMN db.user.passwordnotchange IS 'Prohibit the user from changing their own password.';
COMMENT ON COLUMN db.user.readonly IS 'Read-only flag; prevents modification of system accounts.';

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

/**
 * @brief Generate defaults for a new user row (id, secret, hash, phone, readonly).
 * @since 1.0.0
 */
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
   SET search_path = kernel, public, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_user_before_insert
  BEFORE INSERT ON db.user
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_user_before_insert();

--------------------------------------------------------------------------------

/**
 * @brief Assign default ACL permissions based on the well-known username after insert.
 * @since 1.0.0
 */
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

/**
 * @brief Reset verification flags when email or phone changes.
 * @since 1.0.0
 */
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

/**
 * @brief Cascade-delete IP table and profile rows before removing a user.
 * @since 1.0.0
 */
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
    userId              uuid NOT NULL REFERENCES db.user(id) ON DELETE CASCADE,
    scope               uuid NOT NULL REFERENCES db.scope(id) ON DELETE RESTRICT,
    family_name         text,
    given_name          text,
    patronymic_name     text,
    input_count         integer DEFAULT 0 NOT NULL,
    input_last          timestamptz DEFAULT NULL,
    input_error         integer DEFAULT 0 NOT NULL,
    input_error_last    timestamptz DEFAULT NULL,
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

COMMENT ON TABLE db.profile IS 'Per-scope profile extending the user account with preferences and login statistics.';

COMMENT ON COLUMN db.profile.userid IS 'Owning user account.';
COMMENT ON COLUMN db.profile.scope IS 'Database scope this profile belongs to.';
COMMENT ON COLUMN db.profile.family_name IS 'Family (last) name.';
COMMENT ON COLUMN db.profile.given_name IS 'Given (first) name.';
COMMENT ON COLUMN db.profile.patronymic_name IS 'Patronymic (middle) name.';
COMMENT ON COLUMN db.profile.input_count IS 'Total successful login count.';
COMMENT ON COLUMN db.profile.input_last IS 'Timestamp of the last successful login.';
COMMENT ON COLUMN db.profile.input_error IS 'Consecutive failed login attempts (resets on success).';
COMMENT ON COLUMN db.profile.input_error_last IS 'Timestamp of the last failed login attempt.';
COMMENT ON COLUMN db.profile.input_error_all IS 'Cumulative failed login count (never resets).';
COMMENT ON COLUMN db.profile.lc_ip IS 'IP address of the last connection.';
COMMENT ON COLUMN db.profile.locale IS 'Default locale for this profile.';
COMMENT ON COLUMN db.profile.area IS 'Default functional area for this profile.';
COMMENT ON COLUMN db.profile.interface IS 'Default workspace interface for this profile.';
COMMENT ON COLUMN db.profile.state IS 'Connection state bitmask: bit 0 = trusted IP, bit 1 = local IP, bit 2 = external IP.';
COMMENT ON COLUMN db.profile.session_limit IS 'Maximum concurrent sessions allowed (0 = unlimited).';
COMMENT ON COLUMN db.profile.email_verified IS 'Whether the email address has been verified.';
COMMENT ON COLUMN db.profile.phone_verified IS 'Whether the phone number has been verified.';
COMMENT ON COLUMN db.profile.picture IS 'URL or path to the user avatar image.';

--------------------------------------------------------------------------------

/**
 * @brief Validate area/interface membership and auto-assign scope on profile insert/update.
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION db.ft_profile_before()
RETURNS trigger AS $$
BEGIN
  IF (TG_OP = 'UPDATE') THEN

    IF NEW.area IS DISTINCT FROM OLD.area THEN
      IF NOT IsMemberArea(NEW.area, NEW.userid) THEN
        PERFORM UserNotMemberArea(GetUserName(NEW.userid), GetAreaName(NEW.area));
      END IF;
    END IF;

    IF OLD.interface IS DISTINCT FROM NEW.interface THEN
      IF NOT IsMemberInterface(NEW.interface, NEW.userid) THEN
        PERFORM UserNotMemberInterface(GetUserName(NEW.userid), GetInterfaceName(NEW.interface));
      END IF;
    END IF;

    IF OLD.scope IS DISTINCT FROM NEW.scope THEN
      SELECT scope INTO NEW.scope FROM db.area WHERE id = NEW.area;
    END IF;

  ELSE

    IF NEW.locale IS NULL THEN
      SELECT id INTO NEW.locale FROM db.locale WHERE code = locale_code();
    END IF;

    IF NOT IsMemberArea(NEW.area, NEW.userid) THEN
      INSERT INTO db.member_area (area, member) VALUES (NEW.area, NEW.userid) ON CONFLICT DO NOTHING;
    END IF;

    IF NOT IsMemberInterface(NEW.interface, NEW.userid) THEN
      INSERT INTO db.member_interface (interface, member) VALUES (NEW.interface, NEW.userid) ON CONFLICT DO NOTHING;
    END IF;

    IF NEW.scope IS NULL THEN
      SELECT scope INTO NEW.scope FROM db.area WHERE id = NEW.area;
    ELSE
      PERFORM FROM db.area WHERE id = NEW.area AND scope = NEW.scope;
      IF NOT FOUND THEN
        RAISE EXCEPTION 'ERR-40000: Area "% (%)" not present in scope "% (%)".', NEW.area, GetAreaName(NEW.area), NEW.scope, GetScopeName(NEW.scope);
      END IF;
    END IF;

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

/**
 * @brief Compute the connection state bitmask (trusted/local/external IP) after login timestamp changes.
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION db.ft_profile_login_state()
RETURNS trigger AS $$
DECLARE
  i         int;

  arrIp     text[];

  lHost     inet;

  nRange    int;

  vCode     text;

  nOnLine   int;
  nLocal    int;
  nTrust    int;

  bSuccess  boolean;

  uUserId   uuid;

  vData     Variant;

  r         record;
BEGIN
  uUserId := current_userid();

  IF uUserId IS NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.lc_ip IS NULL THEN
    RETURN NEW;
  END IF;

  nOnLine := 0;
  nLocal := 0;
  nTrust := 0;

  NEW.state := B'000';

  FOR r IN SELECT area, host FROM db.session WHERE userid = uUserId AND host = NEW.lc_ip
  LOOP

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
  WHEN (OLD.input_last IS DISTINCT FROM NEW.input_last)
  EXECUTE PROCEDURE db.ft_profile_login_state();

--------------------------------------------------------------------------------
-- member_group ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.member_group (
    userid        uuid NOT NULL REFERENCES db.user(id),
    member        uuid NOT NULL REFERENCES db.user(id),
    PRIMARY KEY (userid, member)
);

COMMENT ON TABLE db.member_group IS 'Many-to-many membership of users/groups in groups (role assignment).';

COMMENT ON COLUMN db.member_group.userid IS 'Group that the member belongs to.';
COMMENT ON COLUMN db.member_group.member IS 'User or group that is a member.';

CREATE INDEX ON db.member_group (userid);
CREATE INDEX ON db.member_group (member);

--------------------------------------------------------------------------------
-- db.member_area --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.member_area (
    area        uuid NOT NULL REFERENCES db.area(id),
    member      uuid NOT NULL REFERENCES db.user(id),
    PRIMARY KEY (area, member)
);

COMMENT ON TABLE db.member_area IS 'Many-to-many membership granting users/groups access to functional areas.';

COMMENT ON COLUMN db.member_area.area IS 'Functional area being granted.';
COMMENT ON COLUMN db.member_area.member IS 'User or group receiving access.';

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

COMMENT ON TABLE db.member_interface IS 'Many-to-many membership granting users/groups access to interfaces.';

COMMENT ON COLUMN db.member_interface.interface IS 'Interface being granted.';
COMMENT ON COLUMN db.member_interface.member IS 'User or group receiving access.';

CREATE INDEX ON db.member_interface (interface);
CREATE INDEX ON db.member_interface (member);

--------------------------------------------------------------------------------
-- RECOVERY TICKET -------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.recovery_ticket ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.recovery_ticket (
    ticket          uuid PRIMARY KEY,
    userId          uuid NOT NULL,
    securityAnswer  text NOT NULL,
    initiator       text NOT NULL,
    used            timestamptz,
    attempts        int NOT NULL DEFAULT 0,
    validFromDate   timestamptz NOT NULL,
    validToDate     timestamptz NOT NULL
);

COMMENT ON TABLE db.recovery_ticket IS 'Time-limited ticket for password recovery or registration verification.';

COMMENT ON COLUMN db.recovery_ticket.ticket IS 'Unique ticket identifier (UUID).';
COMMENT ON COLUMN db.recovery_ticket.userId IS 'User account the ticket was issued for.';
COMMENT ON COLUMN db.recovery_ticket.securityAnswer IS 'Hashed security answer or verification code.';
COMMENT ON COLUMN db.recovery_ticket.initiator IS 'SHA-1 hash of the initiator identifier (email or phone).';
COMMENT ON COLUMN db.recovery_ticket.used IS 'Timestamp when the ticket was consumed (NULL = unused).';
COMMENT ON COLUMN db.recovery_ticket.validFromDate IS 'Start of the ticket validity period.';
COMMENT ON COLUMN db.recovery_ticket.validToDate IS 'End of the ticket validity period.';

--------------------------------------------------------------------------------

CREATE UNIQUE INDEX ON db.recovery_ticket (userid, validFromDate, validToDate);
CREATE INDEX ON db.recovery_ticket (initiator, validFromDate, validToDate);

--------------------------------------------------------------------------------

/**
 * @brief Enforce immutability of securityAnswer on update; auto-generate ticket UUID and validity dates on insert.
 * @since 1.0.0
 */
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
   SET search_path = db, kernel, public, pg_temp;

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
    created     timestamptz DEFAULT Now() NOT NULL,
    PRIMARY KEY (userId, audience)
);

COMMENT ON TABLE db.auth IS 'External identity provider links (OAuth 2.0 federated login).';

COMMENT ON COLUMN db.auth.userId IS 'Local user account.';
COMMENT ON COLUMN db.auth.audience IS 'OAuth 2.0 audience (client application).';
COMMENT ON COLUMN db.auth.code IS 'External user identifier from the identity provider.';
COMMENT ON COLUMN db.auth.created IS 'Timestamp when the link was created.';

CREATE INDEX ON db.auth (userId);
CREATE INDEX ON db.auth (audience);
CREATE INDEX ON db.auth (code);

--------------------------------------------------------------------------------
-- TABLE db.iptable ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.iptable (
    id          serial PRIMARY KEY,
    type        char DEFAULT 'A' NOT NULL CHECK (type IN ('A', 'D')),
    userid      uuid NOT NULL REFERENCES db.user(id),
    addr        inet NOT NULL,
    range       int CHECK (range BETWEEN 1 AND 255)
);

COMMENT ON TABLE db.iptable IS 'Per-user IP allow/deny list for login access control.';

COMMENT ON COLUMN db.iptable.id IS 'Auto-increment identifier.';
COMMENT ON COLUMN db.iptable.type IS 'Rule type: A = allow, D = deny.';
COMMENT ON COLUMN db.iptable.userid IS 'User account this rule applies to.';
COMMENT ON COLUMN db.iptable.addr IS 'IP address or network (CIDR notation).';
COMMENT ON COLUMN db.iptable.range IS 'Address range size (1-255); NULL means single host or CIDR mask.';

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

COMMENT ON TABLE db.oauth2 IS 'OAuth 2.0 authorization parameters for a login session.';

COMMENT ON COLUMN db.oauth2.id IS 'Auto-increment identifier.';
COMMENT ON COLUMN db.oauth2.audience IS 'OAuth 2.0 client (audience) reference.';
COMMENT ON COLUMN db.oauth2.scopes IS 'Requested scope codes array.';
COMMENT ON COLUMN db.oauth2.access_type IS 'Access type: online (no refresh token) or offline (with refresh token).';
COMMENT ON COLUMN db.oauth2.redirect_uri IS 'OAuth 2.0 redirect URI for the authorization flow.';
COMMENT ON COLUMN db.oauth2.state IS 'Opaque state parameter passed through the authorization flow.';

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

COMMENT ON TABLE db.token_header IS 'Groups related tokens (code, access, refresh, id) under one header per session.';

COMMENT ON COLUMN db.token_header.id IS 'Auto-increment identifier.';
COMMENT ON COLUMN db.token_header.oauth2 IS 'OAuth 2.0 authorization parameters reference.';
COMMENT ON COLUMN db.token_header.session IS 'Session code this token set belongs to.';
COMMENT ON COLUMN db.token_header.salt IS 'Random salt used for key derivation.';
COMMENT ON COLUMN db.token_header.agent IS 'Client application (User-Agent).';
COMMENT ON COLUMN db.token_header.host IS 'Client IP address at token creation.';
COMMENT ON COLUMN db.token_header.created IS 'Timestamp when the header was created.';
COMMENT ON COLUMN db.token_header.updated IS 'Timestamp of the last token refresh.';

CREATE INDEX ON db.token_header (oauth2);
CREATE INDEX ON db.token_header (session);

--------------------------------------------------------------------------------
-- FUNCTION ft_token_header_before_delete --------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Cascade-delete all tokens before removing a token header.
 * @since 1.0.0
 */
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
    type            char NOT NULL CHECK (type IN ('C', 'A', 'R', 'I')),
    token           text NOT NULL,
    hash            varchar(40) NOT NULL,
    used            timestamptz,
    validFromDate   timestamptz DEFAULT Now() NOT NULL,
    validToDate     timestamptz DEFAULT TO_DATE('4433-12-31', 'YYYY-MM-DD') NOT NULL
);

COMMENT ON TABLE db.token IS 'OAuth 2.0 tokens with temporal validity ranges.';

COMMENT ON COLUMN db.token.id IS 'Auto-increment identifier.';
COMMENT ON COLUMN db.token.header IS 'Parent token header grouping related tokens.';
COMMENT ON COLUMN db.token.type IS 'Token type: C = authorization code, A = access token, R = refresh token, I = id token.';
COMMENT ON COLUMN db.token.token IS 'Token value (JWT or opaque string).';
COMMENT ON COLUMN db.token.hash IS 'HMAC-SHA1 hash of the token for secure lookup.';
COMMENT ON COLUMN db.token.used IS 'Timestamp when a one-time token was consumed (NULL = unused).';
COMMENT ON COLUMN db.token.validFromDate IS 'Start of the token validity period.';
COMMENT ON COLUMN db.token.validToDate IS 'End of the token validity period.';

CREATE UNIQUE INDEX ON db.token (hash, validFromDate, validToDate);
CREATE UNIQUE INDEX ON db.token (header, type, validFromDate, validToDate);

CREATE INDEX ON db.token (header);
CREATE INDEX ON db.token (type);
CREATE INDEX ON db.token (hash);
CREATE INDEX ON db.token (used);

--------------------------------------------------------------------------------
-- FUNCTION ft_token_before ----------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Enforce immutability of header/type on update; compute hash and default validity on insert.
 * @since 1.0.0
 */
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
    scope       uuid NOT NULL REFERENCES db.scope(id),
    oper_date   timestamptz DEFAULT NULL,
    created     timestamptz DEFAULT Now() NOT NULL,
    updated     timestamptz DEFAULT Now() NOT NULL,
    pwkey       text NOT NULL,
    secret      text NOT NULL,
    salt        text NOT NULL,
    agent       text NOT NULL,
    host        inet
);

COMMENT ON TABLE db.session IS 'Active user sessions with authentication keys and current context.';

COMMENT ON COLUMN db.session.code IS 'Session key (HMAC-SHA1 hash); serves as primary identifier.';
COMMENT ON COLUMN db.session.oauth2 IS 'OAuth 2.0 authorization parameters for this session.';
COMMENT ON COLUMN db.session.token IS 'Current authorization code token id.';
COMMENT ON COLUMN db.session.suid IS 'Original (session-owner) user id; unchanged by substitute-user.';
COMMENT ON COLUMN db.session.userid IS 'Effective user id (may differ from suid after substitute-user).';
COMMENT ON COLUMN db.session.locale IS 'Active locale for this session.';
COMMENT ON COLUMN db.session.area IS 'Active functional area for this session.';
COMMENT ON COLUMN db.session.interface IS 'Active workspace interface for this session.';
COMMENT ON COLUMN db.session.scope IS 'Active database scope for this session.';
COMMENT ON COLUMN db.session.oper_date IS 'Business operation date override (NULL = use current timestamp).';
COMMENT ON COLUMN db.session.created IS 'Timestamp when the session was created.';
COMMENT ON COLUMN db.session.updated IS 'Timestamp of the last session activity.';
COMMENT ON COLUMN db.session.pwkey IS 'Bcrypt hash of the session key material for validation.';
COMMENT ON COLUMN db.session.salt IS 'Random salt for authentication key rotation.';
COMMENT ON COLUMN db.session.agent IS 'Client application (User-Agent or application_name).';
COMMENT ON COLUMN db.session.host IS 'Client IP address.';

CREATE UNIQUE INDEX ON db.session (token);
CREATE UNIQUE INDEX ON db.session (oauth2);

CREATE INDEX ON db.session (suid);
CREATE INDEX ON db.session (userid);
CREATE INDEX ON db.session (scope);
CREATE INDEX ON db.session (created);
CREATE INDEX ON db.session (updated);
CREATE INDEX ON db.session (agent);

--------------------------------------------------------------------------------
-- FUNCTION ft_session_before --------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Manage session lifecycle: generate keys on insert, validate changes on update, clean up on delete.
 * @since 1.0.0
 */
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

    -- Rotate salt when session idle for more than 1 hour
    IF (NEW.updated - OLD.updated) > INTERVAL '1 hour' THEN
      NEW.salt := gen_salt('bf');
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

    IF OLD.scope IS DISTINCT FROM NEW.scope THEN
      PERFORM FROM db.area WHERE id = NEW.area AND scope = NEW.scope;
      IF NOT FOUND THEN
        NEW.scope := OLD.scope;
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

    NEW.salt := gen_salt('bf');

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
      PERFORM UserNotMemberArea(GetUserName(NEW.userid), GetAreaName(NEW.area));
    END IF;

    IF NEW.interface IS NULL THEN
      NEW.interface := GetDefaultInterface(NEW.userid);
    END IF;

    IF NOT IsMemberInterface(NEW.interface, NEW.userid) THEN
      PERFORM UserNotMemberInterface(GetUserName(NEW.userid), GetInterfaceName(NEW.interface));
    END IF;

    IF NEW.scope IS NULL THEN
      SELECT scope INTO NEW.scope FROM db.area WHERE id = NEW.area;
    ELSE
      PERFORM FROM db.area WHERE id = NEW.area AND scope = NEW.scope;
      IF NOT FOUND THEN
        RAISE EXCEPTION 'Area "% (%)" not present in scope "% (%)".', NEW.area, GetAreaName(NEW.area), NEW.scope, GetScopeName(NEW.scope);
      END IF;
    END IF;

    RETURN NEW;
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = db, kernel, public, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_session_before
  BEFORE INSERT OR UPDATE OR DELETE ON db.session
  FOR EACH ROW EXECUTE PROCEDURE db.ft_session_before();

--------------------------------------------------------------------------------
-- FUNCTION ft_session_after ---------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Clean up token headers on delete; update current user id on userid change.
 * @since 1.0.0
 */
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
 Access control bitmask (14 bits, MSB first):
   13: s - substitute user
   12: L - unlock user
   11: l - lock user
   10: E - exclude user from group
   09: I - include user to group
   08: D - delete group
   07: U - update group
   06: C - create group
   05: p - set user password
   04: d - delete user
   03: u - update user
   02: c - create user
   01: o - logout
   00: i - login
 */
CREATE TABLE db.acl (
    userId      uuid REFERENCES db.user ON DELETE CASCADE,
    deny        bit varying NOT NULL,
    allow       bit varying NOT NULL,
    mask        bit varying NOT NULL,
    PRIMARY KEY (userId)
);

COMMENT ON TABLE db.acl IS 'Access control list defining per-user administrative privilege bitmasks.';

COMMENT ON COLUMN db.acl.userid IS 'User or group this ACL entry applies to.';
COMMENT ON COLUMN db.acl.deny IS 'Deny bitmask (14 bits); set bits revoke the corresponding privilege.';
COMMENT ON COLUMN db.acl.allow IS 'Allow bitmask (14 bits); set bits grant the corresponding privilege.';
COMMENT ON COLUMN db.acl.mask IS 'Effective bitmask computed as (allow AND NOT deny).';

--------------------------------------------------------------------------------

/**
 * @brief Compute the effective access mask as (allow AND NOT deny) before insert or update.
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION db.ft_acl_before()
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
  EXECUTE PROCEDURE db.ft_acl_before();
