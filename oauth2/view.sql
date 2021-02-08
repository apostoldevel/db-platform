--------------------------------------------------------------------------------
-- VIEW Provider ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Provider
AS
  SELECT * FROM oauth2.provider;

GRANT SELECT ON Provider TO administrator;

--------------------------------------------------------------------------------
-- VIEW Application ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Application
AS
  SELECT * FROM oauth2.application;

GRANT SELECT ON Application TO administrator;

--------------------------------------------------------------------------------
-- VIEW Issuer -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Issuer
AS
  SELECT * FROM oauth2.issuer;

GRANT SELECT ON Issuer TO administrator;

--------------------------------------------------------------------------------
-- VIEW Algorithm --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Algorithm
AS
  SELECT * FROM oauth2.algorithm;

GRANT SELECT ON Algorithm TO administrator;
--------------------------------------------------------------------------------
-- VIEW Audience ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Audience
AS
  SELECT * FROM oauth2.audience;

GRANT SELECT ON Audience TO administrator;
