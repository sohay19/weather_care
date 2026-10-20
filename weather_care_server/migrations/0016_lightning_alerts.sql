ALTER TABLE notification_settings ADD COLUMN lightning_enabled INTEGER NOT NULL DEFAULT 1;

CREATE TABLE lightning_collection_state (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  attempted_at TEXT NOT NULL,
  window_end TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('AVAILABLE', 'FAILED'))
);

CREATE TABLE lightning_notification_claims (
  installation_id TEXT NOT NULL REFERENCES installations(installation_id) ON DELETE CASCADE,
  notification_key TEXT NOT NULL,
  lease_until TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  sent_at TEXT,
  PRIMARY KEY (installation_id, notification_key)
);

CREATE INDEX idx_lightning_claims_expiry ON lightning_notification_claims(expires_at);
