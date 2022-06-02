--------------------------------------------------------------------------------
-- ReplicationLog --------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- replication.ft_replication --------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION replication.ft_log()
RETURNS trigger AS $$
DECLARE
  r             record;

  uEntity       uuid;
  uObject       uuid;

  arKeys        text[];
  pEntities     text[];

  j             jsonb;
  jNew          jsonb;
  jOld          jsonb;
  jKey          jsonb;
  jData         jsonb;

  vMessage      text;
  vContext      text;
BEGIN
  pEntities := array_cat(pEntities, ARRAY['job', 'message']);

  IF TG_TABLE_NAME = ANY (pEntities) THEN
	RETURN NULL;
  END IF;

  IF (TG_OP = 'INSERT') THEN

    jNew := row_to_json(NEW)::jsonb;

    IF TG_TABLE_NAME = 'object_text' THEN
      jNew := jNew - 'searchable_en';
      jNew := jNew - 'searchable_ru';
    END IF;

    IF TG_TABLE_NAME = ANY (ARRAY['object', 'document']) THEN
      uObject := (jNew->>'id')::uuid;
    END IF;

    IF TG_TABLE_NAME = 'object_state' THEN
      SELECT object INTO uObject FROM db.object_state WHERE id = (jNew->>'id')::uuid;
    END IF;

    IF uObject IS NOT NULL THEN
      SELECT entity INTO uEntity FROM db.object WHERE id = uObject;
      IF GetEntityCode(uEntity) = ANY (pEntities) THEN
	    RETURN NULL;
      END IF;
    END IF;

    INSERT INTO replication.log(action, schema, name, data) SELECT 'I', TG_TABLE_SCHEMA, TG_TABLE_NAME, jNew;

  ELSIF (TG_OP = 'UPDATE') THEN

    jOld := row_to_json(OLD)::jsonb;
    jNew := row_to_json(NEW)::jsonb;

    IF TG_TABLE_NAME = ANY (ARRAY['object', 'document']) THEN
      uObject := (jNew->>'id')::uuid;
    END IF;

    IF TG_TABLE_NAME = 'object_state' THEN
      SELECT object INTO uObject FROM db.object_state WHERE id = (jNew->>'id')::uuid;
    END IF;

    IF uObject IS NOT NULL THEN
      SELECT entity INTO uEntity FROM db.object WHERE id = uObject;
      IF GetEntityCode(uEntity) = ANY (pEntities) THEN
	    RETURN NULL;
      END IF;
    END IF;

    SELECT array_agg(field) INTO arKeys FROM replication.pkey WHERE schema = TG_TABLE_SCHEMA AND name = TG_TABLE_NAME;

    FOR r IN SELECT * FROM jsonb_each(jNew)
    LOOP
      j := jsonb_build_object(r.key, r.value);

      IF r.key = ANY (arKeys) THEN
	    jKey := coalesce(jKey, jsonb_build_object()) || j;
	  END IF;

      IF NOT jOld @> j THEN
	    jData := coalesce(jData, jsonb_build_object()) || j;
	  END IF;
    END LOOP;

	IF TG_TABLE_NAME = 'object_text' THEN
	  jData := jData - 'searchable_en';
	  jData := jData - 'searchable_ru';
	END IF;

	IF TG_TABLE_NAME = 'user' THEN
	  jData := jData - 'status';
	END IF;

    IF NULLIF(jData, jsonb_build_object()) IS NOT NULL THEN
      INSERT INTO replication.log(action, schema, name, key, data) SELECT 'U', TG_TABLE_SCHEMA, TG_TABLE_NAME, jKey, jData;
    END IF;

  ELSIF (TG_OP = 'DELETE') THEN

    jOld := row_to_json(OLD)::jsonb;

    SELECT array_agg(field) INTO arKeys FROM replication.pkey WHERE schema = TG_TABLE_SCHEMA AND name = TG_TABLE_NAME;

    FOR r IN SELECT * FROM jsonb_each(jOld)
    LOOP
      IF r.key = ANY (arKeys) THEN
	    jKey := coalesce(jKey, jsonb_build_object()) || jsonb_build_object(r.key, r.value);
	  END IF;
    END LOOP;

    IF jKey IS NOT NULL THEN
      INSERT INTO replication.log(action, schema, name, key) SELECT 'D', TG_TABLE_SCHEMA, TG_TABLE_NAME, jKey;
    END IF;

  END IF;

  RETURN NULL;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;
  PERFORM WriteDiagnostics(vMessage, vContext);
  RETURN NULL;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- replication.log -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION replication.log (
  pFrom         bigint,
  pSource       text,
  pLimit        int DEFAULT 500
) RETURNS       SETOF replication.log
AS $$
  SELECT * FROM replication.log WHERE id > pFrom AND source IS DISTINCT FROM pSource ORDER BY id LIMIT pLimit
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- replication.add_log ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION replication.add_log (
  pDateTime     timestamptz,
  pAction       char,
  pSchema       text,
  pName         text,
  pKey          jsonb,
  pData         jsonb,
  pSource       text DEFAULT null
) RETURNS       bigint
AS $$
DECLARE
  uId           bigint;
