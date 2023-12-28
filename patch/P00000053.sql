DROP FUNCTION IF EXISTS CreateAddress(uuid, uuid, text, text, text, text, text, text, text, text, text, text, text, text, text);
DROP FUNCTION IF EXISTS EditAddress(uuid, uuid, uuid, text, text, text, text, text, text, text, text, text, text, text, text, text);

DROP FUNCTION IF EXISTS api.set_object_file(uuid, text, text, integer, timestamp with time zone, bytea, text, text, text);
DROP FUNCTION IF EXISTS api.delete_object_file(uuid, text, text);

DROP FUNCTION IF EXISTS NewObjectFile(uuid, text, text, integer, timestamp with time zone, bytea, text, text, text, text);
DROP FUNCTION IF EXISTS EditObjectFile(uuid, text, text, integer, timestamp with time zone, bytea, text, text, text, text, timestamp with time zone);
DROP FUNCTION IF EXISTS SetObjectFile(uuid, text, text, integer, timestamp with time zone, bytea, text, text, text, text);
DROP FUNCTION IF EXISTS DeleteObjectFile(uuid, text, text);
--

\ir '../file/create.psql'

DROP VIEW ObjectFile CASCADE;

ALTER TABLE db.object_file
  ADD COLUMN file uuid REFERENCES db.file(id) ON DELETE RESTRICT;

ALTER TABLE db.object_file
  ADD COLUMN updated timestamptz DEFAULT Now() NOT NULL;

--

CREATE OR REPLACE FUNCTION tmp_file (
) RETURNS    void
AS $$
DECLARE
  r         record;

  uId       uuid;
  uRoot     uuid;
  uParent   uuid;
BEGIN
  FOR r IN
    SELECT object, f.owner, o.class, c.code, file_path, file_name, file_size, file_date, file_data, file_type, file_text, file_hash, load_date
      FROM db.object_file f INNER JOIN db.object     o ON f.object = o.id
                            INNER JOIN db.class_tree c ON c.id = o.class
     WHERE c.code != 'report_ready'
     ORDER BY class, file_name
  LOOP
    uRoot := NewFilePath(concat('/', r.code, '/'));
    uParent := NewFilePath(concat('/', r.object, r.file_path), uRoot);

    BEGIN
      uId := NewFile(gen_kernel_uuid('8'), uRoot, uParent, r.file_name, '-', r.owner, B'111110100', null, r.file_size, r.file_date, r.file_data, r.file_type, r.file_text, r.file_hash);

      UPDATE db.object_file SET file = uId, updated = r.load_date WHERE object = r.object AND file_path = r.file_path AND file_name = r.file_name;
    EXCEPTION
    WHEN others THEN
      DELETE FROM db.object_file WHERE object = r.object AND file_path = r.file_path AND file_name = r.file_name;
    END;
  END LOOP;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--

\connect :dbname admin

SELECT SignIn(CreateSystemOAuth2(), 'admin', :'admin');

SELECT GetErrorMessage();

SELECT tmp_file();

SELECT SignOut();

\connect :dbname kernel

DROP FUNCTION tmp_file();

DELETE FROM db.object_file WHERE file IS NULL;

DROP TRIGGER t_object_file ON db.object_file CASCADE;
DROP TRIGGER t_object_file_name ON db.object_file CASCADE;
DROP TRIGGER t_object_file_path ON db.object_file CASCADE;
DROP TRIGGER t_object_file_notify ON db.object_file CASCADE;

ALTER TABLE db.object_file DROP CONSTRAINT object_file_pkey;

ALTER TABLE db.object_file
  ALTER COLUMN file SET NOT NULL;

ALTER TABLE db.object_file
  DROP COLUMN call_back CASCADE,
  DROP COLUMN file_link CASCADE,
  DROP COLUMN load_date CASCADE,
  DROP COLUMN file_type CASCADE,
  DROP COLUMN file_text CASCADE,
  DROP COLUMN file_hash CASCADE,
  DROP COLUMN file_data CASCADE,
  DROP COLUMN file_date CASCADE,
  DROP COLUMN file_size CASCADE,
  DROP COLUMN file_path CASCADE,
  DROP COLUMN file_name CASCADE,
  DROP COLUMN owner CASCADE;

ALTER TABLE db.object_file ADD PRIMARY KEY (object, file);
