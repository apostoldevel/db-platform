--------------------------------------------------------------------------------
-- OAUTH 2.0 -------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- oauth2.provider -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE oauth2.provider (
    id          serial PRIMARY KEY,
    type        char NOT NULL,
    code        text NOT NULL,
    name        text,
    CHECK (type IN ('I', 'E'))
);

COMMENT ON TABLE oauth2.provider IS 'OAuth 2.0 provider. Represents an internal or external identity provider used for authentication.';

COMMENT ON COLUMN oauth2.provider.id IS 'Primary key, auto-generated.';
COMMENT ON COLUMN oauth2.provider.type IS 'Provider kind: "I" — internal (platform itself); "E" — external (Google, Yandex, etc.).';
COMMENT ON COLUMN oauth2.provider.code IS 'Unique machine-readable identifier within the same type (e.g. "google", "yandex").';
COMMENT ON COLUMN oauth2.provider.name IS 'Human-readable display name.';

CREATE UNIQUE INDEX ON oauth2.provider (type, code);

CREATE INDEX ON oauth2.provider (type);
CREATE INDEX ON oauth2.provider (code);
CREATE INDEX ON oauth2.provider (code text_pattern_ops);

--------------------------------------------------------------------------------
-- oauth2.application ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE oauth2.application (
    id          serial PRIMARY KEY,
    type        char NOT NULL,
    code        text NOT NULL,
    name        text,
    CHECK (type IN ('S', 'W', 'N'))
);

COMMENT ON TABLE oauth2.application IS 'Registered client application. Each application represents an OAuth 2.0 client that may request tokens.';

COMMENT ON COLUMN oauth2.application.id IS 'Primary key, auto-generated.';
COMMENT ON COLUMN oauth2.application.type IS 'Application kind: "S" — service (machine-to-machine); "W" — web (browser-based); "N" — native (mobile/desktop).';
COMMENT ON COLUMN oauth2.application.code IS 'Unique machine-readable identifier within the same type.';
COMMENT ON COLUMN oauth2.application.name IS 'Human-readable display name.';

CREATE UNIQUE INDEX ON oauth2.application (type, code);

CREATE INDEX ON oauth2.application (type);
CREATE INDEX ON oauth2.application (code);
CREATE INDEX ON oauth2.application (code text_pattern_ops);

--------------------------------------------------------------------------------
-- oauth2.issuer ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE oauth2.issuer (
    id          serial PRIMARY KEY,
    provider    integer NOT NULL REFERENCES oauth2.provider,
    code        text NOT NULL,
    name        text
);

COMMENT ON TABLE oauth2.issuer IS 'JWT token issuer. Identifies who signs and issues tokens, scoped to a specific provider.';

COMMENT ON COLUMN oauth2.issuer.id IS 'Primary key, auto-generated.';
COMMENT ON COLUMN oauth2.issuer.provider IS 'Reference to the owning OAuth 2.0 provider.';
COMMENT ON COLUMN oauth2.issuer.code IS 'Unique issuer identifier within the provider (typically a URL, e.g. "https://accounts.google.com").';
COMMENT ON COLUMN oauth2.issuer.name IS 'Human-readable display name.';

CREATE UNIQUE INDEX ON oauth2.issuer (provider, code);

CREATE INDEX ON oauth2.issuer (provider);
CREATE INDEX ON oauth2.issuer (code);
CREATE INDEX ON oauth2.issuer (code text_pattern_ops);

--------------------------------------------------------------------------------
-- oauth2.algorithm ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE oauth2.algorithm (
    id          serial PRIMARY KEY,
    code        text NOT NULL,
    name        text
);

COMMENT ON TABLE oauth2.algorithm IS 'Hashing/signing algorithm. Used to specify how audience secrets are hashed and tokens are signed.';

COMMENT ON COLUMN oauth2.algorithm.id IS 'Primary key, auto-generated.';
COMMENT ON COLUMN oauth2.algorithm.code IS 'Short algorithm code (e.g. "HS256", "RS256").';
COMMENT ON COLUMN oauth2.algorithm.name IS 'Algorithm name as recognized by pgcrypto (e.g. "md5", "bf").';

CREATE INDEX ON oauth2.algorithm (code);

--------------------------------------------------------------------------------
-- oauth2.audience -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE oauth2.audience (
    id          serial PRIMARY KEY,
    provider    integer NOT NULL REFERENCES oauth2.provider,
    application integer NOT NULL REFERENCES oauth2.application,
    algorithm   integer NOT NULL,
    code        text NOT NULL,
    secret      text NOT NULL,
    hash        text NOT NULL,
    name        text
);

COMMENT ON TABLE oauth2.audience IS 'JWT audience (OAuth 2.0 client credentials). Binds a provider and application together with a client_id/client_secret pair.';

COMMENT ON COLUMN oauth2.audience.id IS 'Primary key, auto-generated.';
COMMENT ON COLUMN oauth2.audience.provider IS 'Reference to the OAuth 2.0 provider that authenticates this audience.';
COMMENT ON COLUMN oauth2.audience.application IS 'Reference to the client application this audience belongs to.';
COMMENT ON COLUMN oauth2.audience.algorithm IS 'Hashing algorithm used to produce the secret hash.';
COMMENT ON COLUMN oauth2.audience.code IS 'Client identifier (client_id), unique within the provider.';
COMMENT ON COLUMN oauth2.audience.secret IS 'Client secret in plain text (used for token signing/verification).';
COMMENT ON COLUMN oauth2.audience.hash IS 'Bcrypt/md5-crypt hash of the secret for credential verification.';
COMMENT ON COLUMN oauth2.audience.name IS 'Human-readable display name.';

CREATE UNIQUE INDEX ON oauth2.audience (provider, code);

CREATE INDEX ON oauth2.audience (provider);
CREATE INDEX ON oauth2.audience (code);
CREATE INDEX ON oauth2.audience (code text_pattern_ops);
