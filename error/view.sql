--------------------------------------------------------------------------------
-- ErrorCatalog ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ErrorCatalog
AS
  SELECT ec.id, ec.code, ec.http_code, ec.severity, ec.category,
         ect.message, ect.description, ect.resolution,
         ec.created_at
    FROM db.error_catalog ec
    LEFT JOIN db.error_catalog_text ect ON ect.error_id = ec.id AND ect.locale = current_locale();

GRANT SELECT ON ErrorCatalog TO administrator;

--------------------------------------------------------------------------------
-- api.error_catalog -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.error_catalog
AS
  SELECT * FROM ErrorCatalog;

GRANT SELECT ON api.error_catalog TO administrator;
