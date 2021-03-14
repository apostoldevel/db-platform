DROP TYPE TCurrencyList;
DROP TYPE Currency;

--------------------------------------------------------------------------------

\ir '../entity/object/reference/currency/create.psql'
\ir '../entity/object/document/account/create.psql'

--------------------------------------------------------------------------------

\connect :dbname admin

SELECT SignIn(CreateSystemOAuth2(), 'admin', 'admin');

SELECT GetErrorMessage();

SELECT CreateEntityCurrency(GetClass('reference'));
SELECT CreateEntityAccount(GetClass('document'));

SELECT SignOut();

\connect :dbname kernel
