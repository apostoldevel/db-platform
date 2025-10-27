CREATE OR REPLACE FUNCTION db.ft_file_insert()
RETURNS trigger AS $$
BEGIN
  IF NEW.owner IS NULL THEN
    NEW.owner := current_userid();
  END IF;

  IF NEW.root IS NULL THEN
    SELECT NEW.id INTO NEW.root;
  END IF;

  NEW.path := NormalizeFilePath(NEW.path, false);
  NEW.name := NormalizeFileName(NEW.name, false);

  IF NEW.type = 'l' THEN
    NEW.url := concat('https:/', NormalizeFilePath(NEW.path, true), NormalizeFileName(NEW.name, true));
  ELSE
    NEW.url := concat('/file', NormalizeFilePath(NEW.path, true), NormalizeFileName(NEW.name, true));
  END IF;

  RETURN NEW;
END
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_file_name()
RETURNS trigger AS $$
BEGIN
  NEW.name := NormalizeFileName(NEW.name, false);

  IF NEW.type = 'l' THEN
    NEW.url := concat('https:/', NormalizeFilePath(NEW.path, true), NormalizeFileName(NEW.name, true));
  ELSE
    NEW.url := concat('/file', NormalizeFilePath(NEW.path, true), NormalizeFileName(NEW.name, true));
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;

--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION db.ft_file_path()
RETURNS trigger AS $$
BEGIN
  NEW.path := NormalizeFilePath(NEW.path, false);

  IF NEW.type = 'l' THEN
    NEW.url := concat('https:/', NormalizeFilePath(NEW.path, true), NormalizeFileName(NEW.name, true));
  ELSE
    NEW.url := concat('/file', NormalizeFilePath(NEW.path, true), NormalizeFileName(NEW.name, true));
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = kernel, pg_temp;
