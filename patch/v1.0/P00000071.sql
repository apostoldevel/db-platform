DROP FUNCTION IF EXISTS http."fetch"(text, text, jsonb, text, text, text, text, text, text, text, text, jsonb);
DROP FUNCTION IF EXISTS http."fetch"(text, text, jsonb, jsonb, text, text, text, text, text, text, text, jsonb);

DROP FUNCTION IF EXISTS http.create_request(text, text, text, jsonb, text, text, text, text, text, text, text, jsonb);
DROP FUNCTION IF EXISTS http.create_response(uuid, integer, text, jsonb, text);

DROP TABLE http.log CASCADE;
DROP TABLE http.request CASCADE;
DROP TABLE http.response CASCADE;

\ir '../http/create.psql'