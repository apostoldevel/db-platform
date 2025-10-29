DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT n.nspname AS schema_name, p.proname AS function_name
      FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
     WHERE p.proname IN ('newobjectfile', 'editobjectfile', 'setobjectfile')
  LOOP
    EXECUTE format('DROP FUNCTION %I.%I(%s)', r.schema_name, r.function_name, array_to_string(GetRoutines(r.function_name, r.schema_name, true, null, 1), ', '));
  END LOOP;
END $$;
