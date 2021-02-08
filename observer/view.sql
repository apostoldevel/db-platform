--------------------------------------------------------------------------------
-- VIEW Publisher --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Publisher
AS
  SELECT * FROM db.publisher;

GRANT SELECT ON Publisher TO administrator;

--------------------------------------------------------------------------------
-- VIEW Listener ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Listener
AS
  SELECT * FROM db.listener;

GRANT SELECT ON Listener TO administrator;

