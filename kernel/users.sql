DO $$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'administrator') THEN
    EXECUTE 'CREATE ROLE administrator WITH CREATEROLE';
  END IF;

  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'kernel') THEN
    EXECUTE format('CREATE USER kernel WITH PASSWORD %L', current_setting('password.kernel'));
  END IF;

  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'admin') THEN
    EXECUTE format('CREATE USER admin WITH CREATEROLE IN ROLE administrator PASSWORD %L', current_setting('password.admin'));
  END IF;

  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'daemon') THEN
    EXECUTE format('CREATE USER daemon WITH PASSWORD %L', current_setting('password.daemon'));
  END IF;

  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'apibot') THEN
    EXECUTE format('CREATE USER apibot WITH PASSWORD %L', current_setting('password.apibot'));
  END IF;
END $$;
