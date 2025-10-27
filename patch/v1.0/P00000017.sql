\ir '../report/create.psql'
\ir '../reports/create.psql'

\connect :dbname admin

SELECT SignIn(CreateSystemOAuth2(), 'admin', :'admin');

SELECT GetErrorMessage();

SELECT CreateEntityReportTree(GetClass('reference'));
SELECT CreateEntityReportForm(GetClass('reference'));
SELECT CreateEntityReportRoutine(GetClass('reference'));
SELECT CreateEntityReport(GetClass('reference'));
SELECT CreateEntityReportReady(GetClass('document'));

SELECT SignOut();

\connect :dbname kernel

