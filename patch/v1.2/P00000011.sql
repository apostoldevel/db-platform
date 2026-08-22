--------------------------------------------------------------------------------
-- db.oauth2_consent -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.oauth2_consent (
    id              bigserial PRIMARY KEY,
    userid          uuid NOT NULL REFERENCES db.user(id) ON DELETE CASCADE,
    audience        integer NOT NULL REFERENCES oauth2.audience(id) ON DELETE RESTRICT,
    scopes          text[] NOT NULL DEFAULT ARRAY[]::text[],
    created         timestamptz NOT NULL DEFAULT Now(),
    updated         timestamptz NOT NULL DEFAULT Now(),
    revoked         timestamptz
);

COMMENT ON TABLE db.oauth2_consent IS 'Record that a user granted an OAuth 2.0 client access to their account. An authorization code is handed to an already signed-in user only when a matching, unrevoked record exists — otherwise the consent screen is shown first.';

COMMENT ON COLUMN db.oauth2_consent.id IS 'Auto-increment identifier.';
COMMENT ON COLUMN db.oauth2_consent.userid IS 'User who granted the consent.';
COMMENT ON COLUMN db.oauth2_consent.audience IS 'OAuth 2.0 client (audience) the consent was granted to.';
COMMENT ON COLUMN db.oauth2_consent.scopes IS 'Scope codes the user granted. A request is covered when its scopes are a subset of these.';
COMMENT ON COLUMN db.oauth2_consent.created IS 'When the consent was first granted.';
COMMENT ON COLUMN db.oauth2_consent.updated IS 'When the consent was last granted or widened.';
COMMENT ON COLUMN db.oauth2_consent.revoked IS 'When the user withdrew the consent; NULL while it stands. Withdrawal stamps the row rather than deleting it — who granted what to whom, and when they took it back, is audit material. Deleting the client is likewise refused while consents reference it (ON DELETE RESTRICT); revoke them first.';

CREATE UNIQUE INDEX ON db.oauth2_consent (userid, audience);

CREATE INDEX ON db.oauth2_consent (audience);

--------------------------------------------------------------------------------
-- daemon.authorization_code ---------------------------------------------------
--------------------------------------------------------------------------------

-- The consent gate arrives as a new trailing parameter, so CREATE OR REPLACE
-- would not replace anything: a different argument count makes an *overload*,
-- and the old eight-argument function — the one that issues a code without
-- asking anyone — would stay callable next to the new one. Drop it explicitly.

DROP FUNCTION IF EXISTS daemon.authorization_code(varchar, text, text, text, text, text, text, inet);

--------------------------------------------------------------------------------
