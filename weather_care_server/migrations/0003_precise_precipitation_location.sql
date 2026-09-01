ALTER TABLE installations ADD COLUMN latitude REAL;
ALTER TABLE installations ADD COLUMN longitude REAL;
ALTER TABLE installations
  ADD COLUMN current_rain_state INTEGER NOT NULL DEFAULT 0;
ALTER TABLE installations ADD COLUMN current_rain_observed_at TEXT;
