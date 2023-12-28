--------------------------------------------------------------------------------
-- FILE ------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- api.file --------------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.file
AS
  SELECT * FROM FileTree;

GRANT SELECT ON api.file TO administrator;

--------------------------------------------------------------------------------
-- api.file_data ---------------------------------------------------------------
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW api.file_data
AS
  SELECT * FROM FileData;

GRANT SELECT ON api.file_data TO administrator;

--------------------------------------------------------------------------------
-- api.set_file ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Создает или обновляет файл
 */
CREATE OR REPLACE FUNCTION api.set_file (
  pId       uuid,
  pType     char,
  pMask     int,
  pOwner    uuid,
  pRoot     uuid,
  pParent   uuid,
  pLink     uuid,
  pName     text,
  pPath     text DEFAULT null,
  pSize     integer DEFAULT null,
  pDate     timestamptz DEFAULT null,
  pData     text DEFAULT null,
  pMime     text DEFAULT null,
  pText     text DEFAULT null,
  pHash     text DEFAULT null
) RETURNS   SETOF api.file
AS $$
DECLARE
  vRoot     text;
BEGIN
  pPath := NULLIF(NULLIF(pPath, '/'), '');

  IF pId IS NULL THEN
    SELECT id INTO pId FROM db.file WHERE path = NormalizeFilePath(pPath) AND name = pName;
  END IF;

  IF pPath IS NULL THEN
    SELECT path INTO pPath FROM db.file WHERE id = pId;
  END IF;

  IF pPath IS NOT NULL THEN
    vRoot := split_part(pPath, '/', 2);
    IF vRoot IS NOT NULL THEN
      pRoot := GetFile(null::uuid, vRoot);
      IF pRoot IS NULL THEN
        pRoot := NewFilePath(concat('/', vRoot));
      END IF;
    END IF;

    pParent := NewFilePath(pPath);
  END IF;

  pId := SetFile(pId, pType, pMask::bit(9), pOwner, pRoot, pParent, pLink, pName, pSize, pDate, decode(pData, 'base64'), pMime, pText, pHash);

  RETURN QUERY SELECT * FROM api.file WHERE id = pId;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_file ----------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает файл
 * @param {uuid} pId - Идентификатор
 * @return {api.file_data}
 */
CREATE OR REPLACE FUNCTION api.get_file (
  pId       uuid
) RETURNS   SETOF api.file_data
AS $$
  SELECT * FROM api.file_data WHERE id = pId;
$$ LANGUAGE sql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.get_file_id -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает идентификатор файла по его имени и пути
 * @param {text} pName - Имя
 * @param {text} pPath - Путь
 * @return {uuid}
 */
CREATE OR REPLACE FUNCTION api.get_file_id (
  pName     text,
  pPath     text DEFAULT null
) RETURNS   uuid
AS $$
BEGIN
  RETURN GetFile(coalesce(NormalizeFileName(pName), 'index.html'), NormalizeFilePath(pPath));
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.delete_file -------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Удалялет файл
 * @param {uuid} pId - Идентификатор
 * @return {api.file}
 */
CREATE OR REPLACE FUNCTION api.delete_file (
  pId       uuid
) RETURNS   boolean
AS $$
BEGIN
  RETURN DeleteFile(pId);
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------
-- api.list_file ---------------------------------------------------------------
--------------------------------------------------------------------------------
/**
 * Возвращает список файлов.
 * @param {jsonb} pSearch - Условие: '[{"condition": "AND|OR", "field": "<поле>", "compare": "EQL|NEQ|LSS|LEQ|GTR|GEQ|GIN|LKE|ISN|INN", "value": "<значение>"}, ...]'
 * @param {jsonb} pFilter - Фильтр: '{"<поле>": "<значение>"}'
 * @param {integer} pLimit - Лимит по количеству строк
 * @param {integer} pOffSet - Пропустить указанное число строк
 * @param {jsonb} pOrderBy - Сортировать по указанным в массиве полям
 * @return {SETOF api.file}
 */
CREATE OR REPLACE FUNCTION api.list_file (
  pSearch   jsonb DEFAULT null,
  pFilter   jsonb DEFAULT null,
  pLimit    integer DEFAULT null,
  pOffSet   integer DEFAULT null,
  pOrderBy  jsonb DEFAULT null
) RETURNS   SETOF api.file
AS $$
BEGIN
  RETURN QUERY EXECUTE api.sql('api', 'file', pSearch, pFilter, pLimit, pOffSet, pOrderBy);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
