UPDATE db.resource_data SET name = 'UserIdNotFound' WHERE resource = '00000000-0000-4000-9400-000000000024';
UPDATE db.resource_data SET name = 'ObjectIdIsNull' WHERE resource = '00000000-0000-4000-9400-000000000068';

CREATE UNIQUE INDEX ON db.resource_data (name, locale);