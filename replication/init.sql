-- API
SELECT RegisterRoute('replication', AddEndpoint('SELECT * FROM rest.replication($1, $2);'));
