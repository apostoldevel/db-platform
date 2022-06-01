CREATE OR REPLACE FUNCTION db.ft_object_file_insert()
RETURNS trigger AS $$
BEGIN
  IF NEW.owner IS NULL THEN
    NEW.owner := current_userid();
  END IF;

  IF NEW.call_back IS NOT NULL THEN
    PERFORM FROM pg_namespace n INNER JOIN pg_proc p ON n.oid = p.pronamespace WHERE n.nspname = split_part(NEW.call_back, '.', 1) AND p.proname = split_part(NEW.call_back, '.', 2);
    IF NOT FOUND THEN
	  RAISE EXCEPTION 'ERR-40000: Not found callback function: %', NEW.call_back;
    END IF;
  END IF;

  NEW.file_name := NormalizeFileName(NEW.file_name, false);
  NEW.file_path := NormalizeFilePath(NEW.file_path, false);
  NEW.file_link := concat('/file/', NEW.object, NormalizeFilePath(NEW.file_path, true), NormalizeFileName(NEW.file_name, true));

  IF NEW.file_path = '/public/' THEN
    UPDATE db.aou SET allow = allow | B'100' WHERE object = NEW.object AND userid = '00000000-0000-4000-a000-000000000000'::uuid;
    IF NOT FOUND THEN
      INSERT INTO db.aou SELECT NEW.object, '00000000-0000-4000-a000-000000000000'::uuid, B'000', B'100';
    END IF;
  END IF;

  RETURN NEW;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

---

CREATE OR REPLACE FUNCTION db.ft_object_file_path()
RETURNS trigger AS $$
BEGIN
  NEW.file_path := NormalizeFilePath(NEW.file_path, false);
  NEW.file_link := concat('/file/', NEW.object, NormalizeFilePath(NEW.file_path, true), NormalizeFileName(NEW.file_name, true));

  IF NEW.file_path = '/public/' THEN
    UPDATE db.aou SET allow = allow | B'100' WHERE object = NEW.object AND userid = '00000000-0000-4000-a000-000000000000'::uuid;
    IF NOT FOUND THEN
      INSERT INTO db.aou SELECT NEW.object, '00000000-0000-4000-a000-000000000000'::uuid, B'000', B'100';
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
