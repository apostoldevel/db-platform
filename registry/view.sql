--------------------------------------------------------------------------------
-- Registry --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Registry
AS
  SELECT * FROM registry.registry(GetRegRoot('kernel'))
   UNION ALL
  SELECT * FROM registry.registry(GetRegRoot(current_username()));

GRANT ALL ON Registry TO administrator;

--------------------------------------------------------------------------------
-- RegistryEx ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW RegistryEx
AS
  SELECT * FROM registry.registry_ex(GetRegRoot('kernel'))
   UNION ALL
  SELECT * FROM registry.registry_ex(GetRegRoot(current_username()));

GRANT ALL ON RegistryEx TO administrator;

--------------------------------------------------------------------------------
-- RegistryKey -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW RegistryKey
AS
  SELECT * FROM registry.registry_key(GetRegRoot('kernel'))
   UNION ALL
  SELECT * FROM registry.registry_key(GetRegRoot(current_username()));

GRANT ALL ON RegistryKey TO administrator;

--------------------------------------------------------------------------------
-- RegistryValue ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW RegistryValue
AS
  SELECT * FROM registry.registry_value(GetRegRoot('kernel'))
   UNION ALL
  SELECT * FROM registry.registry_value(GetRegRoot(current_username()));

GRANT ALL ON RegistryValue TO administrator;

--------------------------------------------------------------------------------
-- RegistryValueEx -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW RegistryValueEx
AS
  SELECT * FROM registry.registry_value_ex(GetRegRoot('kernel'))
   UNION ALL
  SELECT * FROM registry.registry_value_ex(GetRegRoot(current_username()));

GRANT ALL ON RegistryValueEx TO administrator;

