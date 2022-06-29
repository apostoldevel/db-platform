-- API
SELECT RegisterRoute('form', AddEndpoint('SELECT * FROM rest.form($1, $2);'));
