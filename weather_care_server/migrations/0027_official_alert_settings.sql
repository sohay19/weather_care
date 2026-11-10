ALTER TABLE notification_settings ADD COLUMN official_alert_settings TEXT
  CHECK (official_alert_settings IS NULL OR json_valid(official_alert_settings));
