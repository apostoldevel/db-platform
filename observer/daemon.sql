--------------------------------------------------------------------------------
-- daemon.publisher_list -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION daemon.publisher_list()
RETURNS SETOF text
AS $$
  SELECT code FROM db.publisher;
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
