CREATE ROLE administrator WITH CREATEROLE;

CREATE USER kernel WITH password 'kernel';

CREATE USER admin 
  WITH CREATEROLE 
  IN ROLE administrator
  PASSWORD 'admin';

CREATE USER daemon WITH password 'daemon';
CREATE USER apibot WITH password 'apibot';
