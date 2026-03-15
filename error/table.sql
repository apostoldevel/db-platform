--------------------------------------------------------------------------------
-- ERROR_CATALOG ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.error_catalog (
  id          uuid PRIMARY KEY DEFAULT gen_kernel_uuid(),
  code        text NOT NULL,
  http_code   integer NOT NULL,
  severity    char(1) NOT NULL DEFAULT 'E',
  category    text NOT NULL DEFAULT 'validation',
  created_at  timestamptz NOT NULL DEFAULT Now()
);

COMMENT ON TABLE db.error_catalog IS 'Master catalog of all application error codes (ERR-GGG-CCC format).';
COMMENT ON COLUMN db.error_catalog.id IS 'Primary key (UUID).';
COMMENT ON COLUMN db.error_catalog.code IS 'Structured error identifier (e.g., ERR-400-001). Unique across the system.';
COMMENT ON COLUMN db.error_catalog.http_code IS 'HTTP status code group (400, 401, 403, 404, 500).';
COMMENT ON COLUMN db.error_catalog.severity IS 'Severity level: E = error, W = warning.';
COMMENT ON COLUMN db.error_catalog.category IS 'Functional category: auth, access, validation, entity, workflow, system.';
COMMENT ON COLUMN db.error_catalog.created_at IS 'Timestamp when the error code was registered.';

CREATE UNIQUE INDEX ON db.error_catalog (code);
CREATE INDEX ON db.error_catalog (http_code);
CREATE INDEX ON db.error_catalog (category);

--------------------------------------------------------------------------------
-- ERROR_CATALOG_TEXT ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.error_catalog_text (
  error_id    uuid NOT NULL REFERENCES db.error_catalog(id) ON DELETE CASCADE,
  locale      uuid NOT NULL REFERENCES db.locale(id) ON DELETE RESTRICT,
  message     text NOT NULL,
  description text,
  resolution  text,
  PRIMARY KEY (error_id, locale)
);

COMMENT ON TABLE db.error_catalog_text IS 'Locale-specific error messages, descriptions, and resolution guidance.';
COMMENT ON COLUMN db.error_catalog_text.error_id IS 'Reference to the error catalog entry.';
COMMENT ON COLUMN db.error_catalog_text.locale IS 'Target locale for this translation.';
COMMENT ON COLUMN db.error_catalog_text.message IS 'Short user-facing error message (e.g., "Access denied."). May contain %s placeholders.';
COMMENT ON COLUMN db.error_catalog_text.description IS 'Detailed explanation for documentation and support agents.';
COMMENT ON COLUMN db.error_catalog_text.resolution IS 'Recommended steps to resolve the error.';
