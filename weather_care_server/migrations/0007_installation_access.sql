-- Credentials are separate from registrations: an interrupted enrollment never
-- stores a push token, coordinates or notification preferences.
CREATE TABLE installation_credentials (
  installation_id TEXT PRIMARY KEY,
  secret_hash TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE TABLE installation_ownership_challenges (
  installation_id TEXT PRIMARY KEY,
  request_id TEXT NOT NULL,
  secret_hash TEXT NOT NULL,
  proof_hash TEXT NOT NULL,
  created_at TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  FOREIGN KEY (installation_id) REFERENCES installations(installation_id) ON DELETE CASCADE
);

-- Freeze the pre-authentication delivery route. In-flight old Worker requests
-- must not redirect the ownership proof by replacing a registration token.
CREATE TABLE legacy_installation_ownership (
  installation_id TEXT PRIMARY KEY,
  fcm_token TEXT,
  FOREIGN KEY (installation_id) REFERENCES installations(installation_id) ON DELETE CASCADE
);
INSERT INTO legacy_installation_ownership SELECT installation_id, fcm_token FROM installations;

-- Also defend against in-flight requests running the previous Worker version.
CREATE TRIGGER installation_insert_requires_owner BEFORE INSERT ON installations
WHEN NOT EXISTS (SELECT 1 FROM installation_credentials WHERE installation_id = NEW.installation_id)
BEGIN SELECT RAISE(ABORT, 'installation authentication required'); END;
CREATE TRIGGER settings_insert_requires_owner BEFORE INSERT ON notification_settings
WHEN NOT EXISTS (SELECT 1 FROM installation_credentials WHERE installation_id = NEW.installation_id)
BEGIN SELECT RAISE(ABORT, 'installation authentication required'); END;
CREATE TRIGGER history_requires_installation BEFORE INSERT ON notification_history
WHEN NOT EXISTS (SELECT 1 FROM installations WHERE installation_id = NEW.installation_id)
BEGIN SELECT RAISE(IGNORE); END;
CREATE TRIGGER warning_state_requires_installation BEFORE INSERT ON installation_warning_state
WHEN NOT EXISTS (SELECT 1 FROM installations WHERE installation_id = NEW.installation_id)
BEGIN SELECT RAISE(IGNORE); END;
