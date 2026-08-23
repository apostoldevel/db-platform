--------------------------------------------------------------------------------
-- oauth2.provider_claim --------------------------------------------------------
--------------------------------------------------------------------------------

-- daemon.login used to read one provider's claim names inline: an IF on the
-- provider code, and Google's field names spelled out inside it. Every other
-- external provider fell through to the else, which set nothing but the
-- subject -- no address, no name, no locale. Adding a second provider meant
-- adding a second branch.
--
-- The names now come from this table, and a provider with no row here is read
-- by the OpenID Connect names. Those are exactly the names the removed branch
-- spelled out, so Google keeps working with the table empty and no row needs to
-- be seeded for it -- by the platform, which does not create providers, or by
-- the project, which does.
--
-- The other column is email_trusted, and it is not cosmetic. daemon.login
-- reaches an existing account by e-mail address only where the provider
-- confirmed that address; a provider that sends no email_verified claim at all
-- -- Yandex sends none -- would otherwise never be able to link a person to the
-- account they already own. The flag says the provider verifies addresses
-- itself. It is what lets a token reach an existing account, so it belongs only
-- to a provider that earns it.

CREATE TABLE IF NOT EXISTS oauth2.provider_claim (
    provider      integer PRIMARY KEY REFERENCES oauth2.provider(id) ON DELETE CASCADE,
    claims        jsonb NOT NULL,
    email_trusted boolean NOT NULL DEFAULT false,
    updated       timestamptz NOT NULL DEFAULT Now()
);

-- CREATE TABLE IF NOT EXISTS is silent about a table that exists with different
-- columns, and this table is arriving from a project that had already written
-- it. Say so loudly instead of letting daemon.login find a column that is not
-- there at the next login.

DO $$
DECLARE
  missing text;
BEGIN
  SELECT string_agg(c, ', ') INTO missing
    FROM unnest(ARRAY['provider', 'claims', 'email_trusted', 'updated']) AS c
   WHERE NOT EXISTS (
     SELECT FROM information_schema.columns
      WHERE table_schema = 'oauth2' AND table_name = 'provider_claim' AND column_name = c);

  IF missing IS NOT NULL THEN
    RAISE EXCEPTION 'oauth2.provider_claim exists without the columns: %', missing
      USING HINT = 'Reconcile it by hand before this patch is recorded as applied.';
  END IF;
END $$;

COMMENT ON TABLE oauth2.provider_claim IS 'Claim mapping for an external identity provider. A provider with no row here is read by the OpenID Connect claim names, which is correct for every provider that follows the specification.';

COMMENT ON COLUMN oauth2.provider_claim.provider IS 'External provider this rule belongs to.';
COMMENT ON COLUMN oauth2.provider_claim.claims IS 'Mapping {"<account field>": "<claim name in the token>"}, e.g. {"email": "default_email", "given_name": "first_name"}. Only the fields whose names differ from the OpenID Connect ones need an entry.';
COMMENT ON COLUMN oauth2.provider_claim.email_trusted IS 'Whether an address from this provider counts as verified when the token carries no email_verified claim of its own. Yandex, for one, never sends that claim; without this flag its users can never be linked to an existing account by address. Turn it on only for a provider that verifies the address itself — it is what allows a token to reach an account that already exists.';
COMMENT ON COLUMN oauth2.provider_claim.updated IS 'When the rule was last changed.';

--------------------------------------------------------------------------------
-- Carry over a project's own copy -----------------------------------------------
--------------------------------------------------------------------------------

-- The project this comes from kept the mapping in db.provider_claim, keyed by
-- the provider's code. Upstream it is keyed by the provider's id and carries a
-- foreign key, because a text code with nothing holding it drifts: rename a
-- provider and the rule is orphaned, the mapping silently falls back to the
-- OpenID Connect names, and for a provider whose names differ that is the loss
-- of the address with no error anywhere.
--
-- Rows whose code names no provider are left where they are rather than
-- dropped: this patch does not get to decide that somebody's data is garbage.
-- The old table is not dropped either -- the project's configuration layer
-- creates it, and dropping it here would only have it recreated later in the
-- same migrate run. Removing it belongs in the same change that removes the
-- project's own copy of daemon.login.

DO $$
BEGIN
  IF EXISTS (SELECT FROM information_schema.tables
              WHERE table_schema = 'db' AND table_name = 'provider_claim') THEN

    INSERT INTO oauth2.provider_claim (provider, claims, updated)
    SELECT p.id, o.claims, o.updated
      FROM db.provider_claim o INNER JOIN oauth2.provider p ON p.code = o.provider
    ON CONFLICT (provider) DO NOTHING;

    RAISE NOTICE 'oauth2.provider_claim: carried over % of % rule(s) from db.provider_claim',
      (SELECT count(*) FROM db.provider_claim o INNER JOIN oauth2.provider p ON p.code = o.provider),
      (SELECT count(*) FROM db.provider_claim);

    -- A rule whose code names no provider cannot be carried across a foreign
    -- key, and a rule that quietly fails to arrive is the failure this table
    -- was keyed by id to prevent. Name them.
    IF EXISTS (SELECT FROM db.provider_claim o
                WHERE NOT EXISTS (SELECT FROM oauth2.provider p WHERE p.code = o.provider)) THEN
      RAISE NOTICE 'oauth2.provider_claim: left behind, no such provider: %',
        (SELECT string_agg(o.provider, ', ') FROM db.provider_claim o
          WHERE NOT EXISTS (SELECT FROM oauth2.provider p WHERE p.code = o.provider));
      RAISE NOTICE 'oauth2.provider_claim: write those rules again after AddProvider, which is the order the foreign key asks for';
    END IF;

    RAISE NOTICE 'db.provider_claim is left in place: drop it together with the project''s own copy of daemon.login';
  END IF;
END $$;

--------------------------------------------------------------------------------
-- What a project must check ----------------------------------------------------
--------------------------------------------------------------------------------

-- A project carrying its own copy of daemon.login must delete it in the same
-- change that takes this version. migrate.sh applies patches, then
-- platform/update.psql, then configuration/update.psql -- so the copy is
-- recreated after the generalised one, with the same signature, and replaces
-- it. Nothing fails; the login simply goes on behaving the way it did.
--
-- email_trusted starts false for every provider, including any rule carried
-- over above. A provider that sends no email_verified claim therefore stops
-- linking to existing accounts until the flag is set for it -- which is the
-- safe direction, and deliberate: the flag is a statement about the provider
-- that only the deployment can make.
