--------------------------------------------------------------------------------
-- REST REGISTRY ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Запрос данных в формате REST JSON API (реестр).
 * @param {text} pPath - Путь
 * @param {jsonb} pPayload - JSON
 * @return {SETOF json} - Записи в JSON
 */
CREATE OR REPLACE FUNCTION rest.registry (
  pPath       text,
  pPayload    jsonb default null
) RETURNS     SETOF json
AS $$
DECLARE
  r           record;
  e           record;

  arKeys      text[];
BEGIN
  IF pPath IS NULL THEN
    PERFORM RouteIsEmpty();
  END IF;

  CASE pPath
  WHEN '/registry/list' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['id', 'key', 'subkey', 'extended']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, key numeric, subkey numeric, extended boolean)
      LOOP
        IF coalesce(r.extended, false) THEN
          FOR e IN SELECT * FROM api.registry_ex(r.id, r.key, r.subkey)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        ELSE
          FOR e IN SELECT * FROM api.registry(r.id, r.key, r.subkey)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END IF;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, key numeric, subkey numeric, extended boolean)
      LOOP
        IF coalesce(r.extended, false) THEN
          FOR e IN SELECT * FROM api.registry_ex(r.id, r.key, r.subkey)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        ELSE
          FOR e IN SELECT * FROM api.registry(r.id, r.key, r.subkey)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END IF;
      END LOOP;

    END IF;

  WHEN '/registry/key' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['id', 'root', 'parent', 'key']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, root numeric, parent numeric, key text)
      LOOP
        FOR e IN SELECT * FROM api.registry_key(r.id, r.root, r.parent, r.key)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, root numeric, parent numeric, key text)
      LOOP
        FOR e IN SELECT * FROM api.registry_key(r.id, r.root, r.parent, r.key)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/registry/value' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['id', 'key', 'extended']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, key numeric, extended boolean)
      LOOP
        IF coalesce(r.extended, false) THEN
          FOR e IN SELECT * FROM api.registry_value_ex(r.id, r.key)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        ELSE
          FOR e IN SELECT * FROM api.registry_value(r.id, r.key)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END IF;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, key numeric, extended boolean)
      LOOP
        IF coalesce(r.extended, false) THEN
          FOR e IN SELECT * FROM api.registry_value_ex(r.id, r.key)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        ELSE
          FOR e IN SELECT * FROM api.registry_value(r.id, r.key)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END IF;
      END LOOP;

    END IF;

  WHEN '/registry/get/key' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['id']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric)
      LOOP
        FOR e IN SELECT * FROM api.registry_get_reg_key(r.id) AS key
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric)
      LOOP
        FOR e IN SELECT * FROM api.registry_get_reg_key(r.id) AS key
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/registry/enum/key' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['key', 'subkey']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(key text, subkey text)
      LOOP
        FOR e IN SELECT * FROM api.registry_enum_key(r.key, r.subkey)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(key text, subkey text)
      LOOP
        FOR e IN SELECT * FROM api.registry_enum_key(r.key, r.subkey)
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/registry/enum/value' THEN

    IF pPayload IS NOT NULL THEN
      arKeys := array_cat(arKeys, ARRAY['key', 'subkey', 'extended']);
      PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);
    ELSE
      pPayload := '{}';
    END IF;

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(key text, subkey text, extended boolean)
      LOOP
        IF coalesce(r.extended, false) THEN
          FOR e IN SELECT * FROM api.registry_enum_value_ex(r.key, r.subkey)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        ELSE
          FOR e IN SELECT * FROM api.registry_enum_value(r.key, r.subkey)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END IF;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(key text, subkey text, extended boolean)
      LOOP
        IF coalesce(r.extended, false) THEN
          FOR e IN SELECT * FROM api.registry_enum_value_ex(r.key, r.subkey)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        ELSE
          FOR e IN SELECT * FROM api.registry_enum_value(r.key, r.subkey)
          LOOP
            RETURN NEXT row_to_json(e);
          END LOOP;
        END IF;
      END LOOP;

    END IF;

  WHEN '/registry/write' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'key', 'subkey', 'name', 'type', 'data']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(type integer)
    LOOP

      pPayload = pPayload - 'type';

      CASE r.type
      WHEN 0 THEN
        pPayload = pPayload || jsonb_build_object('value', pPayload->>'data');
        pPayload = pPayload - 'data';
        FOR e IN SELECT * FROM rest.registry(pPath || '/integer', pPayload)
        LOOP
          RETURN NEXT e.registry;
        END LOOP;
      WHEN 1 THEN
        pPayload = pPayload || jsonb_build_object('value', pPayload->>'data');
        pPayload = pPayload - 'data';
        FOR e IN SELECT * FROM rest.registry(pPath || '/numeric', pPayload)
        LOOP
          RETURN NEXT e.registry;
        END LOOP;
      WHEN 2 THEN
        pPayload = pPayload || jsonb_build_object('value', pPayload->>'data');
        pPayload = pPayload - 'data';
        FOR e IN SELECT * FROM rest.registry(pPath || '/datetime', pPayload)
        LOOP
          RETURN NEXT e.registry;
        END LOOP;
      WHEN 3 THEN
        pPayload = pPayload || jsonb_build_object('value', pPayload->>'data');
        pPayload = pPayload - 'data';
        FOR e IN SELECT * FROM rest.registry(pPath || '/string', pPayload)
        LOOP
          RETURN NEXT e.registry;
        END LOOP;
      WHEN 4 THEN
        pPayload = pPayload || jsonb_build_object('value', pPayload->>'data');
        pPayload = pPayload - 'data';
        FOR e IN SELECT * FROM rest.registry(pPath || '/boolean', pPayload)
        LOOP
          RETURN NEXT e.registry;
        END LOOP;
      ELSE
        PERFORM IncorrectRegistryDataType(r.type);
      END CASE;
    END LOOP;

  WHEN '/registry/write/integer' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'key', 'subkey', 'name', 'value']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, key text, subkey text, name text, value integer)
      LOOP
        FOR e IN SELECT * FROM api.registry_write(r.id, r.key, r.subkey, r.name, 0, r.value) AS id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, key text, subkey text, name text, value integer)
      LOOP
        FOR e IN SELECT * FROM api.registry_write(r.id, r.key, r.subkey, r.name, 0, r.value) AS id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/registry/write/numeric' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'key', 'subkey', 'name', 'value']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, key text, subkey text, name text, value numeric)
      LOOP
        FOR e IN SELECT * FROM api.registry_write(r.id, r.key, r.subkey, r.name, 1, r.value) AS id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, key text, subkey text, name text, value numeric)
      LOOP
        FOR e IN SELECT * FROM api.registry_write(r.id, r.key, r.subkey, r.name, 1, r.value) AS id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/registry/write/datetime' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'key', 'subkey', 'name', 'value']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, key text, subkey text, name text, value timestamp)
      LOOP
        FOR e IN SELECT * FROM api.registry_write(r.id, r.key, r.subkey, r.name, 2, r.value) AS id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, key text, subkey text, name text, value timestamp)
      LOOP
        FOR e IN SELECT * FROM api.registry_write(r.id, r.key, r.subkey, r.name, 2, r.value) AS id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/registry/write/string' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'key', 'subkey', 'name', 'value']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, key text, subkey text, name text, value text)
      LOOP
        FOR e IN SELECT * FROM api.registry_write(r.id, r.key, r.subkey, r.name, 3, r.value) AS id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, key text, subkey text, name text, value text)
      LOOP
        FOR e IN SELECT * FROM api.registry_write(r.id, r.key, r.subkey, r.name, 3, r.value) AS id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/registry/write/boolean' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'key', 'subkey', 'name', 'value']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, key text, subkey text, name text, value boolean)
      LOOP
        FOR e IN SELECT * FROM api.registry_write(r.id, r.key, r.subkey, r.name, 4, r.value) AS id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, key text, subkey text, name text, value boolean)
      LOOP
        FOR e IN SELECT * FROM api.registry_write(r.id, r.key, r.subkey, r.name, 4, r.value) AS id
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/registry/read' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'key', 'subkey', 'name']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, key text, subkey text, name text)
      LOOP
        FOR e IN SELECT * FROM api.registry_read(r.key, r.subkey, r.name) AS value
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, key text, subkey text, name text)
      LOOP
        FOR e IN SELECT * FROM api.registry_read(r.key, r.subkey, r.name) AS value
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/registry/read/integer' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'key', 'subkey', 'name']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, key text, subkey text, name text)
      LOOP
        FOR e IN SELECT (data::variant).vinteger as value FROM api.registry_read(r.key, r.subkey, r.name) AS data
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, key text, subkey text, name text)
      LOOP
        FOR e IN SELECT (data::variant).vinteger as value FROM api.registry_read(r.key, r.subkey, r.name) AS data
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/registry/read/numeric' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'key', 'subkey', 'name']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, key text, subkey text, name text)
      LOOP
        FOR e IN SELECT (data::variant).vnumeric as value FROM api.registry_read(r.key, r.subkey, r.name) AS data
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, key text, subkey text, name text)
      LOOP
        FOR e IN SELECT (data::variant).vnumeric as value FROM api.registry_read(r.key, r.subkey, r.name) AS data
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/registry/read/datetime' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'key', 'subkey', 'name']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, key text, subkey text, name text)
      LOOP
        FOR e IN SELECT (data::variant).vdatetime as value FROM api.registry_read(r.key, r.subkey, r.name) AS data
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, key text, subkey text, name text)
      LOOP
        FOR e IN SELECT (data::variant).vdatetime as value FROM api.registry_read(r.key, r.subkey, r.name) AS data
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/registry/read/string' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'key', 'subkey', 'name']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, key text, subkey text, name text)
      LOOP
        FOR e IN SELECT (data::variant).vstring as value FROM api.registry_read(r.key, r.subkey, r.name) AS data
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, key text, subkey text, name text)
      LOOP
        FOR e IN SELECT (data::variant).vstring as value FROM api.registry_read(r.key, r.subkey, r.name) AS data
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/registry/read/boolean' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'key', 'subkey', 'name']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, key text, subkey text, name text)
      LOOP
        FOR e IN SELECT (data::variant).vboolean as value FROM api.registry_read(r.key, r.subkey, r.name) AS data
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, key text, subkey text, name text)
      LOOP
        FOR e IN SELECT (data::variant).vboolean as value FROM api.registry_read(r.key, r.subkey, r.name) AS data
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/registry/delete/key' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['key', 'subkey']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(key text, subkey text)
      LOOP
        FOR e IN SELECT * FROM api.registry_delete_key(r.key, r.subkey) AS success
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(key text, subkey text)
      LOOP
        FOR e IN SELECT * FROM api.registry_delete_key(r.key, r.subkey) AS success
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/registry/delete/value' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['id', 'key', 'subkey', 'name']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(id numeric, key text, subkey text, name text)
      LOOP
        FOR e IN SELECT * FROM api.registry_delete_value(r.id, r.key, r.subkey, r.name) AS success
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(id numeric, key text, subkey text, name text)
      LOOP
        FOR e IN SELECT * FROM api.registry_delete_value(r.id, r.key, r.subkey, r.name) AS success
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  WHEN '/registry/delete/tree' THEN

    IF pPayload IS NULL THEN
      PERFORM JsonIsEmpty();
    END IF;

    arKeys := array_cat(arKeys, ARRAY['key', 'subkey']);
    PERFORM CheckJsonbKeys(pPath, arKeys, pPayload);

    IF jsonb_typeof(pPayload) = 'array' THEN

      FOR r IN SELECT * FROM jsonb_to_recordset(pPayload) AS x(key text, subkey text)
      LOOP
        FOR e IN SELECT * FROM api.registry_delete_tree(r.key, r.subkey) AS success
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    ELSE

      FOR r IN SELECT * FROM jsonb_to_record(pPayload) AS x(key text, subkey text)
      LOOP
        FOR e IN SELECT * FROM api.registry_delete_tree(r.key, r.subkey) AS success
        LOOP
          RETURN NEXT row_to_json(e);
        END LOOP;
      END LOOP;

    END IF;

  ELSE
    PERFORM RouteNotFound(pPath);
  END CASE;

  RETURN;
END;
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;
