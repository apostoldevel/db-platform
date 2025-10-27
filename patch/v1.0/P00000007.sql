--\ir '../entity/object/reference/version/create.psql'
\ir '../entity/object/reference/project/create.psql'

--------------------------------------------------------------------------------

\connect :dbname admin

SELECT SignIn(CreateSystemOAuth2(), 'admin', 'admin');

SELECT GetErrorMessage();

SELECT CreateEntityVersion(GetClass('reference'));
SELECT CreateEntityProject(GetClass('reference'));

SELECT SignOut();

\connect :dbname kernel
