ALTER TABLE notification_settings
  ADD COLUMN heavy_rain_enabled INTEGER NOT NULL DEFAULT 1;

ALTER TABLE notification_settings
  ADD COLUMN heatwave_enabled INTEGER NOT NULL DEFAULT 1;

ALTER TABLE notification_settings
  ADD COLUMN cold_wave_enabled INTEGER NOT NULL DEFAULT 1;

ALTER TABLE notification_settings
  ADD COLUMN shower_light_rain_enabled INTEGER NOT NULL DEFAULT 1;
