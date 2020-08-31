--------------------------------------------------------------------------------
-- OAUTH 2.0 -------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- oauth2.provider -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE oauth2.provider (
    id          numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    type        char NOT NULL,
    code        text NOT NULL,
    name        text,
    CONSTRAINT ch_provider_type CHECK (type IN ('I', 'E'))
);

COMMENT ON TABLE oauth2.provider IS 'Поставщик.';

COMMENT ON COLUMN oauth2.provider.id IS 'Идентификатор';
COMMENT ON COLUMN oauth2.provider.type IS 'Тип: "I" - внутренний; "E" - внешний';
COMMENT ON COLUMN oauth2.provider.code IS 'Код';
COMMENT ON COLUMN oauth2.provider.name IS 'Наименование';

CREATE UNIQUE INDEX ON oauth2.provider (type, code);

CREATE INDEX ON oauth2.provider (type);
CREATE INDEX ON oauth2.provider (code);
CREATE INDEX ON oauth2.provider (code text_pattern_ops);

--------------------------------------------------------------------------------
-- VIEW Provider ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Provider
AS
  SELECT * FROM oauth2.provider;

GRANT SELECT ON Provider TO administrator;

--------------------------------------------------------------------------------
-- AddProvider -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddProvider (
  pType		    char,
  pCode		    varchar,
  pName		    varchar DEFAULT null
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

  INSERT INTO oauth2.provider (type, code, name) VALUES (pType, pCode, pName)
  RETURNING Id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetProvider --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetProvider (
  pCode		varchar
) RETURNS 	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM oauth2.provider WHERE code = pCode;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetProviderCode ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetProviderCode (
  pId		numeric
) RETURNS 	text
AS $$
DECLARE
  vCode		text;
BEGIN
  SELECT code INTO vCode FROM oauth2.provider WHERE id = pId;
  RETURN vCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- oauth2.application ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE oauth2.application (
    id          numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    type        char NOT NULL,
    code        text NOT NULL,
    name        text,
    CONSTRAINT ch_application_type CHECK (type IN ('S', 'W', 'N'))
);

COMMENT ON TABLE oauth2.application IS 'Приложение.';

COMMENT ON COLUMN oauth2.application.id IS 'Идентификатор';
COMMENT ON COLUMN oauth2.application.type IS 'Тип: "S" - Сервис; "W" - Веб; "N" - Нативное';
COMMENT ON COLUMN oauth2.application.code IS 'Код';
COMMENT ON COLUMN oauth2.application.name IS 'Наименование';

CREATE UNIQUE INDEX ON oauth2.application (type, code);

CREATE INDEX ON oauth2.application (type);
CREATE INDEX ON oauth2.application (code);
CREATE INDEX ON oauth2.application (code text_pattern_ops);

--------------------------------------------------------------------------------
-- VIEW Application ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Application
AS
  SELECT * FROM oauth2.application;

GRANT SELECT ON Application TO administrator;

--------------------------------------------------------------------------------
-- AddApplication --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddApplication (
  pType		    char,
  pCode		    varchar,
  pName		    varchar DEFAULT null
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

  INSERT INTO oauth2.application (type, code, name) VALUES (pType, pCode, pName)
  RETURNING Id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetApplication -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetApplication (
  pCode		varchar
) RETURNS 	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM oauth2.application WHERE code = pCode;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetApplicationCode -------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetApplicationCode (
  pId		numeric
) RETURNS 	text
AS $$
DECLARE
  vCode		text;
BEGIN
  SELECT code INTO vCode FROM oauth2.application WHERE id = pId;
  RETURN vCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- oauth2.issuer ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE oauth2.issuer (
    id          numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    provider    numeric(12) NOT NULL,
    code        text NOT NULL,
    name        text,
    CONSTRAINT fk_issuer_provider FOREIGN KEY (provider) REFERENCES oauth2.provider(id)
);

COMMENT ON TABLE oauth2.issuer IS 'Издатель.';

COMMENT ON COLUMN oauth2.issuer.id IS 'Идентификатор';
COMMENT ON COLUMN oauth2.issuer.provider IS 'Поставщик';
COMMENT ON COLUMN oauth2.issuer.code IS 'Код';
COMMENT ON COLUMN oauth2.issuer.name IS 'Наименование';

CREATE UNIQUE INDEX ON oauth2.issuer (provider, code);

CREATE INDEX ON oauth2.issuer (provider);
CREATE INDEX ON oauth2.issuer (code);
CREATE INDEX ON oauth2.issuer (code text_pattern_ops);

--------------------------------------------------------------------------------
-- VIEW Issuer -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Issuer
AS
  SELECT * FROM oauth2.issuer;

GRANT SELECT ON Issuer TO administrator;

--------------------------------------------------------------------------------
-- AddIssuer -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddIssuer (
  pProvider     numeric,
  pCode		    varchar,
  pName		    varchar
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

  INSERT INTO oauth2.issuer (provider, code, name) VALUES (pProvider, pCode, pName)
  RETURNING Id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetIssuer ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetIssuer (
  pCode		varchar
) RETURNS 	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM oauth2.issuer WHERE code = pCode;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetIssuerCode ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetIssuerCode (
  pId		numeric
) RETURNS 	text
AS $$
DECLARE
  vCode		text;
BEGIN
  SELECT code INTO vCode FROM oauth2.issuer WHERE id = pId;
  RETURN vCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- oauth2.algorithm ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE oauth2.algorithm (
    id          numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    code        text NOT NULL,
    name        text
);

COMMENT ON TABLE oauth2.algorithm IS 'Алгоритмы хеширования.';

COMMENT ON COLUMN oauth2.algorithm.id IS 'Идентификатор';
COMMENT ON COLUMN oauth2.algorithm.code IS 'Код';
COMMENT ON COLUMN oauth2.algorithm.name IS 'Наименование (как в pgcrypto)';

CREATE INDEX ON oauth2.algorithm (code);

--------------------------------------------------------------------------------
-- VIEW Algorithm --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Algorithm
AS
  SELECT * FROM oauth2.algorithm;

GRANT SELECT ON Algorithm TO administrator;

--------------------------------------------------------------------------------
-- AddAlgorithm ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddAlgorithm (
  pCode		    varchar,
  pName		    varchar
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

  INSERT INTO oauth2.algorithm (code, name) VALUES (pCode, pName)
  RETURNING Id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetAlgorithm -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetAlgorithm (
  pCode		varchar
) RETURNS 	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM oauth2.algorithm WHERE code = pCode;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetAlgorithmCode ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetAlgorithmCode (
  pId		numeric
) RETURNS 	text
AS $$
DECLARE
  vCode		text;
BEGIN
  SELECT code INTO vCode FROM oauth2.algorithm WHERE id = pId;
  RETURN vCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetAlgorithmName ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetAlgorithmName (
  pId		numeric
) RETURNS 	text
AS $$
DECLARE
  vName		text;
BEGIN
  SELECT name INTO vName FROM oauth2.algorithm WHERE id = pId;
  RETURN vName;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- oauth2.audience -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE oauth2.audience (
    id          numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    provider    numeric(12) NOT NULL,
    application numeric(12) NOT NULL,
    algorithm   numeric(12) NOT NULL,
    code        text NOT NULL,
    secret      text NOT NULL,
    hash        text NOT NULL,
    name        text,
    CONSTRAINT fk_audience_provider FOREIGN KEY (provider) REFERENCES oauth2.provider(id),
    CONSTRAINT fk_audience_application FOREIGN KEY (application) REFERENCES oauth2.application(id)
);

COMMENT ON TABLE oauth2.audience IS 'Аудитория (Клиенты OAuth 2.0).';

COMMENT ON COLUMN oauth2.audience.id IS 'Идентификатор';
COMMENT ON COLUMN oauth2.audience.provider IS 'Поставщик';
COMMENT ON COLUMN oauth2.audience.application IS 'Приложение';
COMMENT ON COLUMN oauth2.audience.algorithm IS 'Алгоритм хеширования';
COMMENT ON COLUMN oauth2.audience.code IS 'Код';
COMMENT ON COLUMN oauth2.audience.secret IS 'Секрет';
COMMENT ON COLUMN oauth2.audience.hash IS 'Секрет (хеш)';
COMMENT ON COLUMN oauth2.audience.name IS 'Наименование';

CREATE UNIQUE INDEX ON oauth2.audience (provider, code);

CREATE INDEX ON oauth2.audience (provider);
CREATE INDEX ON oauth2.audience (code);
CREATE INDEX ON oauth2.audience (code text_pattern_ops);

--------------------------------------------------------------------------------
-- VIEW Audience ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Audience
AS
  SELECT * FROM oauth2.audience;

GRANT SELECT ON Audience TO administrator;

--------------------------------------------------------------------------------
-- CreateAudience --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CreateAudience (
  pProvider     numeric,
  pApplicaton   numeric,
  pAlgorithm    numeric,
  pCode         text,
  pSecret       text,
  pName         text DEFAULT null
) RETURNS       numeric
AS $$
DECLARE
  nId           numeric;
BEGIN
  IF session_user <> 'kernel' THEN
    IF NOT IsUserRole(GetGroup('administrator')) THEN
      PERFORM AccessDenied();
    END IF;
  END IF;

  INSERT INTO oauth2.audience (provider, application, algorithm, code, secret, hash, name)
  VALUES (pProvider, pApplicaton, pAlgorithm, pCode, pSecret, crypt(pSecret, gen_salt('md5')), pName)
  RETURNING Id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetAudience --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetAudience (
  pCode		varchar
) RETURNS 	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM oauth2.audience WHERE code = pCode;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetAudienceCode ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetAudienceCode (
  pId		numeric
) RETURNS 	text
AS $$
DECLARE
  vCode		text;
BEGIN
  SELECT code INTO vCode FROM oauth2.audience WHERE id = pId;
  RETURN vCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
