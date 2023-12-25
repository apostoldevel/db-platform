--------------------------------------------------------------------------------
-- AGENT -----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.agent --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.agent (
    id          uuid PRIMARY KEY,
    reference   uuid NOT NULL REFERENCES db.reference(id) ON DELETE CASCADE,
    vendor      uuid NOT NULL REFERENCES db.vendor(id) ON DELETE RESTRICT
);

COMMENT ON TABLE db.agent IS 'Агент.';

COMMENT ON COLUMN db.agent.id IS 'Идентификатор.';
COMMENT ON COLUMN db.agent.reference IS 'Справочник.';
COMMENT ON COLUMN db.agent.vendor IS 'Производитель (поставщик).';

CREATE INDEX ON db.agent (reference);
CREATE INDEX ON db.agent (vendor);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_agent_before_insert()
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

CREATE TRIGGER t_agent_before_insert
  BEFORE INSERT ON db.agent
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_agent_before_insert();

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_agent_after_insert()
RETURNS trigger AS $$
BEGIN
  UPDATE db.aou SET deny = B'000', allow = B'100' WHERE object = NEW.id AND userid = '00000000-0000-4000-a002-000000000002'::uuid; -- mailbot
  IF NOT FOUND THEN
    INSERT INTO db.aou SELECT NEW.id, '00000000-0000-4000-a002-000000000002'::uuid, B'000', B'100'; -- mailbot
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_agent_after_insert
  AFTER INSERT ON db.agent
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_agent_after_insert();
