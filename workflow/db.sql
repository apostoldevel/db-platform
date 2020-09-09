--------------------------------------------------------------------------------
-- ESSENCE ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.essence (
    id			numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    code		varchar(30) NOT NULL,
    name		varchar(50)
);

COMMENT ON TABLE db.essence IS 'Сущность.';
COMMENT ON COLUMN db.essence.id IS 'Идентификатор';
COMMENT ON COLUMN db.essence.code IS 'Код';
COMMENT ON COLUMN db.essence.name IS 'Наименование';

CREATE UNIQUE INDEX ON db.essence (code);

--------------------------------------------------------------------------------
-- VIEW Essence ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Essence
AS
  SELECT * FROM db.essence;

GRANT SELECT ON Essence TO administrator;

--------------------------------------------------------------------------------
-- FUNCTION GetEssence ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetEssence (
  pCode		varchar
) RETURNS 	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM db.essence WHERE code = pCode;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CLASS -----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.class_tree (
    id			numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    parent		numeric(12),
    essence		numeric(12) NOT NULL,
    level		integer NOT NULL,
    code		varchar(30) NOT NULL,
    label		text NOT NULL,
    abstract		boolean DEFAULT TRUE NOT NULL,
    CONSTRAINT fk_class_tree_parent FOREIGN KEY (parent) REFERENCES db.class_tree(id),
    CONSTRAINT fk_class_tree_essence FOREIGN KEY (essence) REFERENCES db.essence(id)
);

COMMENT ON TABLE db.class_tree IS 'Дерево классов.';

COMMENT ON COLUMN db.class_tree.id IS 'Идентификатор';
COMMENT ON COLUMN db.class_tree.parent IS 'Ссылка на родительский узел';
COMMENT ON COLUMN db.class_tree.essence IS 'Сущность';
COMMENT ON COLUMN db.class_tree.level IS 'Уровень вложенности';
COMMENT ON COLUMN db.class_tree.code IS 'Код';
COMMENT ON COLUMN db.class_tree.label IS 'Метка';
COMMENT ON COLUMN db.class_tree.abstract IS 'Абстрактный: Да/Нет';

--------------------------------------------------------------------------------

CREATE INDEX ON db.class_tree (parent);
CREATE INDEX ON db.class_tree (essence);

CREATE UNIQUE INDEX ON db.class_tree (code);

--------------------------------------------------------------------------------
-- VIEW Class ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Class (Id, Parent, Essence, EssenceCode, EssenceName, Level, Code,
  Label, Abstract)
AS
  SELECT c.id, c.parent, c.essence, t.code, t.name, c.level, c.code, c.label, c.abstract
    FROM db.class_tree c INNER JOIN db.essence t ON t.id = c.essence;

GRANT SELECT ON Class TO administrator;

--------------------------------------------------------------------------------
-- VIEW ClassTree --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ClassTree
AS
  WITH RECURSIVE tree AS (
    SELECT *, ARRAY[row_number() OVER (ORDER BY id)] AS sortlist FROM Class WHERE parent IS NULL
    UNION ALL
      SELECT c.*, array_append(t.sortlist, row_number() OVER (ORDER BY c.id))
        FROM Class c INNER JOIN tree t ON c.parent = t.id
    )
    SELECT * FROM tree
     ORDER BY sortlist;

GRANT SELECT ON ClassTree TO administrator;

--------------------------------------------------------------------------------
-- FUNCTION GetClassLabel ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetClassLabel (
  pClass	numeric
) RETURNS	varchar
AS $$
DECLARE
  vLabel	text;
