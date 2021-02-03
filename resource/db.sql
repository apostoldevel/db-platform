--------------------------------------------------------------------------------
-- RESOURCE --------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- db.resource -----------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.resource (
    id			    uuid PRIMARY KEY,
    root            uuid NOT NULL,
    node            uuid,
    type			text NOT NULL,
    level           integer NOT NULL,
    sequence		integer NOT NULL,
    CONSTRAINT fk_resource_root FOREIGN KEY (root) REFERENCES db.resource(id),
    CONSTRAINT fk_resource_node FOREIGN KEY (node) REFERENCES db.resource(id)
);

COMMENT ON TABLE db.resource IS 'Ресурс.';

COMMENT ON COLUMN db.resource.id IS 'Идентификатор.';
COMMENT ON COLUMN db.resource.root IS 'Корневой узел.';
COMMENT ON COLUMN db.resource.node IS 'Родительский узел.';
COMMENT ON COLUMN db.resource.type IS 'Multipurpose Internet Mail Extensions (MIME) тип.';
COMMENT ON COLUMN db.resource.level IS 'Уровень вложенности.';
COMMENT ON COLUMN db.resource.sequence IS 'Очерёдность';

CREATE INDEX ON db.resource (root);
CREATE INDEX ON db.resource (node);
CREATE INDEX ON db.resource (type);
CREATE INDEX ON db.resource (sequence);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_resource_before()
RETURNS trigger AS $$
BEGIN
  IF NEW.id IS NULL THEN
    NEW.id := gen_random_uuid();
  END IF;

  IF NEW.root IS NULL THEN
    NEW.root := NEW.id;
  END IF;

  IF NEW.node IS NULL THEN
    IF NEW.root <> NEW.id THEN
      NEW.node := NEW.root;
    END IF;
  END IF;

  IF NEW.type IS NULL THEN
    NEW.type := 'text/plain';
  END IF;

  IF NEW.sequence IS NULL THEN
    NEW.sequence := 1;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_resource_before
  BEFORE INSERT ON db.resource
  FOR EACH ROW
  EXECUTE PROCEDURE ft_resource_before();

--------------------------------------------------------------------------------
-- FUNCTION SetResourceSequence ------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetResourceSequence (
  pId		uuid,
  pSequence	integer,
  pDelta	integer
) RETURNS 	void
AS $$
DECLARE
  nId		uuid;
  nNode     uuid;
BEGIN
  IF pDelta <> 0 THEN
    SELECT node INTO nNode FROM db.resource WHERE id = pId;
    SELECT id INTO nId
      FROM db.resource
     WHERE coalesce(node, null_uuid()) = coalesce(nNode, null_uuid())
       AND sequence = pSequence
       AND id <> pId;

    IF found THEN
      PERFORM SetResourceSequence(nId, pSequence + pDelta, pDelta);
    END IF;
  END IF;

  UPDATE db.resource SET sequence = pSequence WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION SortResource -------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SortResource (
  pNode     uuid
) RETURNS 	void
AS $$
DECLARE
  r         record;
BEGIN
  FOR r IN
    SELECT id, (row_number() OVER(order by sequence))::int as newsequence
      FROM db.resource
     WHERE coalesce(node, null_uuid()) = coalesce(pNode, null_uuid())
  LOOP
    PERFORM SetResourceSequence(r.id, r.newsequence, 0);
  END LOOP;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- db.resource_data ------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE TABLE db.resource_data (
    resource		uuid NOT NULL,
    locale		    numeric(12) NOT NULL,
    name			text,
    description		text,
    encoding		text,
    data			text,
    updated			timestamptz DEFAULT Now() NOT NULL,
    CONSTRAINT pk_resource_data PRIMARY KEY (resource, locale),
    CONSTRAINT fk_resource_data_resource FOREIGN KEY (resource) REFERENCES db.resource(id),
    CONSTRAINT fk_resource_data_locale FOREIGN KEY (locale) REFERENCES db.locale(id)
);

--------------------------------------------------------------------------------

COMMENT ON TABLE db.resource_data IS 'Данные ресурса.';

COMMENT ON COLUMN db.resource_data.resource IS 'Идентификатор ресурса';
COMMENT ON COLUMN db.resource_data.locale IS 'Идентификатор локали';
COMMENT ON COLUMN db.resource_data.name IS 'Наименование.';
COMMENT ON COLUMN db.resource_data.description IS 'Описание.';
COMMENT ON COLUMN db.resource_data.encoding IS 'Кодировка.';
COMMENT ON COLUMN db.resource_data.data IS 'Данные.';
COMMENT ON COLUMN db.resource_data.updated IS 'Дата обновления.';

--------------------------------------------------------------------------------

CREATE INDEX ON db.resource_data (resource);
CREATE INDEX ON db.resource_data (locale);

