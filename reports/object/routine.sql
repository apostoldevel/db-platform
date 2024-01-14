--------------------------------------------------------------------------------
-- REPORT ----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- rpc_object_info -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Отчёт: Информация об объекте
 * @param {uuid} pReady - Идентификатор готового отчёта
 * @param {jsonb} pForm - Форма
 * @return {uuid} - Идентификатор готового отчёта
 */
CREATE OR REPLACE FUNCTION report.rpc_object_info (
  pReady        uuid,
  pForm         jsonb default null
) RETURNS       void
AS $$
DECLARE
  o             record;
  l             record;
  f             record;
  d             record;

  uObject       uuid;

  bEmpty        boolean;

  vHTML         text;

  Lines         text[];

  vMessage      text;
  vContext      text;

  ErrorCode     int;
  ErrorMessage  text;
BEGIN
  uObject := pForm->>'identifier';

  FOR l IN SELECT code FROM db.locale WHERE id = current_locale()
  LOOP
    IF l.code = 'ru' THEN
      Lines[1] := 'Информация об объекте';
    ELSE
      Lines[1] := 'Information about the object';
    END IF;

    vHTML := E'<!DOCTYPE html>\n';

    vHTML := vHTML || format(E'<html lang="%s">\n', l.code);
    vHTML := vHTML || E'<head>\n';
    vHTML := vHTML || E'  <meta charset="UTF-8">\n';
    vHTML := vHTML || format(E'  <title>%s</title>\n', Lines[1]);
    vHTML := vHTML || E'</head>\n';

    vHTML := vHTML || E'<body>\n';
    vHTML := vHTML || E'<div>\n';

    vHTML := vHTML || E'  <div class="text-center">\n';
    vHTML := vHTML || E'    <h2 class="mb-3">' || Lines[1] || E'</h2>\n';
    vHTML := vHTML || E'  </div>\n';

    vHTML := vHTML || E'  <div class="table-responsive">\n';

    vHTML := vHTML || E'    <table class="table table-bordered">\n';
    vHTML := vHTML || E'      <thead class="thead-light">\n';

    IF l.code = 'ru' THEN
      vHTML := vHTML || E'        <tr>\n';
      vHTML := vHTML || E'          <th style="width: 20%!important;">Поле</th>\n';
      vHTML := vHTML || E'          <th>Данные</th>\n';
      vHTML := vHTML || E'        </tr>\n';
    ELSE
      vHTML := vHTML || E'        <tr>\n';
      vHTML := vHTML || E'          <th style="width: 20%!important;">Field</th>\n';
      vHTML := vHTML || E'          <th>Data</th>\n';
      vHTML := vHTML || E'        </tr>\n';
    END IF;

    vHTML := vHTML || E'      </thead>\n';
    vHTML := vHTML || E'      <tbody>\n';

    bEmpty := true;

    FOR o IN
      SELECT *
        FROM Object
       WHERE id = uObject
    LOOP
      bEmpty := false;

      FOR f IN SELECT * FROM all_tab_columns WHERE table_name = 'object' ORDER BY column_id
      LOOP
        vHTML := vHTML || E'        <tr>\n';
        vHTML := vHTML || format(E'          <th>%s</th>\n', f.column_name);

        FOR d IN EXECUTE format('SELECT $1->>%L AS value', f.column_name) USING row_to_json(o)
        LOOP
          vHTML := vHTML || format(E'          <td>%s</th>\n', d.value);
        END LOOP;

        vHTML := vHTML || E'        </tr>\n';
      END LOOP;

    END LOOP;

    IF bEmpty THEN
      IF l.code = 'ru' THEN
        vHTML := vHTML || E'        <tr class="text-center">\n';
        vHTML := vHTML || E'          <th colspan="2">Нет данных</th>\n';
        vHTML := vHTML || E'        </tr>\n';
      ELSE
        vHTML := vHTML || E'        <tr class="text-center">\n';
        vHTML := vHTML || E'          <th colspan="2">No data</th>\n';
        vHTML := vHTML || E'        </tr>\n';
      END IF;
    END IF;

    vHTML := vHTML || E'      </tbody>\n';
    vHTML := vHTML || E'    </table>\n';
    vHTML := vHTML || E'  </div>\n';

    vHTML := vHTML || E'</div>\n';
    vHTML := vHTML || E'</body>\n';
    vHTML := vHTML || E'</html>\n';
  END LOOP;

  PERFORM SetObjectFile(pReady, null, 'index.html', null, length(vHTML), localtimestamp, vHTML::bytea, encode(digest(vHTML, 'md5'), 'hex'), Lines[1], 'data:text/html;base64,');

  PERFORM ExecuteObjectAction(pReady, GetAction('complete'));
EXCEPTION
WHEN others THEN
  GET STACKED DIAGNOSTICS vMessage = MESSAGE_TEXT, vContext = PG_EXCEPTION_CONTEXT;

  PERFORM SetErrorMessage(vMessage);

  SELECT * INTO ErrorCode, ErrorMessage FROM ParseMessage(vMessage);

  PERFORM WriteToEventLog('E', ErrorCode, ErrorMessage, pReady);
  PERFORM WriteToEventLog('D', ErrorCode, vContext, pReady);

  PERFORM ExecuteObjectAction(pReady, GetAction('fail'));

  vHTML := ReportErrorHTML(ErrorCode, ErrorMessage, vContext);

  PERFORM SetObjectFile(pReady, null, 'index.html', null, length(vHTML), localtimestamp, vHTML::bytea, encode(digest(vHTML, 'md5'), 'hex'), 'exception', 'data:text/html;base64,');
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, public, pg_temp;
