CREATE OR REPLACE VIEW http.fetch
AS
  SELECT t1.id, t1.agent, t1.profile, t1.command, t1.state, t1.method, t1.resource,
         t2.status, t2.status_text, t1.content AS request, t2.content AS response,
         t1.datetime AS dateStart, t2.datetime AS dateStop, t2.runtime,
         t1.headers AS request_headers, t2.headers AS response_headers,
         t1.message, t1.error, t1.data
    FROM http.request t1 LEFT JOIN http.response t2 ON t1.id = t2.request;

GRANT ALL ON http.fetch TO kernel;
GRANT SELECT ON http.fetch TO public;
