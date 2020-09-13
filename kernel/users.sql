DROP USER IF EXISTS stream;
DROP USER IF EXISTS apibot;
DROP USER IF EXISTS daemon;
DROP USER IF EXISTS admin;
DROP USER IF EXISTS kernel;

DROP ROLE IF EXISTS administrator;

CREATE ROLE administrator WITH CREATEROLE;

CREATE USER kernel WITH password 'kernel';

CREATE USER admin 
  WITH CREATEROLE 
  IN ROLE administrator
  PASSWORD 'admin';

CREATE USER daemon WITH password 'daemon';
CREATE USER apibot WITH password 'apibot';
CREATE USER stream WITH password 'stream';
