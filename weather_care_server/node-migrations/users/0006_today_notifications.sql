-- Today 정기 안내는 기존 동작을 유지하도록 기본 ON이다.
ALTER TABLE notification_settings ADD COLUMN today_visibility_enabled INTEGER NOT NULL DEFAULT 1 CHECK (today_visibility_enabled IN (0, 1));
ALTER TABLE notification_settings ADD COLUMN today_ozone_enabled INTEGER NOT NULL DEFAULT 1 CHECK (today_ozone_enabled IN (0, 1));
ALTER TABLE notification_settings ADD COLUMN today_wind_enabled INTEGER NOT NULL DEFAULT 1 CHECK (today_wind_enabled IN (0, 1));
ALTER TABLE notification_settings ADD COLUMN today_humidity_enabled INTEGER NOT NULL DEFAULT 1 CHECK (today_humidity_enabled IN (0, 1));
ALTER TABLE notification_settings ADD COLUMN today_apparent_temperature_enabled INTEGER NOT NULL DEFAULT 1 CHECK (today_apparent_temperature_enabled IN (0, 1));
