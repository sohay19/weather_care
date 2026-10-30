ALTER TABLE notification_settings ADD COLUMN dryness_enabled INTEGER CHECK (dryness_enabled IN (0, 1));
