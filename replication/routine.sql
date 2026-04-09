--------------------------------------------------------------------------------
-- ReplicationLog --------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- replication.ft_replication --------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Capture row changes into the replication log for cross-instance synchronization.
 * @return {trigger} - NULL (AFTER trigger, does not modify the row)
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION replication.ft_log()
RETURNS trigger AS $$
DECLARE
  r             record;

  uObject       uuid;

  arKeys        text[];
  pTables       text[];

  j             jsonb;
  jNew          jsonb;
  jOld          jsonb;
  jKey          jsonb;
  jData         jsonb;

  vMessage      text;
  vContext      text;
BEGIN
  pTables := array_cat(pTables, ARRAY['log', 'api_log', 'job', 'message', 'notification']);

  IF TG_TABLE_NAME = ANY (pTables) THEN
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
      uObject := (jNew->>'object')::uuid;
    END IF;

    IF TG_TABLE_NAME = 'method_stack' THEN
      uObject := (jNew->>'object')::uuid;
    END IF;

    IF uObject IS NOT NULL THEN
      PERFORM FROM db.job WHERE id = uObject;
      IF FOUND THEN
        RETURN NULL;
      END IF;

      PERFORM FROM db.message WHERE id = uObject;
      IF FOUND THEN
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
      uObject := (jNew->>'object')::uuid;
    END IF;

    IF TG_TABLE_NAME = 'method_stack' THEN
      uObject := (jNew->>'object')::uuid;
    END IF;

    IF uObject IS NOT NULL THEN
      PERFORM FROM db.job WHERE id = uObject;
      IF FOUND THEN
        RETURN NULL;
      END IF;

      PERFORM FROM db.message WHERE id = uObject;
      IF FOUND THEN
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

    IF TG_TABLE_NAME = 'profile' THEN
      jData := jData - 'input_count';
      jData := jData - 'input_last';
      jData := jData - 'lc_ip';
      jData := jData - 'state';
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
  PERFORM WriteDiagnostics(vMessage, vContext, 'replication');
  RETURN NULL;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- replication.log -------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Fetch replication log entries after a given ID, excluding a specific source.
 * @param {bigint} pFrom - Log entry ID to start from (exclusive)
 * @param {text} pSource - Source instance to exclude from results
 * @param {int} pLimit - Maximum number of entries to return (default 500)
 * @return {SETOF replication.log} - Matching log entries ordered by ID
 * @since 1.0.0
 */
CREATE OR REPLACE FUNCTION replication.log (
  pFrom         bigint,
  pSource       text,
  pLimit        int DEFAULT 500
) RETURNS       SETOF replication.log
AS $$
  SELECT * FROM replication.log WHERE id > pFrom AND source IS DISTINCT FROM pSource ORDER BY id LIMIT pLimit
$$ LANGUAGE SQL STABLE
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- replication.add_log ---------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Insert an entry into the replication log.
 * @param {timestamptz} pDateTime - Timestamp of the original change
 * @param {char} pAction - DML action: I = INSERT, U = UPDATE, D = DELETE
 * @param {text} pSchema - Target table schema
 * @param {text} pName - Target table name
 * @param {jsonb} pKey - Primary key columns for row identification
 * @param {jsonb} pData - Changed row data
 * @param {text} pSource - Originating instance identifier (NULL for local)
 * @return {bigint} - Newly created log entry ID
 * @since 1.0.0
 */
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

/**
 * @brief Insert an entry into the relay log for deferred application.
 * @param {text} pSource - Originating instance identifier
 * @param {bigint} pId - Log entry ID from the source instance
 * @param {timestamptz} pDateTime - Original timestamp of the change
 * @param {char} pAction - DML action: I = INSERT, U = UPDATE, D = DELETE
 * @param {text} pSchema - Target table schema
 * @param {text} pName - Target table name
 * @param {jsonb} pKey - Primary key columns for row identification
 * @param {jsonb} pData - Row data to apply
 * @param {bool} pProxy - When TRUE, re-log the entry for further relay
 * @return {bigint} - The relay entry ID (same as pId)
 * @since 1.0.0
 */
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

