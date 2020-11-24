--------------------------------------------------------------------------------
-- InitAPI ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION InitAPI()
RETURNS			void
AS $$
BEGIN
  PERFORM RegisterRoute('/api/v1', AddEndpoint('SELECT * FROM rest.api($1, $2);'));
  PERFORM RegisterRoute('/api/v1/admin', AddEndpoint('SELECT * FROM rest.admin($1, $2);'));
  PERFORM RegisterRoute('/api/v1/current', AddEndpoint('SELECT * FROM rest.current($1, $2);'));
  PERFORM RegisterRoute('/api/v1/event', AddEndpoint('SELECT * FROM rest.event($1, $2);'));
  PERFORM RegisterRoute('/api/v1/notify', AddEndpoint('SELECT * FROM rest.notify($1, $2);'));
  PERFORM RegisterRoute('/api/v1/registry', AddEndpoint('SELECT * FROM rest.registry($1, $2);'));
  PERFORM RegisterRoute('/api/v1/session', AddEndpoint('SELECT * FROM rest.session($1, $2);'));
  PERFORM RegisterRoute('/api/v1/verification', AddEndpoint('SELECT * FROM rest.verification($1, $2);'));
  PERFORM RegisterRoute('/api/v1/workflow', AddEndpoint('SELECT * FROM rest.workflow($1, $2);'));
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