BEGIN
  INSERT INTO replication.log(datetime, action, schema, name, key, data, source)
  VALUES (pDateTime, pAction, pSchema, pName, pKey, pData, pSource)
  RETURNING id INTO uId;

  RETURN uId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- replication.add_relay -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION replication.add_relay (
  pSource       text,
  pId           bigint,
  pDateTime     timestamptz,
  pAction       char,
  pSchema       text,
  pName         text,
  pKey          jsonb,
  pData         jsonb,
  pProxy        bool DEFAULT false
) RETURNS       bigint
AS $$
BEGIN
  INSERT INTO replication.relay (source, id, datetime, action, schema, name, key, data, proxy)
  VALUES (pSource, pId, pDateTime, pAction, pSchema, pName, pKey, pData, pProxy);

  RETURN pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- replication.apply_relay -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION replication.apply_relay (
  pSource       text,
  pId           bigint
) RETURNS       void
AS $$
DECLARE
  r             record;
  e             record;
  u             record;

  k             text[];
  v             text[];

  SQL           text;

  vMessage      text;
  vContext      text;
BEGIN
  SELECT * INTO r FROM replication.relay WHERE source = pSource AND id = pId;

  IF NOT FOUND THEN
	PERFORM NotFound();
  END IF;

  EXECUTE format('ALTER TABLE %I.%I DISABLE TRIGGER USER', r.schema, r.name);

  IF r.action = 'I' THEN

    FOR e IN SELECT * FROM jsonb_each(r.data)
    LOOP
      k := array_append(k, e.key);

      IF jsonb_typeof(e.value) = 'string' THEN
        v := array_append(v, quote_nullable(e.value->>0));
      ELSIF jsonb_typeof(e.value) = 'null' THEN
        v := array_append(v, 'null');
      ELSIF jsonb_typeof(e.value) = 'object' OR jsonb_typeof(e.value) = 'array' THEN
        IF e.key = 'value' THEN
          FOR u IN SELECT * FROM jsonb_to_record(e.value) AS x(vtype int, vinteger int, vnumeric numeric, vdatetime timestamptz, vstring text, vboolean boolean)
          LOOP
            v := array_append(v, format('(%s, %L, %L, %L, %L, %L)::Variant', u.vtype, u.vinteger, u.vnumeric, u.vdatetime, u.vstring, u.vboolean));
		  END LOOP;
        ELSE
          v := array_append(v, quote_nullable(e.value->>0));
        END IF;
      ELSE
        v := array_append(v, e.value->>0);
      END IF;
    END LOOP;

    SQL := format('INSERT INTO %I.%I (%s) VALUES (%s);', r.schema, r.name, array_to_string(k, ', '), array_to_string(v, ', '));

  ELSIF r.action = 'U' THEN

    FOR e IN SELECT * FROM jsonb_each(r.key)
    LOOP
      IF jsonb_typeof(e.value) = 'string' THEN
        k := array_append(k, e.key || ' = ' || quote_nullable(e.value->>0));
      ELSIF jsonb_typeof(e.value) = 'null' THEN
        k := array_append(k, e.key || ' IS NULL');
      ELSE
        k := array_append(k, e.key || ' = ' || e.value);
      END IF;
    END LOOP;

    FOR e IN SELECT * FROM jsonb_each(r.data)
    LOOP
      IF jsonb_typeof(e.value) = 'string' THEN
        v := array_append(v, e.key || ' = ' || quote_nullable(e.value->>0));
      ELSIF jsonb_typeof(e.value) = 'null' THEN
        v := array_append(v, e.key || ' = null');
      ELSIF jsonb_typeof(e.value) = 'object' OR jsonb_typeof(e.value) = 'array' THEN
        IF e.key = 'value' THEN
          FOR u IN SELECT * FROM jsonb_to_record(e.value) AS x(vtype int, vinteger int, vnumeric numeric, vdatetime timestamptz, vstring text, vboolean boolean)
          LOOP
            v := array_append(v, e.key || format(' = (%s, %L, %L, %L, %L, %L)::Variant', u.vtype, u.vinteger, u.vnumeric, u.vdatetime, u.vstring, u.vboolean));
		  END LOOP;
        ELSE
          v := array_append(v, e.key || ' = ' || quote_nullable(e.value->>0));
        END IF;
      ELSE
        v := array_append(v, e.key || ' = ' || e.value);
      END IF;
    END LOOP;

    SQL := format('UPDATE %I.%I SET %s WHERE %s', r.schema, r.name, array_to_string(v, ', '), array_to_string(k, ' AND '));

  ELSIF r.action = 'D' THEN

    FOR e IN SELECT * FROM jsonb_each_text(r.key)
    LOOP
      k := array_append(k, e.key || ' = ' || quote_nullable(e.value));
    END LOOP;

    SQL := format('DELETE FROM %I.%I WHERE %s', r.schema, r.name, array_to_string(k, ' AND '));

  END IF;

  EXECUTE SQL;

  EXECUTE format('ALTER TABLE %I.%I ENABLE TRIGGER USER', r.schema, r.name);

  PERFORM SetErrorMessage('Success');

  UPDATE replication.relay SET state = 1, message = null WHERE source = pSource AND id = pId;

  IF r.proxy THEN
	PERFORM replication.add_log(r.datetime, r.action, r.schema, r.name, r.key, r.data, r.source);
  END IF;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;

  EXECUTE format('ALTER TABLE %I.%I ENABLE TRIGGER USER', r.schema, r.name);

  PERFORM SetErrorMessage(vMessage);

  PERFORM WriteDiagnostics(vMessage, vContext);
  PERFORM SafeSetVar('replication_apply', 'false');

  PERFORM WriteToEventLog('D', 9999, 'replication', coalesce(SQL, '<null>'));

  UPDATE replication.relay SET state = 2, message = vMessage WHERE source = pSource AND id = pId;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- replication.apply -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION replication.apply (
  pSource       text
)
RETURNS         int
AS $$
DECLARE
  result        int;
  r             record;
