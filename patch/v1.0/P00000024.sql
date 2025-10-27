DROP FUNCTION IF EXISTS api.login(text, text, text, inet, out text, out text, out text);
DROP FUNCTION IF EXISTS api.get_session(text, text, inet, boolean, boolean);

--

DROP FUNCTION IF EXISTS api.job(uuid,timestamp with time zone);
DROP FUNCTION IF EXISTS api.job(text,double precision);

DROP VIEW IF EXISTS api.service_job;
DROP VIEW IF EXISTS ServiceJob;

--

DROP FUNCTION IF EXISTS api.service_message(uuid) CASCADE;

DROP VIEW IF EXISTS api.service_message;
DROP VIEW IF EXISTS ServiceMessage;

\ir '../workflow/update.psql'
\ir '../entity/object/document/message/update.psql'
\ir '../entity/object/document/message/inbox/create.psql'
\ir '../entity/object/document/message/outbox/create.psql'

SELECT DeleteEvent(id) FROM db.event WHERE class = GetClass('inbox');
SELECT DeleteMethod(id) FROM db.method WHERE class = GetClass('inbox');

SELECT DeleteEvent(id) FROM db.event WHERE class = GetClass('outbox');
SELECT DeleteMethod(id) FROM db.method WHERE class = GetClass('outbox');

SELECT AddInboxEvents(GetClass('inbox'));
SELECT AddInboxMethods(GetClass('inbox'));

SELECT AddOutboxEvents(GetClass('outbox'));
SELECT AddOutboxMethods(GetClass('outbox'));
