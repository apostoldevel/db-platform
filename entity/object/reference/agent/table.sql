--------------------------------------------------------------------------------
-- AGENT -----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.agent --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.agent (
    id          numeric(12) PRIMARY KEY,
    reference   numeric(12) NOT NULL,
    vendor      numeric(12) NOT NULL,
    CONSTRAINT fk_agent_reference FOREIGN KEY (reference) REFERENCES db.reference(id)
);

COMMENT ON TABLE db.agent IS 'Агент.';

COMMENT ON COLUMN db.agent.id IS 'Идентификатор.';
COMMENT ON COLUMN db.agent.reference IS 'Справочник.';
COMMENT ON COLUMN db.agent.vendor IS 'Производитель (поставщик).';

CREATE INDEX ON db.agent (reference);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_agent_insert()
RETURNS trigger AS $$
DECLARE
BEGIN
  IF NULLIF(NEW.id, 0) IS NULL THEN
    SELECT NEW.reference INTO NEW.id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_agent_insert
  BEFORE INSERT ON db.agent
  FOR EACH ROW
  EXECUTE PROCEDURE ft_agent_insert();

