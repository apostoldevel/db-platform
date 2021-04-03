--------------------------------------------------------------------------------
-- db.account ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.account (
    id			uuid PRIMARY KEY,
    document	uuid NOT NULL REFERENCES db.document(id) ON DELETE CASCADE,
    currency	uuid NOT NULL REFERENCES db.currency(id),
    category	uuid REFERENCES db.category(id),
    client		uuid REFERENCES db.client(id),
    code		text NOT NULL
);

--------------------------------------------------------------------------------

COMMENT ON TABLE db.account IS 'Счёт.';

COMMENT ON COLUMN db.account.id IS 'Идентификатор';
COMMENT ON COLUMN db.account.document IS 'Документ';
COMMENT ON COLUMN db.account.currency IS 'Валюта';
COMMENT ON COLUMN db.account.category IS 'Категория';
COMMENT ON COLUMN db.account.client IS 'Клиент';
COMMENT ON COLUMN db.account.code IS 'Код';

--------------------------------------------------------------------------------

CREATE UNIQUE INDEX ON db.account (currency, code);

CREATE INDEX ON db.account (document);
CREATE INDEX ON db.account (currency);
CREATE INDEX ON db.account (category);
CREATE INDEX ON db.account (client);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_account_before_insert()
RETURNS trigger AS $$
BEGIN
  IF NEW.id IS NULL THEN
    SELECT NEW.document INTO NEW.id;
  END IF;

  IF NULLIF(NEW.code, '') IS NULL THEN
    NEW.code := encode(gen_random_bytes(7), 'hex');
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_account_before_insert
  BEFORE INSERT ON db.account
  FOR EACH ROW
  EXECUTE PROCEDURE ft_account_before_insert();

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_account_after_insert()
RETURNS trigger AS $$
DECLARE
  uUserId	uuid;
BEGIN
  IF NEW.client IS NOT NULL THEN
    uUserId := GetClientUserId(NEW.client);
    IF uUserId IS NOT NULL THEN
      UPDATE db.object SET owner = uUserId WHERE id = NEW.document;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_account_after_insert
  AFTER INSERT ON db.account
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_account_after_insert();

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_account_before_update()
RETURNS trigger AS $$
DECLARE
  uParent	uuid;
  uUserId	uuid;
BEGIN
  IF OLD.client IS NULL AND NEW.client IS NOT NULL THEN
    uUserId := GetClientUserId(NEW.client);
    PERFORM CheckObjectAccess(NEW.document, B'010', uUserId);
    SELECT parent INTO uParent FROM db.object WHERE id = NEW.document;
    IF uParent IS NOT NULL THEN
      PERFORM CheckObjectAccess(uParent, B'010', uUserId);
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_account_before_update
  BEFORE UPDATE ON db.account
  FOR EACH ROW
  EXECUTE PROCEDURE ft_account_before_update();

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_account_after_update_client()
RETURNS trigger AS $$
DECLARE
  uUserId	uuid;
BEGIN
  IF NEW.client IS NOT NULL THEN
	uUserId := GetClientUserId(NEW.client);
	IF uUserId IS NOT NULL THEN
	  INSERT INTO db.aou SELECT NEW.document, uUserId, B'000', B'100';
	END IF;
  END IF;

  IF OLD.client IS NOT NULL THEN
	uUserId := GetClientUserId(OLD.client);
	IF uUserId IS NOT NULL THEN
	  DELETE FROM db.aou WHERE object = OLD.document AND userid = uUserId;
	END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_account_after_update_client
  AFTER UPDATE ON db.account
  FOR EACH ROW
  WHEN (OLD.client IS DISTINCT FROM NEW.client)
  EXECUTE PROCEDURE ft_account_after_update_client();

--------------------------------------------------------------------------------
-- BALANCE ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.balance (
    id			    uuid PRIMARY KEY DEFAULT gen_kernel_uuid('8'),
    type            integer NOT NULL DEFAULT 0,
    account         uuid NOT NULL REFERENCES db.account(id) ON DELETE RESTRICT,
    amount		    numeric NOT NULL,
    validFromDate	timestamptz DEFAULT Now() NOT NULL,
    validToDate		timestamptz DEFAULT MAXDATE() NOT NULL,
    CHECK (type BETWEEN 0 AND 3)
);

--------------------------------------------------------------------------------

COMMENT ON TABLE db.balance IS 'Баланс.';

COMMENT ON COLUMN db.balance.id IS 'Идентификатор';
COMMENT ON COLUMN db.balance.type IS 'Тип: 0 - на момент открытия; 1 - реальный; 2 - плановый; 3 - эквивалент';
COMMENT ON COLUMN db.balance.account IS 'Счёт';
COMMENT ON COLUMN db.balance.amount IS 'Сумма';
COMMENT ON COLUMN db.balance.validFromDate IS 'Дата начала периода действия';
COMMENT ON COLUMN db.balance.validToDate IS 'Дата окончания периода действия';

--------------------------------------------------------------------------------

CREATE INDEX ON db.balance (type);
CREATE INDEX ON db.balance (account);

CREATE UNIQUE INDEX ON db.balance (type, account, validFromDate, validToDate);

--------------------------------------------------------------------------------
-- TURNOVER --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.turnover (
    id			    uuid PRIMARY KEY DEFAULT gen_kernel_uuid('8'),
    type            integer NOT NULL DEFAULT 0,
    account			uuid NOT NULL REFERENCES db.account(id) ON DELETE RESTRICT,
    debit		    numeric NOT NULL,
    credit          numeric NOT NULL,
    timestamp		timestamptz NOT NULL,
    datetime		timestamptz NOT NULL DEFAULT Now(),
    CHECK (type BETWEEN 0 AND 3)
);

COMMENT ON TABLE db.turnover IS 'Оборот.';

COMMENT ON COLUMN db.turnover.id IS 'Идентификатор';
COMMENT ON COLUMN db.turnover.type IS 'Тип: 0 - на момент открытия; 1 - реальный; 2 - плановый; 3 - эквивалент';
COMMENT ON COLUMN db.turnover.account IS 'Счёт';
COMMENT ON COLUMN db.turnover.debit IS 'Сумма обота по дебету';
COMMENT ON COLUMN db.turnover.credit IS 'Сумма обота по кредиту';
COMMENT ON COLUMN db.turnover.timestamp IS 'Логическое время оборота';
COMMENT ON COLUMN db.turnover.datetime IS 'Физическое время оборота';

CREATE INDEX ON db.turnover (type);
CREATE INDEX ON db.turnover (account);

CREATE INDEX ON db.turnover (type, account, timestamp);
