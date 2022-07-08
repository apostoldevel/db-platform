DROP VIEW IF EXISTS api.form_field CASCADE;
DROP VIEW IF EXISTS api.form CASCADE;

DROP FUNCTION IF EXISTS NewFormText(uuid, text, text, uuid);
DROP FUNCTION IF EXISTS EditFormText(uuid, text, text, uuid);

DROP FUNCTION IF EXISTS CreateForm(uuid, uuid, text, text, text, uuid);
DROP FUNCTION IF EXISTS EditForm(uuid, uuid, text, text, text, uuid);

DROP FUNCTION IF EXISTS CreateFormField(uuid, uuid, text, text, text, text, text, jsonb, boolean, integer);
DROP FUNCTION IF EXISTS EditFormField(uuid, uuid, text, text, text, text, text, jsonb, boolean, integer);

DROP FUNCTION IF EXISTS GetForm(uuid, text);
DROP FUNCTION IF EXISTS GetFormCode(uuid);
DROP FUNCTION IF EXISTS GetFormName(uuid, uuid);
DROP FUNCTION IF EXISTS BuildForm(uuid, json);

DROP FUNCTION IF EXISTS api.add_form(uuid, text, text, text);
DROP FUNCTION IF EXISTS api.update_form(uuid, uuid, text, text, text);
DROP FUNCTION IF EXISTS api.build_form(uuid, json);

DROP FUNCTION IF EXISTS api.delete_form_field(uuid, text);
DROP FUNCTION IF EXISTS api.clear_form_field(uuid);

DROP FUNCTION IF EXISTS api.get_form_field_json(uuid);
DROP FUNCTION IF EXISTS api.get_form_field_jsonb(uuid);

DROP TABLE IF EXISTS db.form_field CASCADE;
DROP TABLE IF EXISTS db.form CASCADE;

--

\ir '../entity/object/reference/form/create.psql'

\connect :dbname admin

SELECT SignIn(CreateSystemOAuth2(), 'admin', :'admin');

SELECT GetErrorMessage();

SELECT CreateEntityForm(GetClass('reference'));

SELECT SignOut();

\connect :dbname kernel
