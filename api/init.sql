--------------------------------------------------------------------------------
-- InitAPI ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION InitAPI()
RETURNS			void
AS $$
BEGIN
  PERFORM RegisterRoute(null, AddEndpoint('SELECT * FROM rest.api($1, $2);'));
  PERFORM RegisterRoute('admin', AddEndpoint('SELECT * FROM rest.admin($1, $2);'));
  PERFORM RegisterRoute('current', AddEndpoint('SELECT * FROM rest.current($1, $2);'));
  PERFORM RegisterRoute('event', AddEndpoint('SELECT * FROM rest.event($1, $2);'));
  PERFORM RegisterRoute('notification', AddEndpoint('SELECT * FROM rest.notification($1, $2);'));
  PERFORM RegisterRoute('registry', AddEndpoint('SELECT * FROM rest.registry($1, $2);'));
  PERFORM RegisterRoute('session', AddEndpoint('SELECT * FROM rest.session($1, $2);'));
  PERFORM RegisterRoute('verification', AddEndpoint('SELECT * FROM rest.verification($1, $2);'));
  PERFORM RegisterRoute('workflow', AddEndpoint('SELECT * FROM rest.workflow($1, $2);'));
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
