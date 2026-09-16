--------------------------------------------------------------------------------
-- GATEWAY SCHEMA --------------------------------------------------------------
--------------------------------------------------------------------------------
-- The database half of the GatewayAPI module (the /api/v2 gateway of track A):
-- the registry of module instances, their state journal, the NOTIFY that tells
-- every gateway worker about a transition, and the api.* wrappers a module
-- behind a connection pool calls. Design and contract: apostol-csms
-- `clean-architecture/track-a-gateway.md` §5 and `gateway-contract.md` — the
-- К-numbers in the comments below refer to that contract. Moved here from the
-- csms configuration (T301, 16.09.2026): the C++ module is public, so is its
-- schema. The module has no OAuth2 identity of its own: the /api/v2 modules
-- authenticate the control socket under the project's existing `service-<domain>`
-- audience (К3 ed. 5, owner's decision 16.09.2026).

CREATE SCHEMA IF NOT EXISTS gateway;

GRANT USAGE ON SCHEMA gateway TO kernel;
GRANT USAGE ON SCHEMA gateway TO administrator;
GRANT USAGE ON SCHEMA gateway TO daemon;
GRANT USAGE ON SCHEMA gateway TO apibot;

COMMENT ON SCHEMA gateway IS 'GatewayAPI, track A (track-a-gateway.md §5): the database mirror of the gateway''s module registry — which /api/v2 module instances exist, where they listen and in what state. Written by the GatewayAPI worker that owns the instance''s control socket, read by other applications through gateway.route.';
