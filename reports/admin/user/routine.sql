--------------------------------------------------------------------------------
-- REPORT ----------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- rfc_user_list ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Форма отчёта: Список пользователей
 * @param {uuid} pForm - Идентификатор формы
 * @param {jsonb} pParams - Параметры
 * @return {SETOF json} - Записи в JSON
 */
CREATE OR REPLACE FUNCTION report.rfc_user_list (
  pForm         uuid,
  pParams       json default null
) RETURNS       json
AS $$
DECLARE
  r             record;
  l             record;
  g             record;
  u             record;

  fields        jsonb;

  arGroups      json[];
  arUsers       json[];
BEGIN
  fields := json_build_array();

  FOR r IN SELECT * FROM json_to_record(pParams) AS x(groupid uuid, status int)
  LOOP
    r.status := coalesce(r.status, 3);

	FOR g IN
	  SELECT id AS value, name AS label
        FROM db.user
       WHERE type = 'G'
       ORDER BY name
	LOOP
	  arGroups := array_append(arGroups, row_to_json(g));
	END LOOP;

	IF r.groupId IS NULL THEN
      FOR u IN
	    SELECT id AS value, name AS label
		  FROM db.user
         WHERE type = 'U'
	     ORDER BY name
	  LOOP
	    arUsers := array_append(arUsers, row_to_json(u));
	  END LOOP;
    ELSE
      FOR u IN
	    SELECT t.id AS value, t.name AS label
		  FROM db.user t INNER JOIN db.member_group mg ON t.id = mg.member
         WHERE t.type = 'U'
           AND mg.userid = r.groupId
	     ORDER BY t.name
	  LOOP
	    arUsers := array_append(arUsers, row_to_json(u));
	  END LOOP;
    END IF;

	FOR l IN SELECT code FROM db.locale WHERE id = current_locale()
	LOOP
	  IF l.code = 'ru' THEN
		IF array_length(arGroups, 1) = 1 THEN
		  fields := fields || jsonb_build_object('type', 'select', 'format', 'uuid', 'key', 'groupid', 'label', 'Группа', 'value', (arGroups[1]::json)->>'value', 'data', arGroups);
		ELSE
		  fields := fields || jsonb_build_object('type', 'select', 'format', 'uuid', 'key', 'groupid', 'label', 'Группа', 'data', arGroups, 'mutable', true);
		END IF;

		IF array_length(arUsers, 1) = 1 THEN
		  fields := fields || jsonb_build_object('type', 'select', 'format', 'uuid', 'key', 'userid', 'label', 'Пользователь', 'value', (arUsers[1]::json)->>'value', 'data', arUsers);
		ELSE
		  fields := fields || jsonb_build_object('type', 'select', 'format', 'uuid', 'key', 'userid', 'label', 'Пользователь', 'data', arUsers, 'mutable', false);
		END IF;

		fields := fields || jsonb_build_object('type', 'select', 'format', 'text', 'key', 'status', 'label', 'Статус', 'value', r.status, 'data', jsonb_build_array(jsonb_build_object('value', 15, 'label', 'Все'), jsonb_build_object('value', 3, 'label', 'Действующие'), jsonb_build_object('value', 1, 'label', 'Открыт'), jsonb_build_object('value', 2, 'label', 'Активен'), jsonb_build_object('value', 4, 'label', 'Заблокирован'), jsonb_build_object('value', 8, 'label', 'Просрочен')));
	  ELSE
		IF array_length(arGroups, 1) = 1 THEN
		  fields := fields || jsonb_build_object('type', 'select', 'format', 'uuid', 'key', 'groupid', 'label', 'Group', 'value', (arGroups[1]::json)->>'value', 'data', arGroups);
		ELSE
		  fields := fields || jsonb_build_object('type', 'select', 'format', 'uuid', 'key', 'groupid', 'label', 'Group', 'data', arGroups, 'mutable', true);
		END IF;

		IF array_length(arUsers, 1) = 1 THEN
		  fields := fields || jsonb_build_object('type', 'select', 'format', 'uuid', 'key', 'userid', 'label', 'User', 'value', (arUsers[1]::json)->>'value', 'data', arUsers);
		ELSE
		  fields := fields || jsonb_build_object('type', 'select', 'format', 'uuid', 'key', 'userid', 'label', 'User', 'data', arUsers, 'mutable', false);
		END IF;

		fields := fields || jsonb_build_object('type', 'select', 'format', 'text', 'key', 'status', 'label', 'Status', 'value', r.status, 'data', jsonb_build_array(jsonb_build_object('value', 15, 'label', 'All'), jsonb_build_object('value', 3, 'label', 'Enable'), jsonb_build_object('value', 1, 'label', 'Open'), jsonb_build_object('value', 2, 'label', 'Active'), jsonb_build_object('value', 4, 'label', 'Locked'), jsonb_build_object('value', 8, 'label', 'Expired')));
	  END IF;
	END LOOP;
  END LOOP;

  RETURN json_build_object('form', pForm, 'fields', fields);
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- rpc_user_list ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Отчёт: Список пользователей
 * @param {uuid} pReady - Идентификатор готового отчёта
 * @param {jsonb} pForm - Форма
 * @return {uuid} - Идентификатор готового отчёта
 */
