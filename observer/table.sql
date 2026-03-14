--------------------------------------------------------------------------------
-- OBSERVER --------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.publisher ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.publisher (
    code        text PRIMARY KEY,
    name        text NOT NULL,
    description text
);

COMMENT ON TABLE db.publisher IS 'Named event source (pub/sub channel) that listeners can subscribe to.';

COMMENT ON COLUMN db.publisher.code IS 'Unique publisher code used as the NOTIFY channel name.';
COMMENT ON COLUMN db.publisher.name IS 'Human-readable display name.';
COMMENT ON COLUMN db.publisher.description IS 'Optional description of the events this publisher emits.';

--------------------------------------------------------------------------------
-- db.listener -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.listener (
    publisher   text NOT NULL REFERENCES db.publisher(code) ON DELETE RESTRICT,
    session     varchar(40) NOT NULL REFERENCES db.session(code) ON DELETE CASCADE,
    identity    text NOT NULL,
    filter		jsonb NOT NULL,
    params		jsonb NOT NULL,
    PRIMARY KEY (publisher, session, identity)
);

COMMENT ON TABLE db.listener IS 'Subscriber bound to a publisher within a session, with optional JSON filter and delivery params.';

COMMENT ON COLUMN db.listener.publisher IS 'Publisher code (FK to db.publisher).';
COMMENT ON COLUMN db.listener.session IS 'Session code that owns this subscription (FK to db.session).';
COMMENT ON COLUMN db.listener.identity IS 'Logical subscription name within the session (default: main).';
COMMENT ON COLUMN db.listener.filter IS 'JSON criteria that incoming events must match (empty object = accept all).';
COMMENT ON COLUMN db.listener.params IS 'Delivery parameters: type (notify/object/mixed/hook) and optional hook config.';
