--------------------------------------------------------------------------------
-- PROGRAM ---------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.program ------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.program (
    id			    numeric(12) PRIMARY KEY,
    reference		numeric(12) NOT NULL,
    body            text NOT NULL,
    CONSTRAINT fk_program_reference FOREIGN KEY (reference) REFERENCES db.reference(id)
);

COMMENT ON TABLE db.program IS 'Программа.';

COMMENT ON COLUMN db.program.id IS 'Идентификатор.';
COMMENT ON COLUMN db.program.reference IS 'Справочник.';
COMMENT ON COLUMN db.program.body IS 'Тело.';

CREATE INDEX ON db.program (reference);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_program_insert()
RETURNS trigger AS $$
DECLARE
BEGIN
  IF NULLIF(NEW.id, 0) IS NULL THEN
    SELECT NEW.reference INTO NEW.id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

CREATE TRIGGER t_program_insert
  BEFORE INSERT ON db.program
  FOR EACH ROW
  EXECUTE PROCEDURE ft_program_insert();

--------------------------------------------------------------------------------
-- CreateProgram ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт программу
 * @param {numeric} pParent - Идентификатор объекта родителя
 * @param {numeric} pType - Идентификатор типа
 * @param {varchar} pCode - Код
 * @param {varchar} pName - Наименование
 * @param {text} pBody - Тело
 * @param {text} pDescription - Описание
 * @return {numeric}
 */
CREATE OR REPLACE FUNCTION CreateProgram (
  pParent       numeric,
  pType         numeric,
  pCode         varchar,
  pName         varchar,
  pBody         text,
  pDescription	text default null
) RETURNS       numeric
AS $$
DECLARE
  nReference	numeric;
  nClass        numeric;
  nMethod       numeric;
BEGIN
  nReference := CreateReference(pParent, pType, pCode, pName, pDescription);

  INSERT INTO db.program (reference, body)
  VALUES (nReference, pBody);

  SELECT class INTO nClass FROM db.type WHERE id = pType;

  nMethod := GetMethod(nClass, null, GetAction('create'));
  PERFORM ExecuteMethod(nReference, nMethod);

  nMethod := GetMethod(nClass, null, GetAction('enable'));
  PERFORM ExecuteMethod(nReference, nMethod);

  RETURN nReference;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- EditProgram -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Редактирует агента
 * @param {numeric} pId - Идентификатор
 * @param {numeric} pParent - Идентификатор объекта родителя
 * @param {numeric} pType - Идентификатор типа
 * @param {varchar} pCode - Код
 * @param {varchar} pName - Наименование
 * @param {text} pBody - Тело
 * @param {text} pDescription - Описание
 * @return {void}
 */
CREATE OR REPLACE FUNCTION EditProgram (
  pId           numeric,
  pParent       numeric default null,
  pType         numeric default null,
  pCode         varchar default null,
  pName         varchar default null,
  pBody         text default null,
  pDescription	text default null
) RETURNS       void
AS $$
DECLARE
  nClass        numeric;
  nMethod       numeric;
BEGIN
  PERFORM EditReference(pId, pParent, pType, pCode, pName, pDescription);

  UPDATE db.program
     SET body = coalesce(pBody, body)
   WHERE id = pId;

  SELECT class INTO nClass FROM db.object WHERE id = pId;

  nMethod := GetMethod(nClass, null, GetAction('edit'));
  PERFORM ExecuteMethod(pId, nMethod);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetProgram ---------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetProgram (
  pCode		varchar
) RETURNS 	numeric
AS $$
BEGIN
  RETURN GetReference(pCode, 'program');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetProgramBody -----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetProgramBody (
  pId       numeric
) RETURNS 	text
AS $$
  SELECT body FROM db.program WHERE id = pId;
$$ LANGUAGE SQL
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- Program ---------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Program (Id, Reference, Code, Name, Description, Body)
AS
  SELECT p.id, p.reference, r.code, r.name, r.description, p.body
    FROM db.program p INNER JOIN db.reference r ON p.reference = r.id;

GRANT SELECT ON Program TO administrator;

--------------------------------------------------------------------------------
-- AccessProgram ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW AccessProgram
AS
  WITH RECURSIVE access AS (
    SELECT * FROM AccessObjectUser(GetEntity('program'), current_userid())
  )
  SELECT p.* FROM Program p INNER JOIN access ac ON p.id = ac.object;

GRANT SELECT ON AccessProgram TO administrator;

--------------------------------------------------------------------------------
-- ObjectProgram ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ObjectProgram (Id, Object, Parent,
  Entity, EntityCode, EntityName,
  Class, ClassCode, ClassLabel,
  Type, TypeCode, TypeName, TypeDescription,
  Code, Name, Label, Description, Body,
  StateType, StateTypeCode, StateTypeName,
  State, StateCode, StateLabel, LastUpdate,
  Owner, OwnerCode, OwnerName, Created,
  Oper, OperCode, OperName, OperDate
)
AS
  SELECT p.id, r.object, o.parent,
         o.entity, o.entitycode, o.entityname,
         o.class, o.classcode, o.classlabel,
         o.type, o.typecode, o.typename, o.typedescription,
         r.code, r.name, o.label, r.description, p.body,
         o.statetype, o.statetypecode, o.statetypename,
         o.state, o.statecode, o.statelabel, o.lastupdate,
         o.owner, o.ownercode, o.ownername, o.created,
         o.oper, o.opercode, o.opername, o.operdate
    FROM AccessProgram p INNER JOIN Reference r ON p.reference = r.id
                         INNER JOIN Object    o ON p.reference = o.id;

GRANT SELECT ON ObjectProgram TO administrator;