/**
 * @brief Apply a single relay log entry by executing the recorded DML on the target table.
 * @param {text} pSource - Originating instance identifier
 * @param {bigint} pId - Relay entry ID to apply
 * @return {void}
 * @throws NotFound - When the relay entry does not exist
 * @see replication.apply
 * @since 1.0.0
 */
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
  t             text[];

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
        ELSIF r.name = 'calendar' AND e.key IN ('holiday', 'dayoff', 'schedule') THEN
          FOR u IN SELECT * FROM jsonb_array_elements(e.value)
          LOOP
            IF jsonb_typeof(u.value) = 'array' THEN
              t := array_append(t, '{' || array_to_string(JsonbToStrArray(u.value), ',') || '}');
            ELSE
              t := array_append(t, '{' || array_to_string(JsonbToStrArray(e.value), ',') || '}');
              EXIT WHEN true;
            END IF;
          END LOOP;
          v := array_append(v, format('%L', '{' || array_to_string(t, ',') || '}'));
        ELSIF r.name = 'cdate' AND e.key = 'schedule' THEN
          FOR u IN SELECT * FROM jsonb_array_elements(e.value)
          LOOP
            IF jsonb_typeof(u.value) = 'array' THEN
              t := array_append(t, '{' || array_to_string(JsonbToIntervalArray(u.value), ',') || '}');
            ELSE
              t := array_append(t, '{' || array_to_string(JsonbToIntervalArray(e.value), ',') || '}');
              EXIT WHEN true;
            END IF;
          END LOOP;
          v := array_append(v, format('%L', '{' || array_to_string(t, ',') || '}'));
        ELSE
          v := array_append(v, quote_nullable(e.value));
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
        ELSIF r.name = 'calendar' AND e.key IN ('holiday', 'dayoff', 'schedule') THEN
          FOR u IN SELECT * FROM jsonb_array_elements(e.value)
          LOOP
            IF jsonb_typeof(u.value) = 'array' THEN
              t := array_append(t, '{' || array_to_string(JsonbToStrArray(u.value), ',') || '}');
            ELSE
              t := array_append(t, '{' || array_to_string(JsonbToStrArray(e.value), ',') || '}');
              EXIT WHEN true;
            END IF;
          END LOOP;
          v := array_append(v, e.key || format(' = %L', '{' || array_to_string(t, ',') || '}'));
        ELSIF r.name = 'cdate' AND e.key = 'schedule' THEN
          FOR u IN SELECT * FROM jsonb_array_elements(e.value)
          LOOP
            IF jsonb_typeof(u.value) = 'array' THEN
              t := array_append(t, '{' || array_to_string(JsonbToIntervalArray(u.value), ',') || '}');
            ELSE
              t := array_append(t, '{' || array_to_string(JsonbToIntervalArray(e.value), ',') || '}');
              EXIT WHEN true;
            END IF;
          END LOOP;
          v := array_append(v, e.key || format(' = %L', '{' || array_to_string(t, ',') || '}'));
        ELSE
          v := array_append(v, e.key || ' = ' || quote_nullable(e.value));
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

  PERFORM WriteDiagnostics(vMessage, vContext, 'replication');
  PERFORM SafeSetVar('replication_apply', 'false');

  PERFORM WriteToEventLog('D', 9020, 'replication', 'diagnostic', coalesce(SQL, '<null>'));

  UPDATE replication.relay SET state = 2, message = vMessage WHERE source = pSource AND id = pId;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- replication.apply -----------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Apply all pending relay entries for a given source instance (up to 1000 per call).
 * @param {text} pSource - Originating instance identifier
 * @return {int} - Number of relay entries processed
 * @see replication.apply_relay
 * @since 1.0.0
 */
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

/**
 * @brief Add or remove a table from the replication set.
 * @param {text} pSchema - Table schema name
 * @param {text} pName - Table name
 * @param {boolean} pActive - TRUE to enroll, FALSE to remove
 * @return {void}
 * @since 1.0.0
 */
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

/**
 * @brief Populate the primary key cache for a replicated table from pg_constraint.
 * @param {text} pSchema - Table schema name
 * @param {text} pName - Table name
 * @return {void}
 * @since 1.0.0
 */
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

/**
 * @brief Remove the primary key cache entries for a table.
 * @param {text} pSchema - Table schema name
 * @param {text} pName - Table name
 * @return {boolean} - TRUE if any rows were deleted
 * @since 1.0.0
 */
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

/**
 * @brief Generate a CREATE TRIGGER statement for attaching the replication trigger to a table.
 * @param {text} pSchema - Table schema name
 * @param {text} pName - Table name
 * @return {text} - DDL statement to create the replication trigger
 * @see replication.drop_trigger
 * @since 1.0.0
 */
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

/**
 * @brief Generate a DROP TRIGGER statement for removing the replication trigger from a table.
 * @param {text} pSchema - Table schema name
 * @param {text} pName - Table name
 * @return {text} - DDL statement to drop the replication trigger
 * @see replication.create_trigger
 * @since 1.0.0
 */
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

/**
 * @brief Enable or disable replication for a table (manages keys, triggers, and the replication set).
 * @param {text} pSchema - Table schema name
 * @param {text} pName - Table name
 * @param {boolean} pActive - TRUE to enable replication, FALSE to disable
 * @return {void}
 * @since 1.0.0
 */
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

/**
 * @brief Activate replication triggers on all tables registered in the replication set.
 * @return {void}
 * @see replication.off
 * @since 1.0.0
 */
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
      PERFORM WriteDiagnostics(vMessage, vContext, 'replication');
    END;
  END LOOP;
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- replication.off -------------------------------------------------------------
--------------------------------------------------------------------------------

/**
 * @brief Deactivate replication triggers on all tables in the replication set.
 * @return {void}
 * @see replication.on
 * @since 1.0.0
 */
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
  PERFORM WriteDiagnostics(vMessage, vContext, 'replication');
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;