CREATE OR REPLACE FUNCTION report.rpc_user_list (
  pReady        uuid,
  pForm         jsonb default null
) RETURNS       void
AS $$
DECLARE
  html_file     bytea;
  csv_file      bytea;

  l             record;
  t             record;

  uGroupId      uuid;
  uUserId       uuid;

  nStatus       int;
  bEmpty        boolean;

  Lines         text[];

  vFormat       text;
  vEmpty        text;
  vHTML         text;
  vCSV          text;

  vMessage      text;
  vContext      text;

  ErrorCode     int;
  ErrorMessage  text;
BEGIN
  uGroupId := pForm->>'groupid';
  uUserId := pForm->>'userid';
  nStatus := pForm->>'status';

  FOR l IN SELECT code FROM db.locale WHERE id = current_locale()
  LOOP
    IF l.code = 'ru' THEN
      vFormat := 'DD.MM.YYYY HH24:MI:SS';
      vEmpty := 'Нет данных';

      Lines[1] := 'Список пользователей';

      IF uGroupId IS NULL THEN
        Lines[2] := 'По всем группам';
      ELSE
        Lines[2] := 'Группа: ' || GetGroupName(uGroupId);
      END IF;

      IF uUserId IS NULL THEN
        Lines[3] := 'Все пользователи';
      ELSE
        Lines[3] := 'Пользователь: ' || GetUserFullName(uUserId);
      END IF;
	ELSE
      vFormat := 'YYYY-MM-YY HH24:MI:SS';
      vEmpty := 'There is no data';

      Lines[1] := 'User list ';

      IF uGroupId IS NULL THEN
        Lines[2] := 'For all groups';
      ELSE
        Lines[2] := 'Group: ' || GetGroupName(uGroupId);
      END IF;

      IF uUserId IS NULL THEN
        Lines[3] := 'For all users';
      ELSE
        Lines[3] := 'User: ' || GetUserFullName(uUserId);
      END IF;
	END IF;

    vCSV := E'status;username;name;email;phone;description;created;host;input_last;input_count;input_error\r\n';

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
    vHTML := vHTML || E'    <h4 class="mb-3">' || Lines[2] || E'</h4>\n';
    vHTML := vHTML || E'    <h4 class="mb-3">' || Lines[3] || E'</h4>\n';

    vHTML := vHTML || E'  </div>\n';

    vHTML := vHTML || E'  <div class="table-responsive">\n';

	vHTML := vHTML || E'  <table class="table table-bordered">\n';
	vHTML := vHTML || E'    <thead class="thead-light">\n';

	IF l.code = 'ru' THEN
      vHTML := vHTML || E'      <tr class="text-center">\n';
      vHTML := vHTML || E'        <th style="width: 10%!important;">Статус</th>\n';
      vHTML := vHTML || E'        <th style="width: 10%!important;">Username</th>\n';
      vHTML := vHTML || E'        <th style="width: 10%!important;">Имя</th>\n';
      vHTML := vHTML || E'        <th style="width: 10%!important;">Почтовый адрес</th>\n';
      vHTML := vHTML || E'        <th style="width: 10%!important;">Телефон</th>\n';
      vHTML := vHTML || E'        <th style="width: 10%!important;">Описание</th>\n';
      vHTML := vHTML || E'        <th style="width: 10%!important;">Создан</th>\n';
      vHTML := vHTML || E'        <th style="width: 10%!important;">IP</th>\n';
      vHTML := vHTML || E'        <th style="width: 10%!important;">Дата входа</th>\n';
      vHTML := vHTML || E'        <th style="width: 5%!important;">Успешных</th>\n';
      vHTML := vHTML || E'        <th style="width: 5%!important;">Неудачных</th>\n';
      vHTML := vHTML || E'      </tr>\n';
	ELSE
      vHTML := vHTML || E'      <tr class="text-center">\n';
      vHTML := vHTML || E'        <th style="width: 10%!important;">Status</th>\n';
      vHTML := vHTML || E'        <th style="width: 10%!important;">Username</th>\n';
      vHTML := vHTML || E'        <th style="width: 10%!important;">Name</th>\n';
      vHTML := vHTML || E'        <th style="width: 10%!important;">Email</th>\n';
      vHTML := vHTML || E'        <th style="width: 10%!important;">Phone</th>\n';
      vHTML := vHTML || E'        <th style="width: 10%!important;">Description</th>\n';
      vHTML := vHTML || E'        <th style="width: 10%!important;">Create</th>\n';
      vHTML := vHTML || E'        <th style="width: 10%!important;">IP</th>\n';
      vHTML := vHTML || E'        <th style="width: 10%!important;">Input last</th>\n';
      vHTML := vHTML || E'        <th style="width: 5%!important;">Input count</th>\n';
      vHTML := vHTML || E'        <th style="width: 5%!important;">Input error</th>\n';
      vHTML := vHTML || E'      </tr>\n';
	END IF;

    vHTML := vHTML || E'    </thead>\n';
    vHTML := vHTML || E'    </tbody>\n';

	bEmpty := true;

    IF uGroupId IS NULL THEN
	  FOR t IN
		SELECT *
		  FROM users u
		 WHERE u.id = coalesce(uUserId, id)
		   AND u.status & nStatus != 0
		 ORDER BY u.name
	     LIMIT 500
	  LOOP
		bEmpty := false;

		vHTML := vHTML || E'        <tr class="text-center">\n';

		vHTML := vHTML || format(E'          <td style="width: 10%%!important;">%s</td>\n', t.statustext);
		vHTML := vHTML || format(E'          <td style="width: 10%%!important;">%s</td>\n', t.username);
		vHTML := vHTML || format(E'          <td style="width: 10%%!important;">%s</td>\n', t.name);

		IF t.email_verified THEN
		  vHTML := vHTML || format(E'          <td style="width: 10%%!important; color: green;">%s</td>\n', t.email);
		ELSE
		  vHTML := vHTML || format(E'          <td style="width: 10%%!important; color: red;">%s</td>\n', t.email);
		END IF;

		IF t.phone_verified THEN
		  vHTML := vHTML || format(E'          <td style="width: 10%%!important; color: green;">%s</td>\n', t.phone);
		ELSE
		  vHTML := vHTML || format(E'          <td style="width: 10%%!important; color: red;">%s</td>\n', t.phone);
		END IF;

		vHTML := vHTML || format(E'          <td style="width: 10%%!important;">%s</td>\n', t.description);
		vHTML := vHTML || format(E'          <td style="width: 10%%!important;">%s</td>\n', DateToStr(t.created, vFormat));
		vHTML := vHTML || format(E'          <td style="width: 10%%!important;">%s</td>\n', t.lc_ip);
		vHTML := vHTML || format(E'          <td style="width: 10%%!important;">%s</td>\n', DateToStr(t.input_last, vFormat));
		vHTML := vHTML || format(E'          <td style="width: 5%%!important;">%s</td>\n', t.input_count);
		vHTML := vHTML || format(E'          <td style="width: 5%%!important;">%s</td>\n', t.input_error);

		vHTML := vHTML || E'        </tr>\n';

		vCSV := vCSV || format(E'%s;', t.username);
        vCSV := vCSV || format(E'"%s";', replace(t.name, '\', '\\'));
		vCSV := vCSV || format(E'%s;', t.email);
		vCSV := vCSV || format(E'%s;', t.phone);
        vCSV := vCSV || format('"%s";', coalesce(replace(t.description, '\', '\\'), ''));
		vCSV := vCSV || format(E'%s;', DateToStr(t.created, vFormat));
		vCSV := vCSV || format(E'%s;', t.lc_ip);
		vCSV := vCSV || format(E'%s;', DateToStr(t.input_last, vFormat));
		vCSV := vCSV || format(E'%s;', t.input_count);
		vCSV := vCSV || format(E'%s\r\n', t.input_error);
	  END LOOP;
	ELSE
	  FOR t IN
		SELECT *
		  FROM users u INNER JOIN db.member_group mg ON u.id = mg.member AND mg.userid = coalesce(uGroupId, mg.userid)
		 WHERE u.id = coalesce(uUserId, id)
		   AND u.status & nStatus != 0
		 ORDER BY u.name
	     LIMIT 500
	  LOOP
		bEmpty := false;

		vHTML := vHTML || E'        <tr class="text-center">\n';

		vHTML := vHTML || format(E'          <td style="width: 10%%!important;">%s</td>\n', t.statustext);
		vHTML := vHTML || format(E'          <td style="width: 10%%!important;">%s</td>\n', t.username);
		vHTML := vHTML || format(E'          <td style="width: 10%%!important;">%s</td>\n', t.name);

		IF t.email_verified THEN
		  vHTML := vHTML || format(E'          <td style="width: 10%%!important; color: green;">%s</td>\n', t.email);
		ELSE
		  vHTML := vHTML || format(E'          <td style="width: 10%%!important; color: red;">%s</td>\n', t.email);
		END IF;

		IF t.phone_verified THEN
		  vHTML := vHTML || format(E'          <td style="width: 10%%!important; color: green;">%s</td>\n', t.phone);
		ELSE
		  vHTML := vHTML || format(E'          <td style="width: 10%%!important; color: red;">%s</td>\n', t.phone);
		END IF;

		vHTML := vHTML || format(E'          <td style="width: 10%%!important;">%s</td>\n', t.description);
		vHTML := vHTML || format(E'          <td style="width: 10%%!important;">%s</td>\n', DateToStr(t.created, vFormat));
		vHTML := vHTML || format(E'          <td style="width: 10%%!important;">%s</td>\n', t.lc_ip);
		vHTML := vHTML || format(E'          <td style="width: 10%%!important;">%s</td>\n', DateToStr(t.input_last, vFormat));
		vHTML := vHTML || format(E'          <td style="width: 5%%!important;">%s</td>\n', t.input_count);
		vHTML := vHTML || format(E'          <td style="width: 5%%!important;">%s</td>\n', t.input_error);

		vHTML := vHTML || E'        </tr>\n';

		vCSV := vCSV || format(E'%s;', t.username);
        vCSV := vCSV || format(E'"%s";', replace(t.name, '\', '\\'));
		vCSV := vCSV || format(E'%s;', t.email);
		vCSV := vCSV || format(E'%s;', t.phone);
        vCSV := vCSV || format('"%s";', coalesce(replace(t.description, '\', '\\'), ''));
		vCSV := vCSV || format(E'%s;', DateToStr(t.created, vFormat));
		vCSV := vCSV || format(E'%s;', t.lc_ip);
		vCSV := vCSV || format(E'%s;', DateToStr(t.input_last, vFormat));
		vCSV := vCSV || format(E'%s;', t.input_count);
		vCSV := vCSV || format(E'%s\r\n', t.input_error);
	  END LOOP;
	END IF;

	IF bEmpty THEN
	  IF l.code = 'ru' THEN
		vHTML := vHTML || E'        <tr class="text-center">\n';
		vHTML := vHTML || E'          <th colspan="11" scope="col">Нет данных</th>\n';
		vHTML := vHTML || E'        </tr>\n';
	  ELSE
		vHTML := vHTML || E'        <tr class="text-center">\n';
		vHTML := vHTML || E'          <th colspan="11" scope="col">No data</th>\n';
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

  html_file := vHTML::bytea;
  csv_file := vCSV::bytea;

  PERFORM SetObjectFile(pReady, 'index.html', null, length(html_file), localtimestamp, html_file, encode(digest(html_file, 'md5'), 'hex'), Lines[1], 'data:text/html;base64,');
  PERFORM SetObjectFile(pReady, format('user_%s.csv', DateToStr(Now(), 'YYYYMMDD_HH24MISS')), null, length(csv_file), localtimestamp, csv_file, encode(digest(csv_file, 'md5'), 'hex'), Lines[1], 'data:text/plain;base64,');

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

  PERFORM SetObjectFile(pReady, 'index.html', null, length(vHTML), localtimestamp, vHTML::bytea, encode(digest(vHTML, 'md5'), 'hex'), 'exception', 'data:text/html;base64,');
END
$$ LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = kernel, pg_temp;
