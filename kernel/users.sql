CREATE ROLE administrator WITH CREATEROLE;

CREATE USER kernel WITH password 'kernel';

CREATE USER admin 
  WITH CREATEROLE 
  IN ROLE administrator
  PASSWORD 'admin';

CREATE USER daemon WITH password 'daemon';
CREATE USER stream WITH password 'stream';
CREATE USER apibot WITH password 'apibot';
CREATE USER mailbot WITH password 'mailbot';
