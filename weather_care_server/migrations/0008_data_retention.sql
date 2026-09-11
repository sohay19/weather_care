-- Do not infer app activity from updated_at: the notification scheduler writes it.
CREATE TABLE installation_activity (
  installation_id TEXT PRIMARY KEY,
  last_active_at TEXT NOT NULL
);

-- No reliable historic last-use timestamp exists. Start the first retention
-- window at rollout for existing registrations, settings and credentials.
INSERT INTO installation_activity (installation_id, last_active_at)
SELECT installation_id, strftime('%Y-%m-%dT%H:%M:%fZ', 'now') FROM (
  SELECT installation_id FROM installations
  UNION SELECT installation_id FROM notification_settings
  UNION SELECT installation_id FROM installation_credentials
);

-- One calendar year in Korea; February 29 expires on February 28 next year.
CREATE INDEX installation_activity_expiry ON installation_activity
  (julianday(last_active_at, '+9 hours', '+1 year', 'floor', '-9 hours'));
CREATE INDEX notification_history_expiry ON notification_history
  (julianday(sent_at, '+9 hours', '+1 year', 'floor', '-9 hours'));

-- Removing an expired anchor atomically removes every related row. No permanent
-- deletion marker is retained. Trigger errors roll back the whole statement.
CREATE TRIGGER activity_delete_clears_installation AFTER DELETE ON installation_activity
BEGIN
  DELETE FROM notification_history WHERE installation_id = OLD.installation_id;
  DELETE FROM notification_settings WHERE installation_id = OLD.installation_id;
  DELETE FROM installation_warning_state WHERE installation_id = OLD.installation_id;
  DELETE FROM installation_ownership_challenges WHERE installation_id = OLD.installation_id;
  DELETE FROM legacy_installation_ownership WHERE installation_id = OLD.installation_id;
  DELETE FROM installations WHERE installation_id = OLD.installation_id;
  DELETE FROM installation_credentials WHERE installation_id = OLD.installation_id;
END;

-- Also clean the activity marker when the previous Worker handles a user delete.
CREATE TRIGGER credential_delete_clears_activity AFTER DELETE ON installation_credentials
WHEN NOT EXISTS (SELECT 1 FROM installations WHERE installation_id = OLD.installation_id)
  AND NOT EXISTS (SELECT 1 FROM notification_settings WHERE installation_id = OLD.installation_id)
BEGIN DELETE FROM installation_activity WHERE installation_id = OLD.installation_id; END;
