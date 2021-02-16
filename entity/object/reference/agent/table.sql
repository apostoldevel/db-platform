--------------------------------------------------------------------------------
-- AGENT -----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.agent --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.agent (
    id          uuid PRIMARY KEY,
    reference   uuid NOT NULL REFERENCES db.reference(id) ON DELETE CASCADE,
    vendor      uuid NOT NULL
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
  IF NEW.id IS NULL THEN
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