CREATE INDEX ON db.resource_data (name);
CREATE INDEX ON db.resource_data (name text_pattern_ops);

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ft_resource_data_before()
RETURNS trigger AS $$
BEGIN
  IF NEW.locale IS NULL THEN
    NEW.locale := current_locale();
  END IF;

  IF NEW.name IS NULL THEN
    NEW.name := CheckNull(coalesce(NEW.name, OLD.name, '<null>'));
  END IF;

  IF NEW.description IS NULL THEN
    NEW.description := CheckNull(coalesce(NEW.description, OLD.description, '<null>'));
  END IF;

  IF NEW.encoding IS NULL THEN
    NEW.encoding := CheckNull(coalesce(NEW.encoding, OLD.encoding, '<null>'));
  END IF;

  IF NEW.data IS NULL THEN
    NEW.data := CheckNull(coalesce(NEW.data, OLD.data, '<null>'));
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE TRIGGER t_resource_data_before
  BEFORE INSERT OR UPDATE ON db.resource_data
  FOR EACH ROW
  EXECUTE PROCEDURE ft_resource_data_before();

--------------------------------------------------------------------------------
-- FUNCTION SetResourceData ----------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION SetResourceData (
  pResource	    uuid,
  pLocale		numeric,
  pName			text,
  pDescription	text,
  pEncoding		text,
  pData			text
) RETURNS 	    void
AS $$
BEGIN
  INSERT INTO db.resource_data (resource, locale, name, description, encoding, data)
  VALUES (pResource, pLocale, pName, pDescription, pEncoding, pData)
    ON CONFLICT (resource, locale) DO UPDATE
	  SET name = pName,
          description = pDescription,
          encoding = pEncoding,
          data = pData;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- CreateResource --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создаёт ресурс
 * @param {uuid} pId - Идентификатор
 * @param {uuid} pRoot - Идентификатор корневого узла (Передать null для создания корневого узла)
 * @param {uuid} pNode - Идентификатор узла родителя
 * @param {text} pType - MIME тип
 * @param {text} pName - Наименование
 * @param {text} pDescription - Описание
 * @param {text} pEncoding - Кодировка
 * @param {text} pData - Данные
 * @param {integer} pSequence - Очерёдность
 * @param {numeric} pLocale - Локаль
 * @return {uuid}
 */
CREATE OR REPLACE FUNCTION CreateResource (
  pId           uuid,
  pRoot         uuid,
  pNode         uuid,
  pType     	text,
  pName         text,
  pDescription	text DEFAULT null,
  pEncoding		text DEFAULT null,
  pData			text DEFAULT null,
  pSequence     integer DEFAULT null,
  pLocale		numeric DEFAULT current_locale()
) RETURNS       uuid
AS $$
DECLARE
  uResource		uuid;
  nLevel        integer;
BEGIN
  nLevel := 0;

  IF pNode IS NOT NULL THEN
    SELECT level + 1 INTO nLevel FROM db.resource WHERE id = pNode;
  END IF;

  IF NULLIF(pSequence, 0) IS NULL THEN
    SELECT max(sequence) + 1 INTO pSequence FROM db.resource WHERE coalesce(node, null_uuid()) = coalesce(pNode, null_uuid());
  ELSE
    PERFORM SetResourceSequence(pNode, pSequence, 1);
  END IF;

  uResource := coalesce(pId, gen_random_uuid());

  INSERT INTO db.resource (id, root, node, type, level, sequence)
  VALUES (uResource, pRoot, pNode, pType, nLevel, pSequence);

  PERFORM SetResourceData(uResource, pLocale, pName, pDescription, pEncoding, pData);

  RETURN uResource;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- UpdateResource --------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Обновляет ресурс
 * @param {uuid} pId - Идентификатор
 * @param {uuid} pRoot - Идентификатор корневого узла
 * @param {uuid} pNode - Идентификатор узла родителя
 * @param {text} pType - MIME тип
 * @param {text} pName - Наименование
 * @param {text} pDescription - Описание
 * @param {text} pEncoding - Кодировка
 * @param {text} pData - Данные
 * @param {integer} pSequence - Очерёдность
 * @param {numeric} pLocale - Локаль
 * @return {void}
 */
CREATE OR REPLACE FUNCTION UpdateResource (
  pId           uuid,
  pRoot         uuid DEFAULT null,
  pNode         uuid DEFAULT null,
  pType			text DEFAULT null,
  pName         text DEFAULT null,
  pDescription	text DEFAULT null,
  pEncoding		text DEFAULT null,
  pData			text DEFAULT null,
  pSequence     integer DEFAULT null,
  pLocale		numeric DEFAULT current_locale()
) RETURNS       void
AS $$
DECLARE
  nNode         uuid;

  nSequence     integer;
  nLevel	    integer;
