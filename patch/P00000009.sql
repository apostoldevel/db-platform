DROP TYPE TCurrencyList;
DROP TYPE Currency;

DROP FUNCTION api.add_model(uuid, text, uuid, uuid, text, text, text);
DROP FUNCTION api.update_model(uuid, uuid, text, uuid, uuid, text, text, text);
DROP FUNCTION api.set_model(uuid, uuid, text, uuid, uuid, text, text, text);

DROP FUNCTION ChangeBalance(uuid, numeric, integer, timestamp with time zone);
DROP FUNCTION NewTurnover(uuid, numeric, numeric, integer, timestamp with time zone);
DROP FUNCTION UpdateBalance(uuid, numeric, integer, timestamp with time zone);
DROP FUNCTION GetBalance(uuid, integer, timestamp with time zone);

--------------------------------------------------------------------------------

CREATE TABLE db._balance AS
  TABLE db.balance;

CREATE TABLE db._turnover AS
  TABLE db.turn_over;

DROP TABLE db.balance CASCADE;
DROP TABLE db.turn_over CASCADE;

--------------------------------------------------------------------------------

\ir '../entity/object/document/client/update.psql'
\ir '../entity/object/reference/currency/create.psql'
\ir '../entity/object/document/account/create.psql'

--------------------------------------------------------------------------------

\connect :dbname admin

SELECT SignIn(CreateSystemOAuth2(), 'admin', 'admin');

SELECT GetErrorMessage();

SELECT CreateEntityCurrency(GetClass('reference'));
SELECT CreateEntityAccount(GetClass('document'));

SELECT CreateCurrency(null, GetType('iso.currency'), 'USD', 'Доллар США', 'Доллар США.', 840);
SELECT CreateCurrency(null, GetType('iso.currency'), 'EUR', 'Евро', 'Евро.', 978);
SELECT CreateCurrency(null, GetType('iso.currency'), 'RUB', 'Рубль', 'Российский рубль.', 643);

SELECT DoEnable(CreateAccount(id, GetType('active-passive.account'), GetCurrency('RUB'), null, id, encode(digest(id::text, 'sha1'), 'hex'))) FROM Client;

SELECT SignOut();

\connect :dbname kernel

SELECT SignIn(CreateSystemOAuth2(), 'admin', 'admin');

INSERT INTO db.balance SELECT id, type, GetAccount(encode(digest(client::text, 'sha1'), 'hex'), GetCurrency('RUB')), amount, validfromdate, validtodate FROM db._balance;
INSERT INTO db.turnover SELECT id, type, GetAccount(encode(digest(client::text, 'sha1'), 'hex'), GetCurrency('RUB')), debit, credit, turn_date, updated FROM db._turnover;

SELECT SignOut();

DROP TABLE db._balance;
DROP TABLE db._turnover;
