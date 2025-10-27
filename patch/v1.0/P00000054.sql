CREATE OR REPLACE FUNCTION http.ft_request_after_insert()
RETURNS     trigger
AS $$
BEGIN
  PERFORM pg_notify(TG_TABLE_SCHEMA, NEW.id::text);
  RETURN NULL;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
