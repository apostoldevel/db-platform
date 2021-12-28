-- API
SELECT RegisterRoute('notice', AddEndpoint('SELECT * FROM rest.notice($1, $2);'));
