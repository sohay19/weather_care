ALTER TABLE notification_settings ADD COLUMN road_control_enabled INTEGER NOT NULL DEFAULT 1
  CHECK (road_control_enabled IN (0, 1));
