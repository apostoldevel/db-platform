ALTER TABLE db.agent
  DROP COLUMN vendor CASCADE;

ALTER TABLE db.agent
  ADD COLUMN vendor uuid REFERENCES db.vendor(id) ON DELETE RESTRICT;

UPDATE db.agent SET vendor = GetVendor('system.vendor') WHERE reference IN (SELECT id FROM db.reference WHERE code IN ('system.agent', 'notice.agent', 'smtp.agent', 'pop3.agent', 'imap.agent'));
UPDATE db.agent SET vendor = GetVendor('google.vendor') WHERE reference IN (SELECT id FROM db.reference WHERE code = 'fcm.agent');
UPDATE db.agent SET vendor = GetVendor('mts.vendor') WHERE reference IN (SELECT id FROM db.reference WHERE code = 'm2m.agent');
UPDATE db.agent SET vendor = GetVendor('sberbank.vendor') WHERE reference IN (SELECT id FROM db.reference WHERE code = 'sba.agent');

ALTER TABLE db.agent
  ALTER COLUMN vendor SET NOT NULL;

DROP FUNCTION IF EXISTS api.add_agent(uuid, uuid, text, text, uuid, text);
DROP FUNCTION IF EXISTS api.update_agent(uuid, uuid, uuid, text, text, uuid, text);

DROP FUNCTION IF EXISTS CreateAgent(uuid, uuid, text, text, uuid, text);
DROP FUNCTION IF EXISTS EditAgent(uuid, uuid, uuid, text, text, uuid, text);
