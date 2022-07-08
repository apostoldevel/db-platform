-- API
SELECT RegisterRoute('form/field', AddEndpoint('SELECT * FROM rest.journal_form_field($1, $2);'));
