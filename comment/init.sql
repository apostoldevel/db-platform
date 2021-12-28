-- API
SELECT RegisterRoute('comment', AddEndpoint('SELECT * FROM rest.comment($1, $2);'));