BEGIN
  result := 0;

  FOR r IN SELECT id FROM replication.relay WHERE source = pSource AND state = 0 ORDER BY id LIMIT 1000
  LOOP
    PERFORM replication.apply_relay(pSource, r.id);
    result := result + 1;
  END LOOP;

  RETURN result;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- replication.set_table -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION replication.set_table (
  pSchema       text,
  pName         text,
  pActive       boolean
) RETURNS       void
AS $$
BEGIN
  IF pActive THEN
    UPDATE replication.list SET updated = Now() WHERE schema = pSchema AND name = pName;

    IF NOT FOUND THEN
      INSERT INTO replication.list (schema, name, updated)
      VALUES (pSchema, pName, Now());
    END IF;
  ELSE
    DELETE FROM replication.list WHERE schema = pSchema AND name = pName;
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- replication.set_key ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION replication.set_key (
  pSchema       text,
  pName         text
) RETURNS       void
AS $$
DECLARE
  r             record;
BEGIN
  DELETE FROM replication.pkey WHERE schema = pSchema AND name = pName;

  FOR r IN
    SELECT a.attname
      FROM pg_constraint AS c CROSS JOIN LATERAL UNNEST(c.conkey) AS cols(colnum) INNER JOIN pg_attribute AS a ON a.attrelid = c.conrelid AND cols.colnum = a.attnum
     WHERE c.contype = 'p' -- p = primary key constraint
       AND c.conrelid = format('%s.%s', pSchema, pName)::REGCLASS
  LOOP
    INSERT INTO replication.pkey (schema, name, field) VALUES (pSchema, pName, r.attname::text);
  END LOOP;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- replication.delete_key ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION replication.delete_key (
  pSchema       text,
  pName         text
) RETURNS       boolean
AS $$
BEGIN
  DELETE FROM replication.pkey WHERE schema = pSchema AND name = pName;
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- replication.create_trigger --------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION replication.create_trigger (
  pSchema       text,
  pName         text
) RETURNS       text
AS $$
BEGIN
  RETURN format('CREATE TRIGGER t__%s_replication AFTER INSERT OR UPDATE OR DELETE ON %s.%s FOR EACH ROW EXECUTE PROCEDURE replication.ft_log();', pName, pSchema, pName);
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- replication.drop_trigger ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION replication.drop_trigger (
  pSchema       text,
  pName         text
) RETURNS       text
AS $$
BEGIN
  RETURN format('DROP TRIGGER IF EXISTS t__%s_replication ON %s.%s;', pName, pSchema, pName);
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- replication.table -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION replication.table (
  pSchema       text,
  pName         text,
  pActive       boolean
) RETURNS       void
AS $$
BEGIN
  PERFORM replication.delete_key(pSchema, pName);
  EXECUTE replication.drop_trigger(pSchema, pName);

  PERFORM replication.set_table(pSchema, pName, pActive);

  IF pActive THEN
    PERFORM replication.set_key(pSchema, pName);
    EXECUTE replication.create_trigger(pSchema, pName);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- replication.on --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION replication.on()
RETURNS void
AS $$
DECLARE
  r             record;

  vMessage      text;
  vContext      text;
BEGIN
  TRUNCATE replication.pkey;

  FOR r IN SELECT * FROM ReplicationTable
  LOOP
    BEGIN
      EXECUTE replication.drop_trigger(r.schema, r.name);
      IF r.active THEN
        PERFORM replication.set_key(r.schema, r.name);
        EXECUTE replication.create_trigger(r.schema, r.name);
      END IF;
    EXCEPTION
    WHEN others THEN
      GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;
      PERFORM WriteDiagnostics(vMessage, vContext);
    END;
  END LOOP;
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- replication.off -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION replication.off()
RETURNS void
AS $$
DECLARE
  r             record;

  vMessage      text;
  vContext      text;
BEGIN
  FOR r IN SELECT * FROM ReplicationTable
  LOOP
    EXECUTE replication.drop_trigger(r.schema, r.name);
  END LOOP;
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;
  PERFORM WriteDiagnostics(vMessage, vContext);
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;