BEGIN
  IF pNode IS NOT NULL THEN
    SELECT level + 1 INTO nLevel FROM db.resource WHERE id = pNode;
  END IF;

  SELECT node, sequence INTO nNode, nSequence FROM db.resource WHERE id = pId;

  pNode := coalesce(pNode, nNode, null_uuid());
  pSequence := coalesce(pSequence, nSequence);

  UPDATE db.resource
     SET root = coalesce(pRoot, root),
         node = CheckNull(pNode),
         type = coalesce(pType, type),
         level = coalesce(nLevel, level),
         sequence = pSequence
   WHERE id = pId;

  PERFORM SetResourceData(pId, pLocale, pName, pDescription, pEncoding, pData);

  IF coalesce(nNode, null_uuid()) <> coalesce(pNode, null_uuid()) THEN
    SELECT max(sequence) + 1 INTO nSequence FROM db.resource WHERE coalesce(node, null_uuid()) = coalesce(pNode, null_uuid());
    PERFORM SortResource(nNode);
  END IF;

  IF pSequence < nSequence THEN
    PERFORM SetResourceSequence(pId, pSequence, 1);
  END IF;

  IF pSequence > nSequence THEN
    PERFORM SetResourceSequence(pId, pSequence, -1);
  END IF;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- SetResource -----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Устанавливает ресурс
 * @param {uuid} pId - Идентификатор
 * @param {uuid} pRoot - Идентификатор корневого узла
 * @param {uuid} pNode - Идентификатор узла родителя
 * @param {text} pType - MIME тип
 * @param {text} pName - Наименование
 * @param {text} pDescription - Описание
 * @param {text} pEncoding - Кодировка
 * @param {text} pData - Данные
 * @param {integer} pSequence - Очерёдность
 * @param {numeric} pLocale - Локаль
 * @return {void}
 */
CREATE OR REPLACE FUNCTION SetResource (
  pId           uuid,
  pRoot         uuid DEFAULT null,
  pNode         uuid DEFAULT null,
  pType			text DEFAULT null,
  pName         text DEFAULT null,
  pDescription	text DEFAULT null,
  pEncoding		text DEFAULT null,
  pData			text DEFAULT null,
  pSequence     integer DEFAULT null,
  pLocale		numeric DEFAULT current_locale()
) RETURNS       uuid
AS $$
DECLARE
  uResource		uuid;
BEGIN
  IF pId IS NULL THEN
    uResource := CreateResource(pId, pRoot, pNode, pType, pName, pDescription, pEncoding, pData, pSequence, pLocale);
  ELSE
	SELECT id INTO uResource FROM db.resource WHERE id = pId;
	IF NOT FOUND THEN
	  uResource := CreateResource(pId, pRoot, pNode, pType, pName, pDescription, pEncoding, pData, pSequence, pLocale);
	ELSE
	  PERFORM UpdateResource(pId, pRoot, pNode, pType, pName, pDescription, pEncoding, pData, pSequence, pLocale);
	END IF;
  END IF;

  RETURN uResource;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- FUNCTION GetResource --------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION GetResource (
  pResource	    uuid,
  pLocale		numeric DEFAULT current_locale()
) RETURNS		text
AS $$
DECLARE
  vData			text;
BEGIN
  SELECT data INTO vData FROM db.resource_data WHERE resource = pResource AND locale = pLocale;
  RETURN vData;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- Resource --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW Resource (Id, Root, Node, Type, Level, Sequence,
    Name, Description, Encoding, Data, Updated,
    Locale, LocaleCode, LocaleName, LocaleDescription
)
AS
  WITH _current AS (
    SELECT * FROM current_locale() AS locale
  )
  SELECT r.id, r.root, r.node, r.type, r.level, r.sequence,
         d.name, d.description, d.encoding, d.data, d.updated,
         d.locale, l.code, l.name, l.description
    FROM db.resource r INNER JOIN _current         c ON true
                       INNER JOIN db.resource_data d ON d.resource = r.id AND d.locale = c.locale
                       INNER JOIN db.locale        l ON l.id = d.locale;

GRANT SELECT ON Resource TO administrator;

--------------------------------------------------------------------------------
-- VIEW ResourceTree -----------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW ResourceTree
AS
  WITH _resource_tree AS (
    WITH RECURSIVE tree AS (
      SELECT *, ARRAY[row_number() OVER (ORDER BY level, sequence)] AS sortlist FROM Resource WHERE node IS NULL
       UNION ALL
      SELECT s.*, array_append(t.sortlist, row_number() OVER (ORDER BY s.level, s.node, s.sequence))
        FROM Resource s INNER JOIN tree t ON s.node = t.id
    ) SELECT * FROM tree
  ) SELECT st.*, array_to_string(sortlist, '.', '0') AS Index FROM _resource_tree st;

GRANT SELECT ON ResourceTree TO administrator;
