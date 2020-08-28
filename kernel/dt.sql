CREATE TYPE TVarType AS ENUM ('kernel', 'context');

CREATE TYPE Id AS (Id NUMERIC(12));
CREATE TYPE Cardinal AS (Cardinal NUMERIC(14));
CREATE TYPE Amount AS (Amount NUMERIC(15,5));
CREATE TYPE Currency AS (Currency NUMERIC(12,4));
CREATE TYPE Const AS (Const NUMERIC(5));

CREATE TYPE Symbol AS (Symbol VARCHAR(1));
CREATE TYPE Code AS (Code VARCHAR(30));
CREATE TYPE Name AS (Name VARCHAR(50));
CREATE TYPE Label AS (Label VARCHAR(65));
CREATE TYPE Description AS (Description VARCHAR(260));
CREATE TYPE String AS (String TEXT);

CREATE TYPE Status AS (Status VARCHAR(1));

-- Вариант

CREATE TYPE Variant AS (
    vType	    integer,
    vInteger	integer,	-- vType = 0
    vNumeric	numeric,	-- vType = 1
    vDateTime	timestamp,	-- vType = 2
    vString	    text,		-- vType = 3
    vBoolean	boolean		-- vType = 4
  );

CREATE TYPE TIdList AS (IdList Id[]);
CREATE TYPE TCardinalList AS (CardinalList Cardinal[]);
CREATE TYPE TAmountList AS (AmountList Amount[]);
CREATE TYPE TCurrencyList AS (CurrencyList Currency[]);
CREATE TYPE TConstList AS (ConstList Const[]);
CREATE TYPE TSymbolList AS (SymbolList Symbol[]);
CREATE TYPE TCodeList AS (CodeList Code[]);
CREATE TYPE TNameList AS (NameList Name[]);
CREATE TYPE TLabelList AS (LabelList Label[]);
CREATE TYPE TDescList AS (DescList Description[]);
CREATE TYPE TStringList AS (StringList String[]);
CREATE TYPE TTextList AS (TextList Text[]);
CREATE TYPE TStatusList AS (StatusList Status[]);
CREATE TYPE TBoolList AS (BoolList Bool[]);
CREATE TYPE TDateList AS (DateList Date[]);
CREATE TYPE TVariantList AS (VariantList Variant[]);