BEGIN
  SELECT label INTO vLabel FROM db.class_tree WHERE id = pClass;
  RETURN vLabel;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION AddClass -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddClass (
  pParent	numeric,
  pEssence  numeric,
  pCode		varchar,
  pLabel	text,
  pAbstract	boolean
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
  nLevel	integer;
BEGIN
  nLevel := 0;

  IF pParent IS NOT NULL THEN
    SELECT level + 1 INTO nLevel FROM db.class_tree WHERE id = pParent;
  END IF;

  INSERT INTO db.class_tree (parent, essence, level, code, label, abstract)
  VALUES (pParent, pEssence, nLevel, pCode, pLabel, pAbstract)
  RETURNING id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION EditClass ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditClass (
  pId		numeric,
  pParent	numeric DEFAULT null,
  pEssence	numeric DEFAULT null,
  pCode		varchar DEFAULT null,
  pLabel	text DEFAULT null,
  pAbstract	boolean DEFAULT null
) RETURNS	void
AS $$
DECLARE
  nLevel	smallint;
BEGIN
  nLevel := 1;

  IF pParent IS NOT NULL THEN
    SELECT level + 1 INTO nLevel FROM db.class_tree WHERE id = pParent;
  END IF;

  UPDATE db.class_tree
     SET parent = coalesce(pParent, parent),
         essence = coalesce(pEssence, essence),
         level = nLevel,
         code = coalesce(pCode, code),
         label = coalesce(pLabel, label),
         abstract = coalesce(pAbstract, abstract)
   WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DeleteClass --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteClass (
  pId		numeric
) RETURNS 	void
AS $$
BEGIN
  DELETE FROM db.state WHERE class = pId;
  DELETE FROM db.class_tree WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetClass -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetClass (
  pCode		varchar
) RETURNS 	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM db.class_tree WHERE code = pCode;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetEssence ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetEssence (
  pClass	numeric
) RETURNS 	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT essence INTO nId FROM db.class_tree WHERE id = pClass;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetClassCode -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetClassCode (
  pId		numeric
) RETURNS 	varchar
AS $$
DECLARE
  vCode		varchar;
BEGIN
  SELECT code INTO vCode FROM db.class_tree WHERE id = pId;
  RETURN vCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetEssenceCode -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetEssenceCode (
  pId		numeric
) RETURNS 	varchar
AS $$
DECLARE
  vCode		varchar;
BEGIN
  SELECT t.code INTO vCode
    FROM db.class_tree c INNER JOIN db.essence t ON t.id = c.essence
   WHERE c.id = pId;

  IF found THEN
    RETURN vCode;
  END IF;

  SELECT code INTO vCode FROM db.essence WHERE Id = pId;
  RETURN vCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- TYPE ------------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.type (
    id			numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    class		numeric(12) NOT NULL,
    code        varchar(30) NOT NULL,
    name 		varchar(50) NOT NULL,
    description text,
    CONSTRAINT fk_type_class FOREIGN KEY (class) REFERENCES db.class_tree(id)
);

COMMENT ON TABLE db.type IS 'Тип.';

COMMENT ON COLUMN db.type.id IS 'Идентификатор';
COMMENT ON COLUMN db.type.class IS 'Класс';
COMMENT ON COLUMN db.type.code IS 'Код';
COMMENT ON COLUMN db.type.name IS 'Наименование';
COMMENT ON COLUMN db.type.description IS 'Описание';

CREATE INDEX ON db.type (class);
CREATE INDEX ON db.type (code);

CREATE UNIQUE INDEX ON db.type (class, code);

--------------------------------------------------------------------------------
-- FUNCTION AddType ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddType (
  pClass	    numeric,
  pCode		    varchar,
  pName		    varchar,
  pDescription	text DEFAULT null
) RETURNS	    numeric
AS $$
DECLARE
  nId		    numeric;
BEGIN
  INSERT INTO db.type (class, code, name, description)
  VALUES (pClass, pCode, pName, pDescription)
  RETURNING id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION EditType -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditType (
  pId		    numeric,
  pClass	    numeric DEFAULT null,
  pCode		    varchar DEFAULT null,
  pName		    varchar DEFAULT null,
  pDescription	text DEFAULT null
) RETURNS	    void
AS $$
DECLARE
BEGIN
  UPDATE db.type
     SET class = coalesce(pClass, class),
         code = coalesce(pCode, code),
         name = coalesce(pName, name),
         description = NULLIF(coalesce(pDescription, description), '<null>')
   WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DeleteType ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteType (
  pId		numeric
) RETURNS 	void
AS $$
BEGIN
  DELETE FROM db.type WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetType ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetType (
  pCode		varchar
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM db.type WHERE code = pCode;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetTypeCode --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetTypeCode (
  pId		numeric
) RETURNS	varchar
AS $$
DECLARE
  vCode		varchar;
BEGIN
  SELECT code INTO vCode FROM db.type WHERE id = pId;
  return vCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetTypeName --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetTypeName (
  pId		numeric
) RETURNS	varchar
AS $$
DECLARE
  vName		varchar;
BEGIN
  SELECT name INTO vName FROM db.type WHERE id = pId;
  return vName;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- GetTypeCodes ----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetTypeCodes (
  pClass    numeric
) RETURNS	text[]
AS $$
DECLARE
  arResult	text[];
  r		    record;
BEGIN
  FOR r IN
    SELECT code
      FROM db.type
     WHERE class = pClass
     ORDER BY code
  LOOP
    arResult := array_append(arResult, r.code::text);
  END LOOP;

  RETURN arResult;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CodeToType ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION CodeToType (
  pCode     varchar,
  pClass    varchar
) RETURNS	numeric
AS $$
DECLARE
  arTypes	text[];
BEGIN
  IF StrPos(pCode, '.' || pClass) = 0 THEN
    pCode := pCode || '.' || pClass;
  END IF;

  arTypes := array_cat(arTypes, GetTypeCodes(GetClass(pClass)));

  IF array_position(arTypes, pCode::text) IS NULL THEN
    PERFORM IncorrectCode(pCode, arTypes);
  END IF;

  RETURN GetType(pCode);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- VIEW Type -------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Type (Id, Essence, EssenceCode, EssenceName,
  Class, ClassCode, ClassLabel, Code, Name, Description
)
AS
  SELECT o.id, c.essence, e.code, e.name,
         o.class, c.code, c.label, o.code, o.name, o.description
    FROM db.type o INNER JOIN db.class_tree c ON c.id = o.class
                   INNER JOIN db.essence e ON e.id = c.essence;

GRANT SELECT ON Type TO administrator;

--------------------------------------------------------------------------------
-- STATE -----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.state_type (
    id			numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    code		varchar(30) NOT NULL,
    name		varchar(50) NOT NULL
);

COMMENT ON TABLE db.state_type IS 'Тип состояния объекта.';

COMMENT ON COLUMN db.state_type.id IS 'Идентификатор';
COMMENT ON COLUMN db.state_type.code IS 'Код типа состояния объекта';
COMMENT ON COLUMN db.state_type.name IS 'Наименование типа состояния объекта';

CREATE UNIQUE INDEX ON db.state_type (code);

--------------------------------------------------------------------------------
-- VIEW StateType --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW StateType
AS
  SELECT * FROM db.state_type;

GRANT SELECT ON StateType TO administrator;

--------------------------------------------------------------------------------
-- FUNCTION GetStateType -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetStateType (
  pCode		varchar
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM db.state_type WHERE code = pCode;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetStateTypeCode ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetStateTypeCode (
  pId		numeric
) RETURNS	varchar
AS $$
DECLARE
  vCode		varchar;
BEGIN
  SELECT code INTO vCode FROM db.state_type WHERE id = pId;
  RETURN vCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- db.state ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.state (
    id			numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    class		numeric(12) NOT NULL,
    type		numeric(12) NOT NULL,
    code		varchar(30) NOT NULL,
    label		text NOT NULL,
    sequence	integer NOT NULL,
    CONSTRAINT fk_state_class FOREIGN KEY (class) REFERENCES db.class_tree(id),
    CONSTRAINT fk_state_type FOREIGN KEY (type) REFERENCES db.state_type(id)
);

COMMENT ON TABLE db.state IS 'Список состояний объекта.';

COMMENT ON COLUMN db.state.id IS 'Идентификатор';
COMMENT ON COLUMN db.state.class IS 'Класс объекта';
COMMENT ON COLUMN db.state.type IS 'Тип состояния';
COMMENT ON COLUMN db.state.code IS 'Код состояния';
COMMENT ON COLUMN db.state.label IS 'Состояние';
COMMENT ON COLUMN db.state.sequence IS 'Очерёдность';

CREATE INDEX ON db.state (class);
CREATE INDEX ON db.state (type);
CREATE INDEX ON db.state (code);

CREATE UNIQUE INDEX ON db.state (class, code);

CREATE OR REPLACE FUNCTION ft_state_insert()
RETURNS trigger AS $$
BEGIN
  IF NULLIF(NEW.CODE, '') IS NULL THEN
    NEW.CODE := encode(gen_random_bytes(12), 'hex');
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

CREATE TRIGGER t_state_insert
  BEFORE INSERT ON db.state
  FOR EACH ROW
  EXECUTE PROCEDURE ft_state_insert();

--------------------------------------------------------------------------------
-- VIEW State ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW State (Id, Class, ClassCode, ClassLabel,
    Type, TypeCode, TypeName, Code, Label, Sequence
)
AS
  SELECT s.id, s.class, c.code, c.label, s.type,
         t.code, t.name, s.code, s.label, s.sequence
    FROM db.state s INNER JOIN db.state_type t ON t.id = s.type
                    INNER JOIN db.class_tree c on c.id = s.class;

GRANT SELECT ON State TO administrator;

--------------------------------------------------------------------------------
-- FUNCTION AddState -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddState (
  pClass	numeric,
  pType		numeric,
  pCode		varchar,
  pLabel	text,
  pSequence     integer DEFAULT null
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  IF pSequence IS NULL THEN
    SELECT coalesce(max(sequence), 0) + 1 INTO pSequence
      FROM db.state
     WHERE class = pClass
       AND type = pType;
  END IF;

  INSERT INTO db.state (class, type, code, label, sequence)
  VALUES (pClass, pType, pCode, pLabel, pSequence)
  RETURNING id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION EditState ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditState (
  pId		    numeric,
  pClass	    numeric DEFAULT null,
  pType		    numeric DEFAULT null,
  pCode		    varchar DEFAULT null,
  pLabel	    text DEFAULT null,
  pSequence     integer DEFAULT null
) RETURNS	    void
AS $$
BEGIN
  UPDATE db.state
     SET class = coalesce(pClass, class),
         type = coalesce(pType, type),
         code = coalesce(pCode, code),
         label = coalesce(pLabel, label),
         sequence = coalesce(pSequence, sequence)
   WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DeleteState --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteState (
  pId		numeric
) RETURNS 	void
AS $$
BEGIN
  DELETE FROM db.state WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetState -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetState (
  pClass	numeric,
  pCode		varchar
) RETURNS 	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT s.id INTO nId
    FROM db.state s INNER JOIN db.class_tree c ON c.id = s.class
   WHERE s.code = pCode
     AND s.class IN (
       WITH RECURSIVE classtree(id, parent) AS (
         SELECT id, parent FROM db.class_tree WHERE id = pClass
       UNION ALL
         SELECT c.id, c.parent
           FROM db.class_tree c INNER JOIN classtree ct ON ct.parent = c.id
       )
       SELECT id FROM classtree
     )
   ORDER BY c.level DESC;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetState -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetState (
  pClass	numeric,
  pType		numeric
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT s.id INTO nId
    FROM db.state s INNER JOIN db.class_tree c ON c.id = s.class
   WHERE s.type = pType
     AND s.class IN (
       WITH RECURSIVE classtree(id, parent) AS (
         SELECT id, parent FROM db.class_tree WHERE id = pClass
       UNION ALL
         SELECT c.id, c.parent
           FROM db.class_tree c INNER JOIN classtree ct ON ct.parent = c.id
       )
       SELECT id FROM classtree
     )
   ORDER BY c.level DESC;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetStateTypeByState ------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetStateTypeByState (
  pState	numeric
) RETURNS	numeric
AS $$
DECLARE
  nType		numeric;
BEGIN
  SELECT type INTO nType FROM db.state WHERE id = pState;
  RETURN nType;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetStateTypeCodeByState --------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetStateTypeCodeByState (
  pState	numeric
) RETURNS	varchar
AS $$
DECLARE
  vCode     varchar;
BEGIN
  SELECT code INTO vCode FROM db.state_type WHERE id = (SELECT type FROM db.state WHERE id = pState);
  RETURN vCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetStateCode -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetStateCode (
  pState	numeric
) RETURNS 	varchar
AS $$
DECLARE
  vCode		varchar;
BEGIN
  SELECT code INTO vCode FROM db.state WHERE id = pState;
  RETURN vCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetStateLabel ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetStateLabel (
  pState	numeric
) RETURNS	varchar
AS $$
DECLARE
  vLabel	text;
BEGIN
  SELECT label INTO vLabel FROM db.state WHERE id = pState;
  RETURN vLabel;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- ACTION ----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.action (
    id			numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    code		varchar(30) NOT NULL,
    name		varchar(50) NOT NULL
);

COMMENT ON TABLE db.action IS 'Список действий.';

COMMENT ON COLUMN db.action.id IS 'Идентификатор';
COMMENT ON COLUMN db.action.code IS 'Код действия';
COMMENT ON COLUMN db.action.name IS 'Наименование действия';

CREATE UNIQUE INDEX ON db.action (code);

--------------------------------------------------------------------------------
-- VIEW Action -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Action
AS
  SELECT * FROM db.action;

GRANT SELECT ON Action TO administrator;

--------------------------------------------------------------------------------
-- FUNCTION GetAction ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetAction (
  pCode		varchar
) RETURNS 	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM db.action WHERE code = pCode;
  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetActionCode ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetActionCode (
  pId		numeric
) RETURNS 	varchar
AS $$
DECLARE
  vCode		varchar;
BEGIN
  SELECT code INTO vCode FROM db.action WHERE id = pId;
  RETURN vCode;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- METHOD ----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.method (
    id			numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    parent		numeric(12),
    class		numeric(12) NOT NULL,
    state		numeric(12),
    action		numeric(12) NOT NULL,
    code		varchar(30) NOT NULL,
    label		text NOT NULL,
    sequence	integer NOT NULL,
    visible		boolean DEFAULT TRUE,
    CONSTRAINT fk_method_class FOREIGN KEY (class) REFERENCES db.class_tree(id),
    CONSTRAINT fk_method_state FOREIGN KEY (state) REFERENCES db.state(id),
    CONSTRAINT fk_method_action FOREIGN KEY (action) REFERENCES db.action(id)
);

COMMENT ON TABLE db.method IS 'Методы класса.';

COMMENT ON COLUMN db.method.id IS 'Идентификатор';
COMMENT ON COLUMN db.method.parent IS 'Ссылка на родительский узел';
COMMENT ON COLUMN db.method.class IS 'Класс';
COMMENT ON COLUMN db.method.state IS 'Состояние';
COMMENT ON COLUMN db.method.action IS 'Действие';
COMMENT ON COLUMN db.method.code IS 'Код метода класса';
COMMENT ON COLUMN db.method.label IS 'Метка';
COMMENT ON COLUMN db.method.sequence IS 'Очерёдность';
COMMENT ON COLUMN db.method.visible IS 'Видимое: Да/Нет';

--------------------------------------------------------------------------------

CREATE INDEX ON db.method (parent);
CREATE INDEX ON db.method (class);
CREATE INDEX ON db.method (state);
CREATE INDEX ON db.method (action);
CREATE INDEX ON db.method (visible);

CREATE UNIQUE INDEX ON db.method (class, state, action);
CREATE UNIQUE INDEX ON db.method (class, code);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_method_before_insert()
RETURNS trigger AS $$
BEGIN
  NEW.STATE = NULLIF(NEW.STATE, 0);

  IF NEW.CODE IS NULL THEN
    NEW.CODE := coalesce(GetStateCode(NEW.STATE), 'null') || ':' || GetActionCode(NEW.ACTION);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_method_before_insert
  BEFORE INSERT ON db.method
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_method_before_insert();

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_method_before_delete()
RETURNS trigger AS $$
BEGIN
  DELETE FROM db.transition WHERE method = OLD.ID;

  RETURN OLD;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_method_before_delete
  BEFORE DELETE ON db.method
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_method_before_delete();

--------------------------------------------------------------------------------
-- VIEW Method -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Method (Id, Parent,
  Class, ClassCode, ClassLabel,
  State, StateCode, StateLabel,
  Action, ActionCode, ActionName,
  Code, Label, Sequence, Visible
)
AS
  SELECT m.id, m.parent,
         m.class, c.code, c.label,
         m.state, s.code, s.label,
         m.action, a.code, a.name,
         m.code, m.label, m.sequence, m.visible
    FROM db.method m INNER JOIN db.class_tree c ON c.id = m.class
                     INNER JOIN db.action a ON a.id = m.action
                      LEFT JOIN db.state s ON s.id = m.state;

GRANT SELECT ON Method TO administrator;

--------------------------------------------------------------------------------
-- FUNCTION AddMethod ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddMethod (
  pParent	numeric,
  pClass	numeric,
  pState	numeric,
  pAction	numeric,
  pCode		varchar,
  pLabel	text,
  pSequence	integer DEFAULT null,
  pVisible	boolean DEFAULT true
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  IF pSequence IS NULL THEN
    SELECT coalesce(max(sequence), 0) + 1 INTO pSequence
      FROM db.method
     WHERE class = pClass
       AND coalesce(state, 0) = coalesce(pState, state, 0);
  END IF;

  INSERT INTO db.method (parent, class, state, action, code, label, sequence, visible)
  VALUES (pParent, pClass, pState, pAction, pCode, pLabel, pSequence, pVisible)
  RETURNING id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION EditMethod ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditMethod (
  pId		numeric,
  pParent	numeric DEFAULT null,
  pClass	numeric DEFAULT null,
  pState	numeric DEFAULT null,
  pAction	numeric DEFAULT null,
  pCode		varchar DEFAULT null,
  pLabel	text default null,
  pSequence	integer default null,
  pVisible	boolean default null
) RETURNS	void
AS $$
BEGIN
  UPDATE db.method
     SET parent = NULLIF(coalesce(pParent, parent), 0),
         class = coalesce(pClass, class),
         state = NULLIF(coalesce(pState, state), 0),
         action = coalesce(pAction, action),
         code = coalesce(pCode, code),
         label = coalesce(pLabel, label),
         sequence = coalesce(pSequence, sequence),
         visible = coalesce(pVisible, visible)
   WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DeleteMethod -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteMethod (
  pId		numeric
) RETURNS 	void
AS $$
BEGIN
  DELETE FROM db.method WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetMethod ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetMethod (
  pClass	numeric,
  pState	numeric,
  pAction	numeric
) RETURNS	numeric
AS $$
DECLARE
  nMethod	numeric;
BEGIN
  SELECT m.id INTO nMethod
    FROM db.method m INNER JOIN db.class_tree c ON c.id = m.class
   WHERE m.action = pAction
     AND coalesce(m.state, 0) = coalesce(pState, m.state, 0)
     AND m.class IN (
       WITH RECURSIVE classtree(id, parent) AS (
         SELECT id, parent FROM db.class_tree WHERE id = pClass
       UNION ALL
         SELECT c.id, c.parent
           FROM db.class_tree c INNER JOIN classtree ct ON ct.parent = c.id
       )
       SELECT id FROM classtree
     )
     ORDER BY c.level DESC;

  RETURN nMethod;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- db.transition ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.transition (
    id			numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    state		numeric(12),
    method		numeric(12) NOT NULL,
    newstate		numeric(12) NOT NULL,
    CONSTRAINT fk_transition_state FOREIGN KEY (state) REFERENCES db.state(id),
    CONSTRAINT fk_transition_method FOREIGN KEY (method) REFERENCES db.method(id),
    CONSTRAINT fk_transition_newstate FOREIGN KEY (newstate) REFERENCES db.state(id)
);

COMMENT ON TABLE db.transition IS 'Таблица переходов из одного состояния объекта в другое состояние.';

COMMENT ON COLUMN db.transition.id IS 'Идентификатор';
COMMENT ON COLUMN db.transition.state IS 'Состояние (текущее)';
COMMENT ON COLUMN db.transition.method IS 'Совершаемая операция (действие)';
COMMENT ON COLUMN db.transition.newstate IS 'Состояние (новое)';

CREATE INDEX ON db.transition (state);
CREATE UNIQUE INDEX ON db.transition (method);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_transition_before_insert()
RETURNS trigger AS $$
BEGIN
  NEW.STATE = NULLIF(NEW.STATE, 0);

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_transition_before_insert
  BEFORE INSERT ON db.transition
  FOR EACH ROW
  EXECUTE PROCEDURE db.ft_transition_before_insert();

--------------------------------------------------------------------------------
-- VIEW Transition -------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Transition (Id,
  State, StateTypeCode, StateTypeName, StateCode, StateLabel,
  Method, MethodCode, MethodLabel, ActionCode, ActionName,
  NewState, NewStateTypeCode, NewStateTypeName, NewStateCode, NewStateLabel
)
AS
  SELECT st.id,
         os.id, os.typecode, os.typename, os.code, os.label,
         cm.id, cm.code, cm.label, cm.actioncode, cm.actionname,
         ns.id, ns.typecode, ns.typename, ns.code, ns.label
    FROM db.transition st  LEFT JOIN State  os ON os.id = st.state
                          INNER JOIN Method cm ON cm.id = st.method
                          INNER JOIN State  ns ON ns.id = st.newstate;

GRANT SELECT ON Transition TO administrator;

--------------------------------------------------------------------------------
-- FUNCTION AddTransition ------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddTransition (
  pState	numeric,
  pMethod	numeric,
  pNewState	numeric
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  INSERT INTO db.transition (state, method, newstate)
  VALUES (pState, pMethod, pNewState)
  RETURNING id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION EditTransition -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditTransition (
  pId		numeric,
  pState	numeric default null,
  pMethod	numeric default null,
  pNewState	numeric default null
) RETURNS	void
AS $$
BEGIN
  UPDATE db.transition
     SET state = coalesce(pState, state),
         method = coalesce(pMethod, method),
         newstate = coalesce(pNewState, newstate)
   WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DeleteTransition ---------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteTransition (
  pId		numeric
) RETURNS 	void
AS $$
BEGIN
  DELETE FROM db.transition WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EVENT -----------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.event_type (
    id			numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    code		varchar(30) NOT NULL,
    name		varchar(50) NOT NULL
);

COMMENT ON TABLE db.event_type IS 'Тип события.';

COMMENT ON COLUMN db.event_type.id IS 'Идентификатор';
COMMENT ON COLUMN db.event_type.code IS 'Код типа события';
COMMENT ON COLUMN db.event_type.name IS 'Наименование типа события';

CREATE UNIQUE INDEX ON db.event_type (code);

--------------------------------------------------------------------------------
-- VIEW EventType --------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW EventType
AS
  SELECT * FROM db.event_type;

GRANT SELECT ON EventType TO administrator;

--------------------------------------------------------------------------------
-- FUNCTION GetEventType -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetEventType (
  pCode		varchar
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  SELECT id INTO nId FROM db.event_type WHERE code = pCode;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- db.event --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.event (
    id			numeric(12) PRIMARY KEY DEFAULT NEXTVAL('SEQUENCE_REF'),
    class		numeric(12) NOT NULL,
    type		numeric(12) NOT NULL,
    action		numeric(12) NOT NULL,
    label		text NOT NULL,
    text		text,
    sequence	integer NOT NULL,
    enabled		boolean DEFAULT TRUE NOT NULL,
    CONSTRAINT fk_event_class FOREIGN KEY (class) REFERENCES db.class_tree(id),
    CONSTRAINT fk_event_type FOREIGN KEY (type) REFERENCES db.event_type(id),
    CONSTRAINT fk_event_action FOREIGN KEY (action) REFERENCES db.action(id)
);

COMMENT ON TABLE db.event IS 'Список событий.';

COMMENT ON COLUMN db.event.id IS 'Идентификатор';
COMMENT ON COLUMN db.event.class IS 'Класс объекта';
COMMENT ON COLUMN db.event.type IS 'Тип события';
COMMENT ON COLUMN db.event.action IS 'Действие';
COMMENT ON COLUMN db.event.label IS 'Событие';
COMMENT ON COLUMN db.event.sequence IS 'Очерёдность';
COMMENT ON COLUMN db.event.enabled IS 'Включено: Да/Нет';

CREATE INDEX ON db.event (class);
CREATE INDEX ON db.event (type);
CREATE INDEX ON db.event (action);
CREATE INDEX ON db.event (enabled);

--------------------------------------------------------------------------------
-- VIEW Event ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Event (Id, Class, Type, TypeCode, TypeName,
  Action, ActionCode, ActionName, Label, Text, Sequence, Enabled
)
AS
  SELECT el.id, el.class, el.type, et.code, et.name, el.action, al.code, al.name,
         el.label, el.text, el.sequence, el.enabled
    FROM db.event el INNER JOIN db.event_type et ON et.id = el.type
                          INNER JOIN db.action al ON al.id = el.action;

GRANT SELECT ON Event TO administrator;

--------------------------------------------------------------------------------
-- FUNCTION AddEvent -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION AddEvent (
  pClass	numeric,
  pType		numeric,
  pAction	numeric,
  pLabel	text,
  pText		text default null,
  pSequence	integer default null,
  pEnabled	boolean default true
) RETURNS	numeric
AS $$
DECLARE
  nId		numeric;
BEGIN
  IF pSequence IS NULL THEN
    SELECT coalesce(max(sequence), 0) + 1 INTO pSequence FROM db.event WHERE class = pClass AND action = pAction;
  END IF;

  INSERT INTO db.event (class, type, action, label, text, sequence, enabled)
  VALUES (pClass, pType, pAction, pLabel, NULLIF(pText, '<null>'), pSequence, pEnabled)
  RETURNING id INTO nId;

  RETURN nId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION EditEvent ----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION EditEvent (
  pId		numeric,
  pClass	numeric default null,
  pType		numeric default null,
  pAction	numeric default null,
  pLabel	text default null,
  pText		text default null,
  pSequence	integer default null,
  pEnabled	boolean default null
) RETURNS	void
AS $$
BEGIN
  UPDATE db.event
     SET class = coalesce(pClass, class),
         type = coalesce(pType, type),
         action = coalesce(pAction, action),
         label = coalesce(pLabel, label),
         text = NULLIF(coalesce(pText, text), '<null>'),
         sequence = coalesce(pSequence, sequence),
         enabled = coalesce(pEnabled, enabled)
   WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION DeleteEvent --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DeleteEvent (
  pId		numeric
) RETURNS 	void
AS $$
BEGIN
  DELETE FROM db.event WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
